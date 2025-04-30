import 'package:money_owl/backend/services/sync_service.dart'; // Import SyncSource
import 'package:money_owl/objectbox.g.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

  /// Get all entities
  List<T> getAll() {
    try {
      return box.getAll();
    } catch (e) {
      print('Error fetching all entities: $e');
      return [];
    }
  }

  /// Get an entity by ID asynchronously
  Future<T?> getById(int id) async {
    try {
      return await box.getAsync(id);
    } catch (e) {
      print('Error fetching entity with ID $id: $e');
      return null;
    }
  }

  /// Add or update an entity asynchronously.
  /// [syncSource] indicates whether the change comes from Supabase to prevent loops.
  Future<int> put(T entity, {SyncSource syncSource = SyncSource.local}) async {
    try {
      return await box.putAsync(entity);
    } catch (e) {
      print('Error adding/updating entity: $e');
      rethrow;
    }
  }

  /// Add or update multiple entities asynchronously
  Future<List<int>> putMany(List<T> entities) async {
    try {
      return await box.putManyAsync(entities);
    } catch (e) {
      print('Error adding/updating multiple entities: $e');
      rethrow;
    }
  }

  /// Remove an entity by ID asynchronously
  Future<bool> remove(int id) async {
    try {
      return await box.removeAsync(id);
    } catch (e) {
      print('Error removing entity with ID $id: $e');
      return false;
    }
  }

  /// Remove all entities asynchronously
  Future<int> removeAll() async {
    try {
      return await box.removeAllAsync();
    } catch (e) {
      print('Error removing all entities: $e');
      return 0;
    }
  }
}
