import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../repositories/account_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/transaction_repository.dart';

const String _lastSyncKey = 'last_sync_timestamp';

class SyncService {
  final SupabaseClient _supabaseClient;
  final TransactionRepository _transactionRepository;
  final AccountRepository _accountRepository;
  final CategoryRepository _categoryRepository;
  SharedPreferences? _prefs;

  SyncService({
    required SupabaseClient supabaseClient,
    required TransactionRepository transactionRepository,
    required AccountRepository accountRepository,
    required CategoryRepository categoryRepository,
  })  : _supabaseClient = supabaseClient,
        _transactionRepository = transactionRepository,
        _accountRepository = accountRepository,
        _categoryRepository = categoryRepository;

  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<DateTime> _getLastSyncTime() async {
    await _initPrefs();
    final timestamp = _prefs!.getInt(_lastSyncKey);
    // Use UTC for consistency
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true)
        // If never synced, use a very old date to fetch everything initially
        : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  Future<void> _setLastSyncTime(DateTime time) async {
    await _initPrefs();
    // Store as UTC milliseconds
    await _prefs!.setInt(_lastSyncKey, time.toUtc().millisecondsSinceEpoch);
  }

  /// Performs a full sync: downloads newer data from Supabase, uploads newer local data.
  Future<void> syncAll() async {
    final lastSyncTime = await _getLastSyncTime();
    // Use a consistent UTC time for the start of this sync operation
    final syncStartTime = DateTime.now().toUtc();

    print('Starting sync. Last sync time (UTC): $lastSyncTime');

    try {
      // --- Sync Down (Supabase -> ObjectBox) ---
      // Fetch records from Supabase updated *at or after* the last sync time
      await _syncDown<Account>(
          'accounts', _accountRepository, Account.fromJson, lastSyncTime);
      await _syncDown<Category>(
          'categories', _categoryRepository, Category.fromJson, lastSyncTime);
      await _syncDown<Transaction>('transactions', _transactionRepository,
          Transaction.fromJson, lastSyncTime);

      // --- Sync Up (ObjectBox -> Supabase) ---
      // Fetch local records updated *after* the last sync time
      await _syncUp<Account>(
          'accounts', _accountRepository.getAllModifiedSince(lastSyncTime));
      await _syncUp<Category>(
          'categories', _categoryRepository.getAllModifiedSince(lastSyncTime));
      await _syncUp<Transaction>('transactions',
          _transactionRepository.getAllModifiedSince(lastSyncTime));

      // Only update last sync time if sync completed successfully
      await _setLastSyncTime(syncStartTime);
      print('Sync finished successfully. New sync time (UTC): $syncStartTime');
    } catch (e, stacktrace) {
      print('Sync failed: $e');
      print('Stacktrace: $stacktrace');
      // Decide how to handle errors: retry later, notify user, etc.
      // Do NOT update the last sync time if sync failed.
    }
  }

  /// Generic method to download data from a Supabase table and update/insert into ObjectBox.
  Future<void> _syncDown<T extends dynamic>(
      // Ensure T has id and updatedAt
      String tableName,
      dynamic repository, // Ideally a common base class or interface
      T Function(Map<String, dynamic>) fromJson,
      DateTime lastSyncTime) async {
    final currentUserId = _supabaseClient.auth.currentUser?.id;
    if (currentUserId == null) {
      print('Sync Down: User not logged in, skipping $tableName.');
      return; // Don't sync down if not logged in
    }

    print(
        'Sync Down: Fetching $tableName for user $currentUserId updated since $lastSyncTime');
    try {
      // Fetch records updated at or after the last sync time FOR THE CURRENT USER
      final response = await _supabaseClient
          .from(tableName)
          .select()
          .eq('user_id', currentUserId) // <-- FILTER BY USER ID
          .gte('updated_at', lastSyncTime.toIso8601String());

      // No need to check if response is List, Supabase client returns List<Map> on success
      if (response.isNotEmpty) {
        print(
            'Sync Down: Received ${response.length} $tableName records from Supabase.');
        for (var itemData in response) {
          // No need for cast, itemData is already Map<String, dynamic>
          final remoteItem = fromJson(itemData);
          // Assume models have 'id' (int) and 'updatedAt' (DateTime)
          final localItem = await repository.getById(remoteItem.id);

          if (localItem == null) {
            // Doesn't exist locally, insert it
            print('Sync Down: Inserting $tableName item ${remoteItem.id}');
            await repository.put(remoteItem, syncSource: SyncSource.supabase);
          } else {
            // Compare UTC timestamps for accuracy
            final remoteUpdatedAtUTC = remoteItem.updatedAt.toUtc();
            final localUpdatedAtUTC = localItem.updatedAt.toUtc();

            // Use a small tolerance to account for potential clock skew or precision differences
            const tolerance = Duration(seconds: 1);
            if (remoteUpdatedAtUTC.isAfter(localUpdatedAtUTC.add(tolerance))) {
              // Remote is significantly newer, update local using copyWith
              print(
                  'Sync Down: Updating $tableName item ${remoteItem.id} (Remote: $remoteUpdatedAtUTC > Local: $localUpdatedAtUTC)');

              // --- Type-specific copyWith ---
              dynamic
                  itemToSave; // Use dynamic or a common base class/interface if you have one

              if (tableName == 'transactions') {
                // Cast to Transaction to access specific fields/methods safely
                final remoteTx = remoteItem as Transaction;
                final localTx = localItem as Transaction;
                itemToSave = remoteTx.copyWith(
                  createdAt: localTx.createdAt, // Keep original creation time
                  updatedAt: remoteTx.updatedAt
                      .toLocal(), // Use remote update time (local TZ)
                  // Pass relationship IDs explicitly for Transactions
                  categoryId: remoteTx.category.targetId,
                  fromAccountId: remoteTx.fromAccount.targetId,
                  toAccountId: remoteTx.toAccount.targetId,
                );
              } else if (tableName == 'accounts') {
                // Cast to Account
                final remoteAcc = remoteItem as Account;
                final localAcc = localItem as Account;
                itemToSave = remoteAcc.copyWith(
                  createdAt: localAcc.createdAt,
                  updatedAt: remoteAcc.updatedAt.toLocal(),
                  // No category/account relations on Account model
                );
              } else if (tableName == 'categories') {
                // Cast to Category
                final remoteCat = remoteItem as Category;
                final localCat = localItem as Category;
                itemToSave = remoteCat.copyWith(
                  createdAt: localCat.createdAt,
                  updatedAt: remoteCat.updatedAt.toLocal(),
                  // No category/account relations on Category model
                );
              } else {
                // Fallback or error for unknown table types
                print(
                    "Error: Unknown table type '$tableName' in _syncDown update logic.");
                // Optionally, use a basic copyWith if a common interface exists
                // itemToSave = remoteItem.copyWith(createdAt: localItem.createdAt, updatedAt: remoteItem.updatedAt.toLocal());
                continue; // Skip saving if type is unknown
              }
              // --- End Type-specific copyWith ---

              await repository.put(itemToSave, syncSource: SyncSource.supabase);
            } else {
              // print('Sync Down: Skipping $tableName item ${remoteItem.id} (Local is same or newer)');
            }
          }
        }
      } else {
        // No need for `if (response is List)` check here either
        print(
            'Sync Down: No new or updated $tableName records found in Supabase.');
      }
    } catch (e, stacktrace) {
      print('Error syncing down $tableName: $e');
      print('Stacktrace: $stacktrace');
      // Re-throw to be caught by syncAll
      rethrow;
    }
  }

  /// Generic method to upload locally modified data to Supabase.
  Future<void> _syncUp<T extends dynamic>(
      String tableName, Future<List<T>> localItemsFuture) async {
    final currentUserId = _supabaseClient.auth.currentUser?.id;
    if (currentUserId == null) {
      print('Sync Up: User not logged in, skipping $tableName.');
      return; // Don't sync up if not logged in
    }

    try {
      final localItems = await localItemsFuture;
      if (localItems.isEmpty) {
        print(
            'Sync Up: No local changes detected for $tableName for user $currentUserId.');
        return;
      }

      print(
          'Sync Up: Pushing ${localItems.length} $tableName changes for user $currentUserId to Supabase.');

      // Separate new (ID=0) from existing items
      // Ensure items have a mutable 'id' field for this to work
      final List<T> itemsToInsert =
          localItems.where((item) => item.id == 0).toList();
      final List<T> itemsToUpdate =
          localItems.where((item) => item.id != 0).toList();

      // Process updates first (less critical to get returning ID)
      if (itemsToUpdate.isNotEmpty) {
        final itemsJson = itemsToUpdate.map((item) => item.toJson()).toList();
        print(
            'Sync Up: Upserting ${itemsToUpdate.length} existing $tableName items.');
        // Consider adding .select() if you need confirmation/updated data for edits too
        await _supabaseClient.from(tableName).upsert(itemsJson);
      }

      // Process inserts and get the returned data with new IDs
      if (itemsToInsert.isNotEmpty) {
        final itemsJson = itemsToInsert.map((item) => item.toJson()).toList();
        print(
            'Sync Up: Upserting ${itemsToInsert.length} new $tableName items.');
        // Use .select() to get the results back, including the generated IDs
        final response =
            await _supabaseClient.from(tableName).upsert(itemsJson).select();

        // --- Update local items with Supabase IDs ---
        // This is crucial for Accounts and Categories before syncing Transactions
        if (response.isNotEmpty &&
            (tableName == 'accounts' || tableName == 'categories')) {
          final repository = _getRepositoryForTable(tableName);
          if (repository != null && response.length == itemsToInsert.length) {
            List<T> itemsToUpdateLocally = [];
            // Assuming response order matches itemsToInsert order
            for (var i = 0; i < response.length; i++) {
              final remoteData = response[i] as Map<String, dynamic>;
              final originalLocalItem = itemsToInsert[i]; // The one with ID 0

              // Create a new object from the response data using fromJson
              // Need a helper to get the correct fromJson based on T or tableName
              final T confirmedItem =
                  _fromJsonForTable<T>(tableName, remoteData);

              // Update the ID on the original local object directly
              // Requires 'id' field to be mutable in Account and Category models
              if (originalLocalItem.id == 0) {
                // Double check it's the new item
                originalLocalItem.id = confirmedItem.id; // Update the ID!

                // Optionally update other fields like updatedAt if needed
                // originalLocalItem.updatedAt = confirmedItem.updatedAt;

                itemsToUpdateLocally.add(originalLocalItem);
                print(
                    'Sync Up: Updated local ID for new $tableName from 0 to ${confirmedItem.id}');
              } else {
                print(
                    'Sync Up Warning: Mismatched item during local ID update for $tableName.');
              }
            }
            // Perform batch update in ObjectBox
            if (itemsToUpdateLocally.isNotEmpty) {
              // Ensure repositories have putMany that accepts syncSource
              await repository.putMany(itemsToUpdateLocally,
                  syncSource: SyncSource.supabase);
              print(
                  'Sync Up: Saved local ID updates for ${itemsToUpdateLocally.length} new $tableName items.');
            }
          } else if (response.length != itemsToInsert.length) {
            print(
                'Sync Up Error: Mismatched response length (${response.length}) vs items inserted (${itemsToInsert.length}) for $tableName. Cannot update local IDs reliably.');
          }
        } else if (response.isEmpty && itemsToInsert.isNotEmpty) {
          print(
              'Sync Up Warning: Upsert for new $tableName items returned empty response.');
        }
        // --- End Update local items ---
      }
      print('Sync Up: Successfully pushed $tableName changes.');
    } catch (e, stacktrace) {
      print('Error syncing up $tableName: $e');
      print('Stacktrace: $stacktrace');
      // Don't rethrow if it's a foreign key constraint during transaction sync,
      // as accounts/categories might have synced successfully.
      // Rethrow for other errors.
      if (!(tableName == 'transactions' &&
          e is PostgrestException &&
          e.code == '23503')) {
        rethrow;
      } else {
        print(
            'Sync Up: Foreign key violation for $tableName likely due to missing related item. Check sync order and ID mapping.');
      }
    }
  }

  // Helper to get repository (ensure it returns the correct type)
  dynamic _getRepositoryForTable(String tableName) {
    if (tableName == 'transactions') return _transactionRepository;
    if (tableName == 'accounts') return _accountRepository;
    if (tableName == 'categories') return _categoryRepository;
    return null;
  }

  // Helper needed in _syncUp to call the correct fromJson
  T _fromJsonForTable<T>(String tableName, Map<String, dynamic> json) {
    if (tableName == 'accounts') {
      return Account.fromJson(json) as T;
    } else if (tableName == 'categories') {
      return Category.fromJson(json) as T;
    } else if (tableName == 'transactions') {
      // Although not strictly needed for ID update logic, include for completeness
      return Transaction.fromJson(json) as T;
    }
    throw Exception("Cannot find fromJson for table: $tableName");
  }

  Future<void> pushUpsert<T extends dynamic>(String tableName, T item) async {
    final currentUserId = _supabaseClient.auth.currentUser?.id;
    if (currentUserId == null) return; // Don't push if not logged in
    // Ensure item has toJson method and includes the correct userId
    if (item.userId != currentUserId) {
      print('Error: Attempting to push item for wrong user.');
      return; // Or throw an error
    }
    try {
      print(
          'Pushing single upsert for $tableName item ${item.id} for user $currentUserId');
      await _supabaseClient.from(tableName).upsert(item.toJson());
    } catch (e) {
      print('Error pushing single upsert for $tableName: $e');
    }
  }

  Future<void> pushDelete(String tableName, int id) async {
    final currentUserId = _supabaseClient.auth.currentUser?.id;
    if (currentUserId == null) return; // Don't push if not logged in
    try {
      print(
          'Pushing single delete for $tableName item $id for user $currentUserId');
      // RLS policy should prevent deleting others' data, but filtering here is safer.
      await _supabaseClient.from(tableName).delete().match(
          {'id': id, 'user_id': currentUserId}); // Match both id and user_id
    } catch (e) {
      print('Error pushing single delete for $tableName: $e');
    }
  }
}

/// Enum to indicate the source of a repository 'put' operation.
enum SyncSource { local, supabase }
