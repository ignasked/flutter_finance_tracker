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
    print('Sync Down: Fetching $tableName updated since $lastSyncTime');
    try {
      // Fetch records updated at or after the last sync time
      final response = await _supabaseClient
          .from(tableName)
          .select()
          // Use ISO8601 format for Supabase timestamp queries
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
            // Ensure createdAt is set correctly if coming from Supabase
            remoteItem.createdAt =
                remoteItem.createdAt.toLocal(); // Adjust if needed
            remoteItem.updatedAt = remoteItem.updatedAt.toLocal();
            await repository.put(remoteItem, syncSource: SyncSource.supabase);
          } else {
            // Compare UTC timestamps for accuracy
            final remoteUpdatedAtUTC = remoteItem.updatedAt.toUtc();
            final localUpdatedAtUTC = localItem.updatedAt.toUtc();

            // Use a small tolerance to account for potential clock skew or precision differences
            const tolerance = Duration(seconds: 1);
            if (remoteUpdatedAtUTC.isAfter(localUpdatedAtUTC.add(tolerance))) {
              // Remote is significantly newer, update local
              print(
                  'Sync Down: Updating $tableName item ${remoteItem.id} (Remote: $remoteUpdatedAtUTC > Local: $localUpdatedAtUTC)');
              remoteItem.createdAt =
                  localItem.createdAt; // Keep original creation time
              remoteItem.updatedAt = remoteItem.updatedAt.toLocal();
              await repository.put(remoteItem, syncSource: SyncSource.supabase);
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
      // Ensure T has toJson
      String tableName,
      Future<List<T>> localItemsFuture) async {
    try {
      final localItems = await localItemsFuture;
      if (localItems.isEmpty) {
        print('Sync Up: No local changes detected for $tableName.');
        return;
      }

      print(
          'Sync Up: Pushing ${localItems.length} $tableName changes to Supabase.');

      // Convert local items to JSON maps for Supabase
      // Assume models have a toJson() method that handles UTC conversion
      final itemsToUpsert = localItems.map((item) => item.toJson()).toList();

      // Upsert: Insert if new (based on primary key), update if exists.
      await _supabaseClient.from(tableName).upsert(itemsToUpsert);
      print('Sync Up: Successfully pushed $tableName changes.');
    } catch (e, stacktrace) {
      print('Error syncing up $tableName: $e');
      print('Stacktrace: $stacktrace');
      // Re-throw to be caught by syncAll
      rethrow;
    }
  }

  // --- Methods to push individual changes immediately (optional) ---
  // These could be called directly from repository methods after a local change.
  // Note: This increases network traffic but keeps Supabase more up-to-date between full syncs.

  Future<void> pushUpsert<T extends dynamic>(String tableName, T item) async {
    // Ensure item has toJson method
    try {
      print('Pushing single upsert for $tableName item ${item.id}');
      await _supabaseClient.from(tableName).upsert(item.toJson());
    } catch (e) {
      print('Error pushing single upsert for $tableName: $e');
      // Handle error (e.g., queue for later sync)
    }
  }

  Future<void> pushDelete(String tableName, int id) async {
    try {
      print('Pushing single delete for $tableName item $id');
      await _supabaseClient.from(tableName).delete().match({'id': id});
    } catch (e) {
      print('Error pushing single delete for $tableName: $e');
      // Handle error
    }
  }
}

/// Enum to indicate the source of a repository 'put' operation.
enum SyncSource { local, supabase }
