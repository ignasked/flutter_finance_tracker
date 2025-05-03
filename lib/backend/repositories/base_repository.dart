import 'package:money_owl/backend/services/sync_service.dart'; // Import SyncSource
import 'package:money_owl/objectbox.g.dart';
import 'package:objectbox/objectbox.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Base repository class providing common CRUD operations for ObjectBox entities.
/// T represents the entity type (e.g., Transaction, Category, Account).
abstract class BaseRepository<T> {
  late final Store _store;
  late final Box<T> box;

  BaseRepository(Store store) {
    _store = store;
    box = _store.box<T>();
  }

  /// Create the ObjectBox store
  static Future<Store> createStore() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final store = await openStore(
          directory: p.join(docsDir.path, "finance_tracker_db"));
      return store;
    } catch (e) {
      throw Exception('Error creating ObjectBox store: $e');
    }
  }

  /// Get the ObjectBox store
  Store get store => _store;

  /// Dispose the ObjectBox store
  void dispose() {
    _store.close();
  }

  /// Retrieves all entities of type T.
  /// Subclasses should override to apply context filters (like userId and deletedAt).
  Future<List<T>> getAll() async {
    try {
      // Base implementation doesn't filter by deletedAt or userId. Subclasses MUST override.
      final query = box.query().build();
      final items = await query.findAsync();
      query.close();
      return items;
    } catch (e) {
      print('Error getting all entities of type $T: $e');
      return [];
    }
  }

  /// Retrieves a single entity by its ID.
  /// Subclasses should override to apply context filters (like userId and deletedAt).
  Future<T?> getById(int id) async {
    try {
      // Base implementation doesn't filter by deletedAt or userId. Subclasses MUST override.
      final item = await box.getAsync(id);
      return item;
    } catch (e) {
      print('Error getting entity of type $T with ID $id: $e');
      return null;
    }
  }

  /// Puts (inserts or updates) a single entity into the database.
  /// Handles updating timestamps locally.
  /// Requires subclasses to implement logic for setting userId and handling sync sources.
  Future<int> put(T entity, {SyncSource syncSource = SyncSource.local}) async {
    // Subclasses should override this to handle timestamps, userId, and syncSource logic.
    try {
      final id = await box.putAsync(entity);
      return id;
    } catch (e) {
      print('Error putting entity of type $T: $e');
      rethrow; // Rethrow to allow calling code to handle
    }
  }

  /// Puts multiple entities into the database.
  /// Requires subclasses to implement logic for setting userId and handling sync sources.
  Future<List<int>> putMany(List<T> entities,
      {SyncSource syncSource = SyncSource.local}) async {
    // Subclasses should override this to handle timestamps, userId, and syncSource logic.
    try {
      final ids = await box.putManyAsync(entities);
      return ids;
    } catch (e) {
      print('Error putting multiple entities of type $T: $e');
      rethrow;
    }
  }

  /// Permanently removes an entity by its ID.
  /// Use `softRemove` for recoverable deletion.
  /// Subclasses should override to apply context filters (like userId).
  Future<bool> remove(int id) async {
    // Subclasses should override to check context (e.g., userId) before removing.
    try {
      final success = await box.removeAsync(id);
      return success;
    } catch (e) {
      print('Error removing entity of type $T with ID $id: $e');
      return false;
    }
  }

  /// Permanently removes multiple entities by their IDs.
  /// Subclasses should override to apply context filters (like userId).
  Future<int> removeMany(List<int> ids) async {
    // Subclasses should override to check context (e.g., userId) before removing.
    try {
      final count = await box.removeManyAsync(ids);
      return count;
    } catch (e) {
      print('Error removing multiple entities of type $T: $e');
      return 0;
    }
  }

  /// Permanently removes all entities of type T.
  /// WARNING: Use with extreme caution. Prefer context-specific removal methods.
  /// Subclasses should override to prevent accidental data loss across users.
  Future<int> removeAll() async {
    // Subclasses should override this, potentially throwing an error
    // to enforce context-specific deletion (e.g., removeAllForCurrentUser).
    try {
      final count = await box.removeAllAsync();
      return count;
    } catch (e) {
      print('Error removing all entities of type $T: $e');
      return 0;
    }
  }

  /// Soft removes an entity by setting its 'deletedAt' field.
  /// Assumes the entity has 'id' (int), 'deletedAt' (DateTime?), and a 'copyWith' method.
  Future<bool> softRemove(int id) async {
    try {
      // Fetch the item directly, even if already soft-deleted (to prevent errors)
      final item = await box.getAsync(id);
      if (item == null) {
        print("Soft remove failed: Item with ID $id not found.");
        return false;
      }

      // Check if already soft-deleted
      // This requires accessing deletedAt, assuming dynamic access or an interface
      if ((item as dynamic).deletedAt != null) {
        print(
            "Soft remove skipped: Item with ID $id is already marked as deleted.");
        return true; // Indicate success as it's already in the desired state
      }

      // Use dynamic invocation for copyWith and setting deletedAt
      final nowUtc = DateTime.now().toUtc();
      final updatedItem = (item as dynamic).copyWith(
        deletedAt: nowUtc,
        // Ensure updatedAt is also updated for sync purposes
        updatedAt: DateTime.now(),
      );

      // Use the overridden put method of the subclass to ensure userId etc. are handled
      await put(updatedItem, syncSource: SyncSource.local);
      print("Soft removed item with ID $id.");
      return true;
    } catch (e, stacktrace) {
      print("Error during soft remove for ID $id: $e");
      print(stacktrace);
      return false;
    }
  }

  /// Restores a soft-removed entity by setting its 'deletedAt' field to null.
  /// Assumes the entity has 'id' (int), 'deletedAt' (DateTime?), and a 'copyWith' method.
  Future<bool> restore(int id) async {
    try {
      // Fetch the item directly, including soft-deleted ones
      final item = await box.getAsync(id);
      if (item == null) {
        print("Restore failed: Item with ID $id not found.");
        return false;
      }

      // Check if it's actually soft-deleted
      if ((item as dynamic).deletedAt == null) {
        print("Restore skipped: Item with ID $id is not marked as deleted.");
        return true; // Indicate success as it's already in the desired state
      }

      // Use dynamic invocation for copyWith and setting deletedAt to null
      final updatedItem = (item as dynamic).copyWith(
        setDeletedAtNull: true, // Use the helper flag in copyWith
        // Ensure updatedAt is also updated for sync purposes
        updatedAt: DateTime.now(),
      );

      // Use the overridden put method of the subclass
      await put(updatedItem, syncSource: SyncSource.local);
      print("Restored item with ID $id.");
      return true;
    } catch (e, stacktrace) {
      print("Error during restore for ID $id: $e");
      print(stacktrace);
      return false;
    }
  }
}
