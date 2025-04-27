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

  /// Get an entity by ID
  T? getById(int id) {
    try {
      return box.get(id);
    } catch (e) {
      print('Error fetching entity with ID $id: $e');
      return null;
    }
  }

  /// Add or update an entity
  void put(T entity) {
    try {
      box.put(entity);
    } catch (e) {
      print('Error adding/updating entity: $e');
    }
  }

  /// Add or update multiple entities
  void putMany(List<T> entities) {
    try {
      box.putMany(entities);
    } catch (e) {
      print('Error adding/updating multiple entities: $e');
    }
  }

  /// Remove an entity by ID
  void remove(int id) {
    try {
      box.remove(id);
    } catch (e) {
      print('Error removing entity with ID $id: $e');
    }
  }

  /// Remove all entities
  void removeAll() {
    try {
      box.removeAll();
    } catch (e) {
      print('Error removing all entities: $e');
    }
  }
}
