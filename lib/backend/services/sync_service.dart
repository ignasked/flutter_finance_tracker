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
  /// Optimized with batch lookups and writes.
  Future<void> _syncDown<T extends dynamic>(
      String tableName,
      dynamic repository, // BaseRepository or specific type
      T Function(Map<String, dynamic>) fromJson,
      DateTime lastSyncTime) async {
    final currentUserId = _supabaseClient.auth.currentUser?.id;
    if (currentUserId == null) {
      print('Sync Down: User not logged in, skipping $tableName.');
      return;
    }

    print(
        'Sync Down: Fetching $tableName for user $currentUserId updated since $lastSyncTime');
    try {
      // 1. Fetch records from Supabase
      final response = await _supabaseClient
          .from(tableName)
          .select()
          .eq('user_id', currentUserId)
          .gte('updated_at', lastSyncTime.toIso8601String());

      if (response.isEmpty) {
        print(
            'Sync Down: No new or updated $tableName records found in Supabase.');
        return;
      }

      print(
          'Sync Down: Received ${response.length} $tableName records from Supabase.');

      // 2. Prepare for batch processing
      final List<T> itemsToInsert = [];
      final List<T> itemsToUpdate = [];
      final List<int> remoteIds = response
          .map((itemData) => (itemData['id'] as num?)?.toInt() ?? 0)
          .where((id) => id != 0) // Filter out potential invalid IDs
          .toList();

      // 3. Batch fetch existing local items (including soft-deleted)
      final List<T> localItemsList =
          await repository.getManyByIds(remoteIds, includeDeleted: true);
      final Map<int, T> localItemsMap = {
        for (var item in localItemsList) item.id: item
      };
      print(
          'Sync Down: Fetched ${localItemsMap.length} existing local $tableName items for comparison.');

      // 4. Process downloaded items
      for (var itemData in response) {
        final remoteItem = fromJson(itemData);
        final localItem = localItemsMap[remoteItem.id];

        if (localItem == null) {
          // Doesn't exist locally (or ID was 0/invalid), prepare for insert
          // Ensure userId is set correctly if missing from Supabase data (shouldn't happen with RLS)
          final itemToInsert = remoteItem.copyWith(
              userId: remoteItem.userId ?? currentUserId, // Ensure userId
              createdAt: remoteItem.createdAt.toLocal(),
              updatedAt: remoteItem.updatedAt.toLocal(),
              deletedAt: remoteItem.deletedAt?.toLocal());
          itemsToInsert.add(itemToInsert);
          // print('Sync Down: Preparing to insert $tableName item ${remoteItem.id}');
        } else {
          // Exists locally, compare timestamps
          final remoteUpdatedAtUTC = remoteItem.updatedAt.toUtc();
          final localUpdatedAtUTC = localItem.updatedAt.toUtc();
          const tolerance = Duration(seconds: 1); // Tolerance for comparison

          if (remoteUpdatedAtUTC.isAfter(localUpdatedAtUTC.add(tolerance))) {
            // Remote is significantly newer, prepare for update
            // Use copyWith, preserving original createdAt from the local item
            final itemToUpdate = remoteItem.copyWith(
              createdAt: localItem.createdAt, // Keep original creation time
              updatedAt:
                  remoteItem.updatedAt.toLocal(), // Use remote update time
              deletedAt:
                  remoteItem.deletedAt?.toLocal(), // Use remote deleted status
              // For Transactions, copyWith in Transaction.dart should handle relation IDs
            );
            itemsToUpdate.add(itemToUpdate);
            // print('Sync Down: Preparing to update $tableName item ${remoteItem.id}');
          } else {
            // print('Sync Down: Skipping $tableName item ${remoteItem.id} (Local is same or newer)');
          }
        }
      }

      // 5. Batch write inserts
      if (itemsToInsert.isNotEmpty) {
        print(
            'Sync Down: Inserting ${itemsToInsert.length} new $tableName items locally.');
        await repository.putMany(itemsToInsert,
            syncSource: SyncSource.supabase);
      }

      // 6. Batch write updates
      if (itemsToUpdate.isNotEmpty) {
        print(
            'Sync Down: Updating ${itemsToUpdate.length} existing $tableName items locally.');
        await repository.putMany(itemsToUpdate,
            syncSource: SyncSource.supabase);
      }

      print('Sync Down: Finished processing $tableName.');
    } catch (e, stacktrace) {
      print('Error syncing down $tableName: $e');
      print('Stacktrace: $stacktrace');
      rethrow; // Re-throw to be caught by syncAll
    }
  }

  /// Generic method to upload locally modified data to Supabase.
  /// Optimized to check UUID existence before upserting.
  Future<void> _syncUp<T extends dynamic>(
      String tableName, Future<List<T>> localItemsFuture) async {
    final currentUserId = _supabaseClient.auth.currentUser?.id;
    if (currentUserId == null) {
      print('Sync Up: User not logged in, skipping $tableName.');
      return;
    }

    try {
      final List<T> localItems = await localItemsFuture;
      if (localItems.isEmpty) {
        print(
            'Sync Up: No local changes detected for $tableName for user $currentUserId.');
        return;
      }

      print(
          'Sync Up: Processing ${localItems.length} local $tableName changes for user $currentUserId.');

      // 1. Extract UUIDs from local items
      final List<String> localUuids = localItems
          .map((item) =>
              item.uuid as String) // Assuming all items have a String uuid
          .where((uuid) =>
              uuid.isNotEmpty) // Filter out any potentially empty UUIDs
          .toList();

      if (localUuids.isEmpty && localItems.isNotEmpty) {
        print(
            'Sync Up: Warning - Local items found but no valid UUIDs to check against Supabase for $tableName.');
        // Decide how to handle this - maybe treat all as updates? Or log error?
        // For now, let's attempt upserting all, which might fail.
      }

      // 2. Fetch existing UUIDs from Supabase for these items
      Set<String> remoteUuids = {};
      if (localUuids.isNotEmpty) {
        try {
          final response = await _supabaseClient
              .from(tableName)
              .select('uuid') // Select only the uuid column
              .eq('user_id', currentUserId)
              .inFilter(
                  'uuid', localUuids); // Filter by the UUIDs we have locally

          if (response.isNotEmpty) {
            remoteUuids =
                response.map((item) => item['uuid'] as String).toSet();
            print(
                'Sync Up: Found ${remoteUuids.length} matching UUIDs in Supabase for $tableName.');
          } else {
            print(
                'Sync Up: No matching UUIDs found in Supabase for $tableName.');
          }
        } catch (e) {
          print(
              'Sync Up: Error fetching existing UUIDs for $tableName: $e. Proceeding with caution (treating all as inserts/updates).');
          // If fetching UUIDs fails, we might have to fall back to simple upsert,
          // which could lead to the original error.
        }
      }

      // 3. Partition local items based on UUID existence in Supabase
      final List<T> itemsToInsert = []; // UUID not found in Supabase
      final List<T> itemsToUpdate = []; // UUID found in Supabase

      for (final item in localItems) {
        if (remoteUuids.contains(item.uuid)) {
          itemsToUpdate.add(item);
        } else {
          itemsToInsert.add(item);
        }
      }

      // 4. Process updates (UUID exists remotely)
      if (itemsToUpdate.isNotEmpty) {
        final itemsJson = itemsToUpdate.map((item) => item.toJson()).toList();
        print(
            'Sync Up: Upserting ${itemsToUpdate.length} existing $tableName items (UUID match).');
        // Upsert based on UUID (primary key) should handle updates correctly.
        await _supabaseClient.from(tableName).upsert(itemsJson);
      }

      // 5. Process inserts (UUID does NOT exist remotely)
      if (itemsToInsert.isNotEmpty) {
        final itemsJson = itemsToInsert.map((item) => item.toJson()).toList();
        print(
            'Sync Up: Upserting ${itemsToInsert.length} new $tableName items (UUID not found remotely).');

        try {
          // Perform the upsert. This should act as an INSERT.
          await _supabaseClient.from(tableName).upsert(itemsJson);
          print('Sync Up: Successfully inserted new $tableName items.');
        } on PostgrestException catch (e) {
          // --- Specific Error Handling for Duplicate ID on INSERT ---
          if (e.code == '23505' && e.message.contains('_id_key')) {
            // Check for unique constraint violation on an ID column
            print(
                'Sync Up: Encountered unique ID conflict during insert for $tableName. This might happen if local IDs were reused after a reset and clash with existing remote records.');
            print('Sync Up: Error Details: ${e.message}');
            // Strategy: Log and potentially skip these specific items.
            // More advanced: Could try fetching the conflicting remote item by ID
            // and deciding on a merge/discard strategy, but that's complex.
            // For now, we just log it. The overall sync might partially succeed.
            // Consider NOT rethrowing here if partial success is acceptable.
          } else {
            // Re-throw other Postgrest errors
            print('Sync Up: Postgrest error during insert for $tableName: $e');
            rethrow;
          }
        } catch (e) {
          // Re-throw non-Postgrest errors
          print('Sync Up: Generic error during insert for $tableName: $e');
          rethrow;
        }
      }

      print('Sync Up: Finished pushing $tableName changes.');
    } catch (e, stacktrace) {
      // Catch errors from fetching local items or the UUID check phase
      print('Error syncing up $tableName: $e');
      print('Stacktrace: $stacktrace');
      // Rethrow to be caught by syncAll, unless specific handling was done above
      if (!(e is PostgrestException &&
          e.code == '23505' &&
          e.message.contains('_id_key'))) {
        rethrow;
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
