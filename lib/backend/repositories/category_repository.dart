import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/repositories/base_repository.dart';
import 'package:money_owl/backend/utils/app_style.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/backend/utils/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_owl/objectbox.g.dart';
import 'package:money_owl/backend/services/sync_service.dart';
import 'package:money_owl/backend/services/auth_service.dart';

class CategoryRepository extends BaseRepository<Category> {
  final AuthService _authService;

  CategoryRepository(Store store, this._authService) : super(store);

  /// Asynchronous initialization method
  Future<void> init() async {
    await _initializeDefaultCategories();
    await _setDefaultCategory(); // Ensure this is also awaited
  }

  /// Factory method for asynchronous initialization
  static Future<CategoryRepository> create(
      Store store, AuthService authService) async {
    return CategoryRepository(store, authService);
  }

  /// Helper method to set default category asynchronously
  Future<void> _setDefaultCategory() async {
    // Use getById which respects user context and deleted status
    final defaultCategory = await getById(1);
    if (defaultCategory != null) {
      Defaults().defaultCategory = defaultCategory;
    } else {
      // Fallback logic if default ID 1 isn't found after init
      final userCondition = _userIdCondition();
      final anyCategoryQuery =
          box.query(userCondition.and(_notDeletedCondition())).build();
      final fallbackCategory = await anyCategoryQuery.findFirstAsync();
      anyCategoryQuery.close();
      if (fallbackCategory != null) {
        Defaults().defaultCategory = fallbackCategory;
        print(
            "Set fallback default category during init: ${fallbackCategory.title}");
      } else {
        print("Error during init: No categories available to set as default.");
      }
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

  get defaultCategoriesData => [
        Category(
          title: 'Food',
          descriptionForAI: 'Expenses related to food and dining',
          colorValue: AppStyle.predefinedColors[3].value, // Orange
          iconCodePoint:
              AppStyle.predefinedIcons[7].codePoint, // restaurant_outlined
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Transportation',
          descriptionForAI:
              'Expenses related to transportation like fuel, public transit, taxis',
          colorValue: AppStyle.predefinedColors[1].value, // Blue
          iconCodePoint: AppStyle
              .predefinedIcons[2].codePoint, // directions_car_filled_outlined
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Accomodation',
          descriptionForAI: 'Expenses related to housing, rent, hotels',
          colorValue: AppStyle.predefinedColors[6].value, // Brown
          iconCodePoint: AppStyle.predefinedIcons[9].codePoint, // home_outlined
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Groceries',
          descriptionForAI:
              'Expenses related to grocery shopping and household supplies',
          colorValue: AppStyle.predefinedColors[2].value, // Green
          iconCodePoint:
              AppStyle.predefinedIcons[8].codePoint, // shopping_cart_outlined
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Junk Food',
          descriptionForAI: 'Expenses related to snacks and fast food',
          colorValue: AppStyle.predefinedColors[0].value, // Red
          iconCodePoint:
              AppStyle.predefinedIcons[1].codePoint, // fastfood_outlined
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Services',
          descriptionForAI:
              'Expenses related to various services and subscriptions',
          colorValue: AppStyle.predefinedColors[11].value, // Indigo
          iconCodePoint: AppStyle
              .predefinedIcons[10].codePoint, // miscellaneous_services_outlined
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Fitness',
          descriptionForAI:
              'Expenses related to gym memberships and fitness activities',
          colorValue: AppStyle.predefinedColors[10].value, // Deep Orange
          iconCodePoint:
              AppStyle.predefinedIcons[11].codePoint, // fitness_center_outlined
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Entertainment',
          descriptionForAI:
              'Expenses related to entertainment and leisure activities',
          colorValue: AppStyle.predefinedColors[4].value, // Purple
          iconCodePoint:
              AppStyle.predefinedIcons[12].codePoint, // sports_esports_outlined
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Healthcare',
          descriptionForAI:
              'Expenses related to medical care and health services',
          colorValue: AppStyle.predefinedColors[0].value, // Red
          iconCodePoint:
              AppStyle.predefinedIcons[5].codePoint, // local_hospital_outlined
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Utilities',
          descriptionForAI:
              'Expenses related to utilities like electricity, water, internet',
          colorValue: AppStyle.predefinedColors[1].value, // Blue
          iconCodePoint:
              AppStyle.predefinedIcons[13].codePoint, // power_settings_new
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Clothing',
          descriptionForAI: 'Expenses related to clothes and accessories',
          colorValue: AppStyle.predefinedColors[5].value, // Pink
          iconCodePoint:
              AppStyle.predefinedIcons[14].codePoint, // shopping_bag_outlined
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Deposit', // Assuming this relates to recycling/returns
          descriptionForAI: 'Money deposited or saved from bottle returns',
          colorValue: AppStyle.predefinedColors[7].value, // Amber
          iconCodePoint:
              AppStyle.predefinedIcons[15].codePoint, // recycling_outlined
          typeValue: TransactionType
              .expense.index, // Should this be income? Keeping expense for now.
        ),
        Category(
          title: 'Other Expenses',
          descriptionForAI:
              'Miscellaneous expenses that don\'t fit other categories',
          colorValue: AppStyle.predefinedColors[8].value, // Grey
          iconCodePoint: AppStyle.predefinedIcons[19].codePoint, // more_horiz
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Salary',
          descriptionForAI: 'Regular income from employment',
          colorValue: AppStyle.predefinedColors[2].value, // Green
          iconCodePoint: AppStyle.predefinedIcons[4].codePoint, // attach_money
          typeValue: TransactionType.income.index,
        ),
        Category(
          title: 'Gifts',
          descriptionForAI: 'Recieved gifts',
          colorValue: AppStyle.predefinedColors[5].value, // Pink
          iconCodePoint:
              AppStyle.predefinedIcons[16].codePoint, // card_giftcard_outlined
          typeValue: TransactionType.income.index,
        ),
        Category(
          title: 'Side Hustle',
          descriptionForAI: 'Income from side jobs or freelance work',
          colorValue: AppStyle.predefinedColors[9].value, // Teal
          iconCodePoint: AppStyle
              .predefinedIcons[17].codePoint, // business_center_outlined
          typeValue: TransactionType.income.index,
        ),
        Category(
          title: 'Other Income',
          descriptionForAI:
              'Miscellaneous income that doesn\'t fit other categories',
          colorValue: AppStyle.predefinedColors[8].value, // Grey
          iconCodePoint: AppStyle.predefinedIcons[19].codePoint, // more_horiz
          typeValue: TransactionType.income.index,
        ),
        Category(
          title: 'Discount for item', // Using local_offer
          descriptionForAI: 'Money saved through discounts and rebates',
          colorValue: AppStyle.predefinedColors[2].value, // Green
          iconCodePoint:
              AppStyle.predefinedIcons[18].codePoint, // local_offer_outlined
          typeValue: TransactionType.income.index,
        ),
        Category(
          title: 'Overall discount', // Using local_offer
          descriptionForAI: 'Money saved through discounts and rebates',
          colorValue: AppStyle.predefinedColors[2].value, // Green
          iconCodePoint:
              AppStyle.predefinedIcons[18].codePoint, // local_offer_outlined
          typeValue: TransactionType.income.index,
        ),
      ];

  /// Initialize default categories if they don't exist (ignores deleted status for check)
  Future<void> _initializeDefaultCategories() async {
    final isFirstLaunch = await _isFirstLaunch();
    if (!isFirstLaunch) {
      // Still need to set the default category if it exists
      final defaultCategory = await getById(1); // Check non-deleted default
      if (defaultCategory != null) {
        Defaults().defaultCategory = defaultCategory;
      }
      return;
    }

    print("First launch detected, initializing default categories...");

    // 2. Get existing category titles for the current context in one query
    final userCondition =
        _userIdCondition(); // Get condition for current user/local
    final existingTitlesQuery = box.query(userCondition).build();
    // Use findIds() and then getMany() or just find() if memory is not a concern
    final existingCategories = await existingTitlesQuery.findAsync();
    existingTitlesQuery.close();
    final existingTitles = existingCategories.map((c) => c.title).toSet();

    // 3. Filter default categories that don't exist yet
    final List<Category> categoriesToAdd = [];
    for (final defaultCategory in defaultCategoriesData) {
      if (!existingTitles.contains(defaultCategory.title)) {
        // Prepare for batch insertion (userId and timestamps will be set by putMany)
        categoriesToAdd.add(defaultCategory);
      }
    }

    // 4. Batch insert the missing categories
    if (categoriesToAdd.isNotEmpty) {
      try {
        // Use putMany which handles setting userId and timestamps for local source
        await putMany(categoriesToAdd, syncSource: SyncSource.local);
        print('Added ${categoriesToAdd.length} default categories in batch.');
      } catch (e) {
        print('Error adding default categories in batch: $e');
        // Handle potential batch errors if necessary
      }
    } else {
      print("All default categories already exist for the current context.");
    }

    // 5. Set the default category (assuming ID 1 is still the intended default)
    // Use getById which respects the user context and deleted status
    final defaultCategory = await getById(1);
    if (defaultCategory != null) {
      Defaults().defaultCategory = defaultCategory;
      print("Default category set.");
    } else {
      print(
          "Warning: Default category (ID 1) not found or not accessible after initialization.");
      // Attempt to find *any* category if the default (ID 1) isn't available
      final anyCategoryQuery =
          box.query(userCondition.and(_notDeletedCondition())).build();
      final fallbackCategory = await anyCategoryQuery.findFirstAsync();
      anyCategoryQuery.close();
      if (fallbackCategory != null) {
        Defaults().defaultCategory = fallbackCategory;
        print("Set fallback default category: ${fallbackCategory.title}");
      } else {
        print("Error: No categories available to set as default.");
        // Consider creating a fallback 'Uncategorized' category here if none exist
      }
    }
  }

  Future<bool> _isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('isFirstLaunchCategories') ?? true;
    if (isFirstLaunch) {
      await prefs.setBool('isFirstLaunchCategories', false);
    }
    return isFirstLaunch;
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

  /// Override put to update timestamps, set userId, and handle deletedAt.
  @override
  Future<int> put(Category category,
      {SyncSource syncSource = SyncSource.local}) async {
    final currentUserId = _authService.currentUser?.id;

    if (syncSource == SyncSource.local) {
      final now = DateTime.now();
      Category categoryToSave;

      if (category.id == 0) {
        categoryToSave = category.copyWith(
          userId: currentUserId,
          createdAt: now,
          updatedAt: now,
          deletedAt: category.deletedAt,
        );
      } else {
        final existing = await box.getAsync(category.id);
        if (existing == null) {
          print(
              "Warning: Attempted to update non-existent category ID: ${category.id}");
          return category.id;
        }
        if (existing.userId != currentUserId) {
          print(
              "Error: Attempted to update category with mismatched userId context. Existing: ${existing.userId}, Current: $currentUserId");
          throw Exception(
              "Cannot modify data belonging to a different user context.");
        }
        categoryToSave = category.copyWith(
          userId: currentUserId,
          updatedAt: now,
          createdAt:
              category.createdAt != DateTime.fromMillisecondsSinceEpoch(0)
                  ? category.createdAt
                  : existing.createdAt,
        );
      }

      if (categoryToSave.userId != currentUserId) {
        print(
            "Error: Mismatched userId (${categoryToSave.userId}) during save for current context ($currentUserId).");
        throw Exception("Data integrity error: User ID mismatch.");
      }
      return await super.put(categoryToSave, syncSource: syncSource);
    } else {
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

  /// Soft removes a category by ID if it belongs to the current context.
  @override
  Future<bool> remove(int id) async {
    final hasTransactions = await _hasTransactionsForCategory(id);
    if (hasTransactions) {
      print(
          "Soft remove failed: Category $id is still linked to active transactions.");
      return false;
    }
    return await super.softRemove(id);
  }

  /// Helper to check if a category is used by non-deleted transactions.
  bool _hasTransactionsForCategory(int categoryId) {
    final transactionBox = store.box<Transaction>();
    // --- FIX: Query using the generated relation field 'category' ---
    final query = transactionBox
        .query(Transaction_.category // Use the relation field directly
            .equals(categoryId) // ObjectBox handles matching the target ID
            .and(Transaction_.deletedAt.isNull())
            .and(_transactionUserIdCondition()))
        .build();
    // --- END FIX ---
    final count = query.count(); // Use async count
    query.close();
    return count > 0;
  }

  Condition<Transaction> _transactionUserIdCondition() {
    final currentUserId = _authService.currentUser?.id;
    return currentUserId != null
        ? Transaction_.userId.equals(currentUserId)
        : Transaction_.userId.isNull();
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
    // --- MODIFIED: Condition to target non-default IDs ---
    final Condition<Category> nonDefaultIdCondition =
        Category_.id.greaterThan(defaultCategoriesData.length);
    // --- END MODIFICATION ---

    // Combine all conditions using the '&' operator
    final Condition<Category> finalCondition = userCondition &
        notDeletedCondition &
        nonDefaultIdCondition; // Use the new ID condition

    // Build the query with the combined condition
    final query = box.query(finalCondition).build(); // Build the Query object

    final categoriesToDelete = await query.findAsync(); // Find using the Query
    query.close(); // Close the Query object after finding

    if (categoriesToDelete.isEmpty) {
      print(
          "No non-default categories (ID > 18) found to delete for user: ${currentUserId ?? 'unauthenticated'}");
      return 0;
    }

    int successCount = 0;
    int skippedCount = 0;
    for (final item in categoriesToDelete) {
      // Use super.softRemove directly as the check for transactions is complex here
      // and we are explicitly deleting non-defaults.
      // If you need the transaction check, call `remove(item.id)` instead.
      // If you need the transaction check, call `remove(item.id)` instead.
      if (await super.softRemove(item.id)) {
        successCount++;
      } else {
        // This might happen if softRemove fails for other reasons
        skippedCount++;
      }
    }
    print(
        "Soft removed $successCount non-default categories (ID > 18) for user ${currentUserId ?? 'unauthenticated'}." +
            (skippedCount > 0 ? " Skipped $skippedCount." : ""));
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
    if (syncSource == SyncSource.supabase) {
      final entitiesToSave = entities
          .map((e) => e.copyWith(
              createdAt: e.createdAt.toLocal(),
              updatedAt: e.updatedAt.toLocal(),
              deletedAt: e.deletedAt?.toLocal()))
          .toList();
      return await super.putMany(entitiesToSave, syncSource: syncSource);
    } else {
      final currentUserId = _authService.currentUser?.id;
      final now = DateTime.now();
      final List<Category> processedEntities = [];
      for (final entity in entities) {
        Category entityToSave;
        if (entity.id == 0) {
          entityToSave = entity.copyWith(
            userId: currentUserId,
            createdAt: now,
            updatedAt: now,
            deletedAt: entity.deletedAt,
          );
        } else {
          entityToSave = entity.copyWith(
            userId: currentUserId,
            updatedAt: now,
            createdAt:
                entity.createdAt != DateTime.fromMillisecondsSinceEpoch(0)
                    ? entity.createdAt
                    : now,
          );
        }
        processedEntities.add(entityToSave);
      }
      return await super.putMany(processedEntities, syncSource: syncSource);
    }
  }
}
