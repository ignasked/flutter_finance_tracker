import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart'
    as foundation; // Import for VoidCallback
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
  final foundation.VoidCallback? onSyncStart; // Callback when sync process begins
  final foundation.VoidCallback? onSyncEnd; // Callback when sync process completes (success or failure)
  SharedPreferences? _prefs;

  SyncService({
    required SupabaseClient supabaseClient,
    required TransactionRepository transactionRepository,
    required AccountRepository accountRepository,
    required CategoryRepository categoryRepository,
    this.onSyncStart,
    this.onSyncEnd,
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
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true)
        : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true); // Default to epoch if never synced
  }

  Future<void> _setLastSyncTime(DateTime time) async {
    await _initPrefs();
    await _prefs!.setInt(_lastSyncKey, time.toUtc().millisecondsSinceEpoch);
  }

  /// Performs a full synchronization:
  /// 1. Downloads newer records from Supabase.
  /// 2. Uploads locally modified records to Supabase.
  /// Invokes [onSyncStart] and [onSyncEnd] callbacks.
  Future<void> syncAll() async {
    final currentUserId = _supabaseClient.auth.currentUser?.id;
    if (currentUserId == null) {
      print("SyncAll: No user logged in, skipping sync.");
      return;
    }

    onSyncStart?.call();
    print("SyncAll: Starting sync process...");

    try {
      final lastSyncTime = await _getLastSyncTime();
      print("SyncAll: Last sync time: $lastSyncTime");
      final nowUtc = DateTime.now().toUtc();

      // --- Sync Down ---
      print("SyncAll: Starting Sync Down...");
      await _syncDown<Account>(
          'accounts', _accountRepository, Account.fromJson, lastSyncTime);
      await _syncDown<Category>(
          'categories', _categoryRepository, Category.fromJson, lastSyncTime);
      await _syncDown<Transaction>('transactions', _transactionRepository,
          Transaction.fromJson, lastSyncTime);
      print("SyncAll: Sync Down completed.");

      // --- Sync Up ---
      print("SyncAll: Starting Sync Up...");
      await _syncUp<Account>(
          'accounts', _accountRepository.getAllModifiedSince(lastSyncTime));
      await _syncUp<Category>(
          'categories', _categoryRepository.getAllModifiedSince(lastSyncTime));
      await _syncUp<Transaction>('transactions',
          _transactionRepository.getAllModifiedSince(lastSyncTime));
      print("SyncAll: Sync Up completed.");

      // --- Update Last Sync Time ---
      await _setLastSyncTime(nowUtc);
      print(
          "SyncAll: Sync process finished successfully. New last sync time: $nowUtc");
    } catch (e, stacktrace) {
      print("SyncAll: Error during sync process: $e");
      print(stacktrace);
      rethrow;
    } finally {
      print("SyncAll: Calling onSyncEnd callback.");
      onSyncEnd?.call();
    }
  }

  /// Downloads records of type [T] from [tableName] modified since [lastSyncTime]
  /// and updates the local ObjectBox database.
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

      final List<T> itemsToInsert = [];
      final List<T> itemsToUpdate = [];
      final List<int> remoteIds = response
          .map((itemData) => (itemData['id'] as num?)?.toInt() ?? 0)
          .where((id) => id != 0)
          .toList();

      final List<T> localItemsList =
          await repository.getManyByIds(remoteIds, includeDeleted: true);
      final Map<int, T> localItemsMap = {
        for (var item in localItemsList) item.id: item
      };
      print(
          'Sync Down: Fetched ${localItemsMap.length} existing local $tableName items for comparison.');

      for (var itemData in response) {
        final remoteItem = fromJson(itemData);
        final localItem = localItemsMap[remoteItem.id];

        if (localItem == null) {
          final itemToInsert = remoteItem.copyWith(
              userId: remoteItem.userId ?? currentUserId,
              createdAt: remoteItem.createdAt.toLocal(),
              updatedAt: remoteItem.updatedAt.toLocal(),
              deletedAt: remoteItem.deletedAt?.toLocal());
          itemsToInsert.add(itemToInsert);
        } else {
          final remoteUpdatedAtUTC = remoteItem.updatedAt.toUtc();
          final localUpdatedAtUTC = localItem.updatedAt.toUtc();
          const tolerance = Duration(seconds: 1);

          if (remoteUpdatedAtUTC.isAfter(localUpdatedAtUTC.add(tolerance))) {
            final itemToUpdate = remoteItem.copyWith(
              createdAt: localItem.createdAt,
              updatedAt: remoteItem.updatedAt.toLocal(),
              deletedAt: remoteItem.deletedAt?.toLocal(),
            );
            itemsToUpdate.add(itemToUpdate);
          }
        }
      }

      if (itemsToInsert.isNotEmpty) {
        final maxRemoteId = itemsToInsert
            .map((e) => e.id as int)
            .fold<int>(0, (prev, id) => id > prev ? id : prev);
        if (maxRemoteId > 0) {
          try {
            await _bumpObjectBoxIdSequence<T>(repository, maxRemoteId);
          } catch (e) {
            print(
                'Sync Down: Failed to bump ObjectBox next ID for $tableName: $e');
          }
        }
        print(
            'Sync Down: Inserting ${itemsToInsert.length} new $tableName items locally.');
        await repository.putMany(itemsToInsert,
            syncSource: SyncSource.supabase);
      }

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
      rethrow;
    }
  }

  /// Uploads locally modified records of type [T] from [localItemsFuture] to [tableName] in Supabase.
  /// Checks for UUID existence in Supabase to differentiate between inserts and updates.
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

      final List<String> localUuids = localItems
          .map((item) =>
              item.uuid as String)
          .where((uuid) =>
              uuid.isNotEmpty)
          .toList();

      if (localUuids.isEmpty && localItems.isNotEmpty) {
        print(
            'Sync Up: Warning - Local items found but no valid UUIDs to check against Supabase for $tableName.');
      }

      Set<String> remoteUuids = {};
      if (localUuids.isNotEmpty) {
        try {
          final response = await _supabaseClient
              .from(tableName)
              .select('uuid')
              .eq('user_id', currentUserId)
              .inFilter(
                  'uuid', localUuids);

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
        }
      }

      final List<T> itemsToInsert = [];
      final List<T> itemsToUpdate = [];

      for (final item in localItems) {
        if (remoteUuids.contains(item.uuid)) {
          itemsToUpdate.add(item);
        } else {
          itemsToInsert.add(item);
        }
      }

      if (itemsToUpdate.isNotEmpty) {
        final itemsJson = itemsToUpdate.map((item) => item.toJson()).toList();
        print(
            'Sync Up: Upserting ${itemsToUpdate.length} existing $tableName items (UUID match).');
        await _supabaseClient.from(tableName).upsert(itemsJson);
      }

      if (itemsToInsert.isNotEmpty) {
        final itemsJson = itemsToInsert.map((item) => item.toJson()).toList();
        print(
            'Sync Up: Upserting ${itemsToInsert.length} new $tableName items (UUID not found remotely).');

        try {
          await _supabaseClient.from(tableName).upsert(itemsJson);
          print('Sync Up: Successfully inserted new $tableName items.');
        } on PostgrestException catch (e) {
          if (e.code == '23505' && e.message.contains('_id_key')) {
            print(
                'Sync Up: Encountered unique ID conflict during insert for $tableName. This might happen if local IDs were reused after a reset and clash with existing remote records.');
            print('Sync Up: Error Details: ${e.message}');
          } else {
            print('Sync Up: Postgrest error during insert for $tableName: $e');
            rethrow;
          }
        } catch (e) {
          print('Sync Up: Generic error during insert for $tableName: $e');
          rethrow;
        }
      }

      print('Sync Up: Finished pushing $tableName changes.');
    } catch (e, stacktrace) {
      print('Error syncing up $tableName: $e');
      print('Stacktrace: $stacktrace');
      if (!(e is PostgrestException &&
          e.code == '23505' &&
          e.message.contains('_id_key'))) {
        rethrow;
      }
    }
  }

  /// Ensures ObjectBox's internal ID sequence for type [T] is at least [targetId].
  /// This prevents ID conflicts when inserting records from Supabase that might have higher IDs
  /// than ObjectBox's current sequence.
  Future<void> _bumpObjectBoxIdSequence<T>(
      dynamic repository, int targetId) async {
    if (targetId <= 1) return;
    final box = repository.box;
    int currentMaxId = 0;
    try {
      final allIds = box.getAllIds();
      if (allIds.isNotEmpty) {
        currentMaxId = allIds.reduce((a, b) => a > b ? a : b);
      }
    } catch (_) {}
    if (currentMaxId >= targetId) return;
    final int numToInsert = targetId - currentMaxId;
    final List<int> dummyIds = [];
    for (int i = 0; i < numToInsert; i++) {
      dynamic dummy;
      final now = DateTime.now();
      if (T == Account) {
        dummy = Account(
          id: 0,
          uuid: 'dummy-sync-id-${now.microsecondsSinceEpoch}-$i',
          name: 'dummy',
          currency: 'USD',
          currencySymbol: ' ',
          balance: 0.0,
          typeValue: 0,
          colorValue: 0,
          iconCodePoint: 0,
          isEnabled: false,
          createdAt: now,
          updatedAt: now,
          userId: _supabaseClient.auth.currentUser?.id,
          deletedAt: null,
        );
      } else if (T == Category) {
        dummy = Category(
          id: 0,
          uuid: 'dummy-sync-id-${now.microsecondsSinceEpoch}-$i',
          title: 'dummy',
          descriptionForAI: 'dummy',
          iconCodePoint: 0,
          typeValue: 0,
          isEnabled: false,
          colorValue: 0,
          createdAt: now,
          updatedAt: now,
          userId: _supabaseClient.auth.currentUser?.id,
          deletedAt: null,
        );
      } else if (T == Transaction) {
        dummy = Transaction.createWithIds(
          id: 0,
          uuid: 'dummy-sync-id-${now.microsecondsSinceEpoch}-$i',
          title: 'dummy',
          amount: 0.0,
          description: 'dummy',
          date: now,
          categoryId: 0,
          fromAccountId: 0,
          toAccountId: 0,
          createdAt: now,
          updatedAt: now,
          userId: _supabaseClient.auth.currentUser?.id,
          metadata: null,
          deletedAt: null,
        );
      } else {
        break;
      }
      final newId = box.put(dummy);
      dummyIds.add(newId);
    }
    for (final id in dummyIds) {
      box.remove(id);
    }
    print('Bumped ObjectBox next ID for ${T.toString()} to >= $targetId');
  }

  /// Upserts a single [item] of type [T] to the specified [tableName] in Supabase.
  /// Ensures the item's `userId` matches the current authenticated user.
  Future<void> pushUpsert<T extends dynamic>(String tableName, T item) async {
    final currentUserId = _supabaseClient.auth.currentUser?.id;
    if (currentUserId == null) return;
    if (item.userId != currentUserId) {
      print('Error: Attempting to push item for wrong user.');
      return;
    }
    try {
      print(
          'Pushing single upsert for $tableName item ${item.id} for user $currentUserId');
      await _supabaseClient.from(tableName).upsert(item.toJson());
    } catch (e) {
      print('Error pushing single upsert for $tableName: $e');
    }
  }

  /// Deletes a single record by its integer [id] from [tableName] in Supabase.
  /// Ensures the deletion is for the current authenticated user.
  Future<void> pushDelete(String tableName, int id) async {
    final currentUserId = _supabaseClient.auth.currentUser?.id;
    if (currentUserId == null) return;
    try {
      print(
          'Pushing single delete for $tableName item $id for user $currentUserId');
      await _supabaseClient.from(tableName).delete().match(
          {'id': id, 'user_id': currentUserId});
    } catch (e) {
      print('Error pushing single delete for $tableName: $e');
    }
  }

  /// Deletes a single record by its string [uuid] from [tableName] in Supabase.
  /// Ensures the deletion is for the current authenticated user.
  Future<void> pushDeleteByUuid(String tableName, String uuid) async {
    final currentUserId = _supabaseClient.auth.currentUser?.id;
    if (currentUserId == null) return;
    try {
      print(
          'Pushing single delete for $tableName item with uuid $uuid for user $currentUserId');
      await _supabaseClient.from(tableName).delete().match({
        'uuid': uuid,
        'user_id': currentUserId
      });
    } catch (e) {
      print('Error pushing single delete for $tableName (uuid): $e');
    }
  }

  /// Upserts a single [entity] of type [T] to Supabase.
  /// Handles foreign key dependencies for [Transaction] entities by recursively pushing them.
  /// Logs errors without throwing to prevent disruption of local operations.
  Future<void> pushSingleUpsert<T>(T entity) async {
    final currentUserId = _supabaseClient.auth.currentUser?.id;
    if (currentUserId == null) {
      print("PushSingleUpsert: No user logged in, skipping push for $T.");
      return;
    }

    try {
      if ((entity as dynamic).userId != currentUserId) {
        print(
            "PushSingleUpsert: Entity userId (${(entity as dynamic).userId}) does not match current user ($currentUserId). Skipping push for $T.");
        return;
      }
    } catch (e) {
      print(
          "PushSingleUpsert: Could not verify userId for entity of type $T. Proceeding with push cautiously. Error: $e");
    }

    String tableName;
    Map<String, dynamic> json = {};

    try {
      if (entity is Transaction) {
        final int? categoryId =
            entity.category.targetId == 0 ? null : entity.category.targetId;
        final int? fromAccountId = entity.fromAccount.targetId == 0
            ? null
            : entity.fromAccount.targetId;
        final int? toAccountId =
            entity.toAccount.targetId == 0 ? null : entity.toAccount.targetId;
        if (categoryId != null) {
          final category = await _categoryRepository.getById(categoryId);
          if (category != null) {
            await pushSingleUpsert<Category>(category);
          }
        }
        if (fromAccountId != null) {
          final fromAccount = await _accountRepository.getById(fromAccountId);
          if (fromAccount != null) {
            await pushSingleUpsert<Account>(fromAccount);
          }
        }
        if (toAccountId != null) {
          final toAccount = await _accountRepository.getById(toAccountId);
          if (toAccount != null) {
            await pushSingleUpsert<Account>(toAccount);
          }
        }
      }
      switch (T) {
        case Transaction:
          tableName = 'transactions';
          json = (entity as Transaction).toJson();
          break;
        case Account:
          tableName = 'accounts';
          json = (entity as Account).toJson();
          break;
        case Category:
          tableName = 'categories';
          json = (entity as Category).toJson();
          break;
        default:
          print("PushSingleUpsert: Unsupported type $T");
          return;
      }

      print(
          "PushSingleUpsert: Pushing ${T.toString()} UUID: ${json['uuid']} to $tableName...");

      if (json.containsKey('created_at') && json['created_at'] is DateTime) {
        json['created_at'] =
            (json['created_at'] as DateTime).toUtc().toIso8601String();
      }
      if (json.containsKey('updated_at') && json['updated_at'] is DateTime) {
        json['updated_at'] =
            (json['updated_at'] as DateTime).toUtc().toIso8601String();
      }
      if (json.containsKey('deleted_at') && json['deleted_at'] is DateTime?) {
        json['deleted_at'] =
            (json['deleted_at'] as DateTime?)?.toUtc().toIso8601String();
      }
      if (json.containsKey('date') && json['date'] is DateTime) {
        json['date'] = (json['date'] as DateTime).toUtc().toIso8601String();
      }

      json.remove('fromAccount');
      json.remove('toAccount');
      json.remove('category');

      await _supabaseClient.from(tableName).upsert(json, onConflict: 'uuid');
      print(
          "PushSingleUpsert: Successfully pushed ${T.toString()} UUID: ${json['uuid']}.");
    } catch (e, stacktrace) {
      print(
          "PushSingleUpsert: Error pushing ${T.toString()} UUID: ${json['uuid'] ?? 'unknown'}: $e");
      print(stacktrace);
    }
  }

  /// Upserts a list of [entities] to Supabase.
  /// Groups entities by type for efficient bulk operations.
  /// Logs errors without throwing.
  Future<void> pushUpsertMany<T>(List<T> entities) async {
    if (entities.isEmpty) {
      return;
    }

    final currentUserId = _supabaseClient.auth.currentUser?.id;
    if (currentUserId == null) {
      print("PushUpsertMany: No user logged in, skipping push.");
      return;
    }

    final Map<Type, List<Map<String, dynamic>>> groupedJson = {};

    for (final entity in entities) {
      Map<String, dynamic> json;
      Type entityType = entity.runtimeType;

      try {
        if ((entity as dynamic).userId != currentUserId) {
          print(
              "PushUpsertMany: Skipping entity with mismatched userId (${(entity as dynamic).userId}) for type $entityType.");
          continue;
        }

        switch (entityType) {
          case Transaction:
            json = (entity as Transaction).toJson();
            break;
          case Account:
            json = (entity as Account).toJson();
            break;
          case Category:
            json = (entity as Category).toJson();
            break;
          default:
            print("PushUpsertMany: Unsupported type $entityType");
            continue;
        }

        if (json.containsKey('created_at') && json['created_at'] is DateTime) {
          json['created_at'] =
              (json['created_at'] as DateTime).toUtc().toIso8601String();
        }
        if (json.containsKey('updated_at') && json['updated_at'] is DateTime) {
          json['updated_at'] =
              (json['updated_at'] as DateTime).toUtc().toIso8601String();
        }
        if (json.containsKey('deleted_at') && json['deleted_at'] is DateTime?) {
          json['deleted_at'] =
              (json['deleted_at'] as DateTime?)?.toUtc().toIso8601String();
        }
        if (json.containsKey('date') && json['date'] is DateTime) {
          json['date'] = (json['date'] as DateTime).toUtc().toIso8601String();
        }

        if (entityType == Transaction) {
          json.remove('id');
        }
        json.remove('fromAccount');
        json.remove('toAccount');
        json.remove('category');

        groupedJson.putIfAbsent(entityType, () => []).add(json);
      } catch (e, stacktrace) {
        print(
            "PushUpsertMany: Error processing entity of type $entityType for batch: $e");
        print(stacktrace);
      }
    }

    for (final entry in groupedJson.entries) {
      Type entityType = entry.key;
      List<Map<String, dynamic>> jsonList = entry.value;
      String tableName;

      if (jsonList.isEmpty) continue;

      switch (entityType) {
        case Transaction:
          tableName = 'transactions';
          break;
        case Account:
          tableName = 'accounts';
          break;
        case Category:
          tableName = 'categories';
          break;
        default:
          continue;
      }

      print(
          "PushUpsertMany: JSON batch for $entityType: ${jsonList.map((e) => e.toString()).join(', ')}");

      print(
          "PushUpsertMany: Pushing ${jsonList.length} items of type $entityType to $tableName...");

      try {
        await _supabaseClient
            .from(tableName)
            .upsert(jsonList, onConflict: 'uuid');
        print("PushUpsertMany: Successfully pushed batch for $entityType.");
      } catch (e, stacktrace) {
        print("PushUpsertMany: Error pushing batch for type $entityType: $e");
        print(stacktrace);
      }
    }
  }
}

/// Enum to indicate the source of a repository 'put' operation.
enum SyncSource { local, supabase }
