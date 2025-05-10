import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/repositories/base_repository.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/objectbox.g.dart';
import 'package:money_owl/backend/services/sync_service.dart';
import 'package:money_owl/backend/services/auth_service.dart';
import 'package:uuid/uuid.dart'; // Make sure you have this import and the package in pubspec.yaml

class CategoryRepository extends BaseRepository<Category> {
  final AuthService _authService;
  SyncService? syncService; // <-- Make public and nullable

  // Modify constructor to accept nullable SyncService
  CategoryRepository(Store store, this._authService, this.syncService)
      : super(store);

  /// Asynchronous initialization method
  Future<void> init() async {
    // Do not call initializeDefaultCategories or setDefaultCategory here
  }

  /// Factory method for asynchronous initialization
  static Future<CategoryRepository> create(
      Store store, AuthService authService, SyncService syncService) async {
    return CategoryRepository(store, authService, syncService);
  }

  /// Make these public for AuthBloc to call after sync
  Future<void> initializeDefaultCategories() async {
    final userCondition = _userIdCondition();
    final notDeleted = _notDeletedCondition();

    // Check if the user already has ANY categories. This is a more reliable check.
    final existingCategoriesQuery =
        box.query(userCondition.and(notDeleted)).build();
    final bool userHasCategories = (existingCategoriesQuery.count()) > 0;
    existingCategoriesQuery.close();

    if (userHasCategories) {
      print(
          "User already has categories. Skipping default category initialization.");
      return;
    }

    // If user has no categories, initialize all defaults with new UUIDs
    print("User has no categories. Initializing defaults with unique UUIDs...");

    final List<Category> categoriesToAdd = [];
    final Uuid uuidGenerator = Uuid(); // Create a Uuid instance once

    for (final template in Defaults().defaultCategoriesData) {
      categoriesToAdd.add(
        Category(
          uuid: uuidGenerator
              .v4(), // Generate a NEW, UNIQUE UUID for this instance
          title: template.title,
          descriptionForAI: template.descriptionForAI,
          colorValue: template.colorValue,
          iconCodePoint: template.iconCodePoint,
          typeValue: template.typeValue,
          isEnabled: template.isEnabled,
        ),
      );
    }

    if (categoriesToAdd.isNotEmpty) {
      try {
        await putMany(categoriesToAdd, syncSource: SyncSource.local);
        print(
            'Added ${categoriesToAdd.length} default categories in batch with unique UUIDs.');
      } catch (e) {
        print('Error adding default categories in batch: $e');
      }
    } else {
      print("Default categories data is empty. Nothing to add.");
    }
  }

  /// Make these public for AuthBloc to call after sync
  Future<void> setDefaultCategory() async {
    // 1. Try loading using the ID stored in Defaults
    if (Defaults().defaultCategoryId != null) {
      final defaultCategory = await getById(Defaults().defaultCategoryId!);
      if (defaultCategory != null) {
        Defaults().setDefaultCategoryInstance(defaultCategory);
        // No need to save here, as the ID hasn't changed
        print("Defaults: Set default category instance from saved ID.");
        return; // Successfully set from saved ID
      } else {
        // ID was saved, but category not found (e.g., deleted)
        print(
            "Warning: Default category ID ${Defaults().defaultCategoryId} found in prefs, but category not found in DB. Resetting default.");
        // Proceed to fallback logic below
      }
    }

    // 2. Fallback logic if default ID isn't set or category wasn't found
    final userCondition = _userIdCondition();
    final anyCategoryQuery =
        box.query(userCondition.and(_notDeletedCondition())).build();
    final fallbackCategory = await anyCategoryQuery.findFirstAsync();
    anyCategoryQuery.close();

    if (fallbackCategory != null) {
      Defaults().setDefaultCategoryInstance(fallbackCategory);
      await Defaults().saveDefaults(); // Save the new fallback default ID
      print(
          "Set fallback default category during init: ${fallbackCategory.title}");
    } else {
      print("Error during init: No categories available to set as default.");
      // Consider setting Defaults()._defaultCategoryId = null and saving?
      // For now, it will remain null or the old invalid ID.
    }
  }

  /// Get the user ID condition based on auth state.
  Condition<Category> _userIdCondition() {
    final currentUserId = _authService.currentUser?.id;
    return currentUserId != null
        ? Category_.userId.equals(currentUserId)
        : Category_.userId.isNull();
  }

  /// Condition to filter out soft-deleted items.
  Condition<Category> _notDeletedCondition() {
    return Category_.deletedAt.isNull();
  }

  /// Check if a category title is unique among non-deleted categories
  Future<bool> isTitleUnique(String title) async {
    try {
      final query = box
          .query(Category_.title
              .equals(title)
              .and(_userIdCondition())
              .and(_notDeletedCondition()))
          .build();
      final isUnique = (query.count()) == 0;
      query.close();
      return isUnique;
    } catch (e) {
      print('Error checking if title is unique: $e');
      return false;
    }
  }

  /// Fetch only enabled and non-deleted categories asynchronously
  Future<List<Category>> getEnabledCategories() async {
    try {
      final query = box
          .query(Category_.isEnabled
              .equals(true)
              .and(_userIdCondition())
              .and(_notDeletedCondition()))
          .build();
      final enabledCategories = await query.findAsync();
      query.close();
      return enabledCategories;
    } catch (e) {
      print('Error fetching enabled categories asynchronously: $e');
      return [];
    }
  }

  /// Fetch enabled and non-deleted category titles as a comma-separated string (now async)
  Future<String> getEnabledCategoryTitles() async {
    final enabledCategories = await getEnabledCategories();
    if (enabledCategories.isEmpty) {
      return 'No enabled categories';
    }
    return enabledCategories.map((category) => category.title).join(', ');
  }

  Future<Category> getDefaultCategory() async {
    return await getById(Defaults().defaultCategoryId ?? 1) ??
        Defaults()
            .defaultCategoriesData
            .first; // Fallback to first default category
  }

  /// Get categories modified after a specific time (UTC) for the current context.
  Future<List<Category>> getAllModifiedSince(DateTime time) async {
    final query = box
        .query(Category_.updatedAt
            .greaterThan(time.toUtc().millisecondsSinceEpoch)
            .and(_userIdCondition()))
        .build();
    final results = await query.findAsync();
    query.close();
    return results;
  }

  /// Override put to update timestamps, set userId, and push changes.
  @override
  Future<int> put(Category category,
      {SyncSource syncSource = SyncSource.local}) async {
    final currentUserId = _authService.currentUser?.id;
    int resultId = category.id; // Initialize with incoming ID

    if (syncSource == SyncSource.local) {
      final now = DateTime.now();
      Category categoryToSave;

      if (category.id == 0) {
        // New category
        categoryToSave = category.copyWith(
          userId: currentUserId,
          createdAt: now,
          updatedAt: now,
          deletedAt: category.deletedAt,
        );
      } else {
        // Existing category
        final existing = await box.getAsync(category.id);
        if (existing == null) {
          print(
              "Warning: Attempted to update non-existent category ID: ${category.id}");
          return category.id;
        }
        // Check context
        if (existing.userId != currentUserId) {
          if (existing.userId != null) {
            print(
                "Error: Attempted to update category with mismatched userId context. Existing: ${existing.userId}, Current: $currentUserId");
            throw Exception(
                "Cannot modify data belonging to a different user context.");
          }
          print(
              "Info: Assigning userId $currentUserId to category ID ${category.id}");
        }

        categoryToSave = category.copyWith(
          userId: currentUserId, // Ensure context
          updatedAt: now, // Always update timestamp
          createdAt:
              category.createdAt != DateTime.fromMillisecondsSinceEpoch(0)
                  ? category.createdAt
                  : existing.createdAt, // Preserve original createdAt
        );
      }

      if (categoryToSave.userId != currentUserId) {
        print(
            "Error: Mismatched userId (${categoryToSave.userId}) during save for current context ($currentUserId).");
        throw Exception("Data integrity error: User ID mismatch.");
      }

      // Use super.put to save locally
      resultId = await super.put(categoryToSave, syncSource: syncSource);

      // --- Push Change Immediately (Fire-and-Forget) ---
      if (resultId != 0 && syncService != null) {
        final savedItem = await box.getAsync(resultId);
        if (savedItem != null) {
          print(
              "Pushing change for Category ID $resultId immediately after local put (no await).");
          syncService!
              .pushSingleUpsert<Category>(savedItem)
              .catchError((pushError) {
            print(
                "Background push error for Category ID $resultId: $pushError");
          });
        } else {
          print(
              "Warning: Could not fetch Category ID $resultId after put for immediate push.");
        }
      } else if (syncService == null) {
        print(
            "Warning: syncService is null in CategoryRepository.put. Cannot push change immediately.");
      }
      // --- End Push Change ---

      return resultId; // Return immediately
    } else {
      // Syncing down from Supabase
      if (category.userId == null) {
        print(
            "Warning: Syncing down category with null userId. ID: ${category.id}");
      }
      final categoryToSave = category.copyWith(
          createdAt: category.createdAt.toLocal(),
          updatedAt: category.updatedAt.toLocal(),
          deletedAt: category.deletedAt?.toLocal());
      return await super.put(categoryToSave, syncSource: syncSource);
    }
  }

  /// Fetch all non-deleted categories for the current context.
  @override
  Future<List<Category>> getAll() async {
    try {
      final query =
          box.query(_userIdCondition().and(_notDeletedCondition())).build();
      final results = await query.findAsync();
      query.close();

      setDefaultCategory(); // Ensure default category is set after fetching
      return results;
    } catch (e) {
      final context = _authService.currentUser?.id ?? 'local (unauthenticated)';
      print('Error fetching categories for context $context: $e');
      return [];
    }
  }

  /// Fetch a category by ID if it belongs to the current context and is not soft-deleted.
  @override
  Future<Category?> getById(int id) async {
    try {
      final query = box
          .query(Category_.id
              .equals(id)
              .and(_userIdCondition())
              .and(_notDeletedCondition()))
          .build();
      final result = await query.findFirstAsync();
      query.close();
      return result;
    } catch (e) {
      final context = _authService.currentUser?.id ?? 'local (unauthenticated)';
      print("Error fetching category $id for context $context: $e");
      return null;
    }
  }

  /// Fetch multiple categories by their IDs for the current context.
  /// Optionally includes soft-deleted items.
  Future<List<Category>> getManyByIds(List<int> ids,
      {bool includeDeleted = false}) async {
    // Added includeDeleted parameter
    if (ids.isEmpty) return [];
    // Remove duplicates and 0 if present
    final uniqueIds = ids.where((id) => id != 0).toSet().toList();
    if (uniqueIds.isEmpty) return [];

    try {
      // Base condition: match IDs and user context
      Condition<Category> condition =
          Category_.id.oneOf(uniqueIds) & _userIdCondition();

      // Conditionally add the 'notDeleted' filter
      if (!includeDeleted) {
        condition = condition & _notDeletedCondition();
      }

      final query = box.query(condition).build();
      final results = await query.findAsync();
      query.close();
      return results;
    } catch (e) {
      final context = _authService.currentUser?.id ?? 'local (unauthenticated)';
      print('Error fetching multiple categories for context $context: $e');
      return [];
    }
  }

  /// Helper to check if a category is used by non-deleted transactions.
  bool _hasTransactionsForCategory(int categoryId) {
    final transactionBox = store.box<Transaction>();
    final query = transactionBox
        .query(Transaction_.category
            .equals(categoryId)
            .and(Transaction_.deletedAt.isNull())
            .and(_transactionUserIdCondition()))
        .build();
    final count = query.count();
    query.close();
    return count > 0;
  }

  Condition<Transaction> _transactionUserIdCondition() {
    final currentUserId = _authService.currentUser?.id;
    return currentUserId != null
        ? Transaction_.userId.equals(currentUserId)
        : Transaction_.userId.isNull();
  }

  /// Soft removes a category by ID if it belongs to the current context,
  /// is not a default category, and has no transactions.
  @override
  Future<bool> remove(int id) async {
    final currentUserId = _authService.currentUser?.id;
    // Prevent deletion of default categories
    if (id >= 1 && id <= Defaults().defaultCategoriesData.length) {
      print("Error: Cannot delete default category ID $id.");
      return false; // Indicate failure
    }

    // Check for transactions
    final hasTransactions = _hasTransactionsForCategory(id);
    if (hasTransactions) {
      print("Error: Cannot delete category ID $id, it has transactions.");
      return false; // Indicate failure
    }

    try {
      // Fetch the item, ensuring it belongs to the user and is not deleted
      final query = box
          .query(Category_.id
              .equals(id)
              .and(_userIdCondition())
              .and(_notDeletedCondition()))
          .build();
      final item = await query.findFirstAsync();
      query.close();

      if (item == null) {
        print(
            "Soft remove failed: Category $id not found, doesn't belong to user $currentUserId, or already deleted.");
        return false;
      }

      // Prepare the update for soft delete
      final now = DateTime.now();
      final nowUtc = now.toUtc();
      final itemToUpdate = item.copyWith(
        deletedAt: nowUtc,
        updatedAt: now, // Also update 'updatedAt' for sync mechanisms
      );

      // --- ADD: Push delete immediately (Fire-and-Forget) ---
      if (syncService != null) {
        print("Pushing soft delete for Category ID $id (no await).");
        syncService!
            .pushSingleUpsert<Category>(itemToUpdate)
            .catchError((pushError) {
          print(
              "Background push error during remove for Category ID $id: $pushError");
        });
      } else {
        print(
            "Warning: syncService is null in CategoryRepository.remove. Cannot push delete immediately.");
      }
      // --- END ADD ---

      // Perform the local update using box directly
      await box.putAsync(itemToUpdate);
      print("Soft removed Category $id locally.");
      return true;
    } catch (e, stacktrace) {
      print("Error during soft remove for Category ID $id: $e");
      print(stacktrace);
      return false;
    }
  }

  /// Restores a soft-deleted category by ID if it belongs to the current context.
  Future<bool> restoreCategory(int id) async {
    return await super.restore(id);
  }

  /// Updates categories with null userId to the provided newUserId.
  /// Skips soft-deleted categories.
  Future<int> assignUserIdToNullEntries(String newUserId) async {
    final query = box
        .query(Category_.userId.isNull().and(_notDeletedCondition()))
        .build();
    final nullUserItems = await query.findAsync();
    query.close();

    if (nullUserItems.isEmpty) {
      return 0;
    }

    print(
        "Assigning userId $newUserId to ${nullUserItems.length} local-only categories...");

    final List<Category> updatedItems = [];
    final now = DateTime.now();

    for (final item in nullUserItems) {
      final existingUserItemQuery = box
          .query(Category_.uuid
              .equals(item.uuid)
              .and(Category_.userId.equals(newUserId)))
          .build();
      final existingUserItem = await existingUserItemQuery.findFirstAsync();
      existingUserItemQuery.close();

      if (existingUserItem != null) {
        print(
            "Skipping assignment for category UUID ${item.uuid}: Already exists for user $newUserId with ID ${existingUserItem.id}. Consider merging or deleting local item ID ${item.id}.");
        continue;
      }
      updatedItems.add(item.copyWith(
        userId: newUserId,
        updatedAt: now,
      ));
    }

    if (updatedItems.isNotEmpty) {
      await putMany(updatedItems, syncSource: SyncSource.local);
      print(
          "Successfully assigned userId $newUserId to ${updatedItems.length} categories.");
      return updatedItems.length;
    } else {
      print(
          "No categories needed userId assignment after checking for existing entries by UUID.");
      return 0;
    }
  }

  /// Soft deletes all categories for the currently logged-in user that are NOT considered default (ID > 18).
  /// If no user is logged in, performs the same logic for categories with a null userId.
  Future<int> removeNonDefaultForCurrentUser() async {
    final currentUserId = _authService.currentUser?.id;

    // Define the base condition based on user authentication state
    final Condition<Category> userCondition = currentUserId != null
        ? Category_.userId.equals(currentUserId)
        : Category_.userId.isNull();

    // Define common conditions
    final Condition<Category> notDeletedCondition =
        Category_.deletedAt.isNull();
    final Condition<Category> nonDefaultIdCondition =
        Category_.id.greaterThan(Defaults().defaultCategoriesData.length);

    final Condition<Category> finalCondition =
        userCondition & notDeletedCondition & nonDefaultIdCondition;

    final query = box.query(finalCondition).build();

    final categoriesToDelete = await query.findAsync();
    query.close();

    if (categoriesToDelete.isEmpty) {
      print(
          "No non-default categories (ID > 18) found to delete for user: ${currentUserId ?? 'unauthenticated'}");
      return 0;
    }

    int successCount = 0;
    int skippedCount = 0;
    final now = DateTime.now();
    final nowUtc = now.toUtc();
    final List<Category> itemsToSoftDelete = [];

    for (final item in categoriesToDelete) {
      final hasTransactions = _hasTransactionsForCategory(item.id);
      if (hasTransactions) {
        print("Skipping delete for Category ID ${item.id}: Has transactions.");
        skippedCount++;
        continue;
      }
      itemsToSoftDelete.add(item.copyWith(
        deletedAt: nowUtc,
        updatedAt: now,
      ));
    }

    if (syncService != null && itemsToSoftDelete.isNotEmpty) {
      print(
          "Pushing ${itemsToSoftDelete.length} category deletes using pushUpsertMany (no await).");
      syncService!
          .pushUpsertMany<Category>(itemsToSoftDelete)
          .catchError((pushError) {
        print(
            "Background push error during pushUpsertMany for deleting Categories: $pushError");
      });
    } else if (syncService == null) {
      print(
          "Warning: syncService is null in removeNonDefaultForCurrentUser. Cannot push deletes immediately.");
    }

    if (itemsToSoftDelete.isNotEmpty) {
      try {
        await box.putManyAsync(itemsToSoftDelete);
        successCount = itemsToSoftDelete.length;
      } catch (e) {
        print(
            "Error during local putManyAsync in removeNonDefaultForCurrentUser: $e");
      }
    }

    print(
        "Attempted soft remove for $successCount non-default categories (ID > ${Defaults().defaultCategoriesData.length}) for user ${_authService.currentUser?.id ?? 'unauthenticated'}.${skippedCount > 0 ? " Skipped $skippedCount." : ""}");
    return successCount;
  }

  /// Override removeAll from BaseRepository.
  @override
  Future<int> removeAll() async {
    print(
        "Error: Direct call to removeAll() is disabled for safety. Use removeAllForCurrentUser() instead.");
    throw UnimplementedError(
        "Use removeAllForCurrentUser() to soft-delete user-specific data.");
  }

  /// Override putMany to handle syncSource correctly.
  @override
  Future<List<int>> putMany(List<Category> entities,
      {SyncSource syncSource = SyncSource.local}) async {
    List<int> resultIds = [];
    if (syncSource == SyncSource.supabase) {
      final entitiesToSave = entities
          .map((e) => e.copyWith(
              createdAt: e.createdAt.toLocal(),
              updatedAt: e.updatedAt.toLocal(),
              deletedAt: e.deletedAt?.toLocal()))
          .toList();
      resultIds = await super.putMany(entitiesToSave, syncSource: syncSource);
    } else {
      final currentUserId = _authService.currentUser?.id;
      final now = DateTime.now();
      final List<Category> processedEntities = [];
      final existingIds =
          entities.map((e) => e.id).where((id) => id != 0).toList();
      final existingMap = {
        for (var e
            in (await box.getManyAsync(existingIds)).whereType<Category>())
          e.id: e
      };

      for (final entity in entities) {
        Category entityToSave;
        if (entity.id == 0) {
          entityToSave = entity.copyWith(
            userId: currentUserId,
            createdAt:
                (entity.id == 0 || existingMap[entity.id]?.createdAt == null)
                    ? now
                    : existingMap[entity.id]!.createdAt,
            updatedAt: now,
          );
        } else if (entity.id == 0) {
          entityToSave = entity.copyWith(
            userId: currentUserId,
            createdAt: now,
            updatedAt: now,
            deletedAt: entity.deletedAt,
          );
        } else {
          final existing = existingMap[entity.id];
          entityToSave = entity.copyWith(
            userId: currentUserId,
            updatedAt: now,
            createdAt: existing?.createdAt ?? now,
            deletedAt: entity.deletedAt,
          );
        }
        processedEntities.add(entityToSave);
      }
      if (processedEntities.isNotEmpty) {
        resultIds =
            await super.putMany(processedEntities, syncSource: syncSource);

        if (resultIds.isNotEmpty && syncService != null) {
          print(
              "Pushing ${resultIds.length} categories after local putMany using pushUpsertMany (no await).");
          final savedItems = (await box.getManyAsync(resultIds))
              .whereType<Category>()
              .toList();
          if (savedItems.isNotEmpty) {
            syncService!
                .pushUpsertMany<Category>(savedItems)
                .catchError((pushError) {
              print(
                  "Background push error during pushUpsertMany for Categories: $pushError");
            });
          } else {
            print(
                "Warning: Could not fetch saved categories after putMany for push.");
          }
        } else if (syncService == null) {
          print(
              "Warning: syncService is null in CategoryRepository.putMany. Cannot push changes immediately.");
        }
      } else {
        resultIds = [];
      }
    }
    return resultIds;
  }

  /// Checks if any non-deleted categories exist with a null userId.
  Future<bool> hasLocalOnlyData() async {
    try {
      final defaultIds = Defaults()
          .defaultCategoriesData
          .map((c) => c.id)
          .where((id) => id != 0)
          .toList();

      Condition<Category> condition =
          Category_.userId.isNull().and(_notDeletedCondition());

      if (defaultIds.isNotEmpty) {
        condition = condition.and(Category_.id.notOneOf(defaultIds));
      }

      final query = box.query(condition).build();
      final count = query.count();
      query.close();
      return count > 0;
    } catch (e) {
      print("Error checking for local-only category data: $e");
      return false;
    }
  }

  /// Hard deletes all categories for the currently logged-in user, including remote (Supabase) deletion.
  Future<int> hardDeleteAllForCurrentUser() async {
    final userCondition = _userIdCondition();
    final query = box.query(userCondition).build();
    final items = await query.findAsync();
    query.close();
    if (items.isEmpty) return 0;
    final ids = items.map((c) => c.id).toList();

    // --- Push remote deletes to Supabase (fire-and-forget) ---
    if (syncService != null) {
      for (final item in items) {
        try {
          // Use pushDeleteByUuid to ensure remote deletion by uuid (Supabase expects uuid as PK)
          syncService!
              .pushDeleteByUuid('categories', item.uuid)
              .catchError((e) {
            print(
                "Supabase delete error for Category UUID \\${item.uuid}: \\${e.toString()}");
          });
        } catch (e) {
          print(
              "Exception during Supabase delete for Category UUID \\${item.uuid}: \\${e.toString()}");
        }
      }
    } else {
      print(
          "Warning: syncService is null in hardDeleteAllForCurrentUser. Cannot push remote deletes.");
    }
    // --- End remote delete ---

    await box.removeManyAsync(ids);
    print("Hard deleted ${ids.length} categories for user (local and remote).");
    return ids.length;
  }
}
