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

  CategoryRepository(Store store, this._authService) : super(store) {
    _initializeDefaultCategories();
    _setDefaultCategory();
  }

  /// Factory method for asynchronous initialization
  static Future<CategoryRepository> create(
      Store store, AuthService authService) async {
    return CategoryRepository(store, authService);
  }

  /// Helper method to set default category asynchronously
  Future<void> _setDefaultCategory() async {
    final defaultCategory = await getById(1);
    if (defaultCategory != null) {
      Defaults().defaultCategory = defaultCategory;
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

  /// Initialize default categories if they don't exist (ignores deleted status for check)
  Future<void> _initializeDefaultCategories() async {
    final isFirstLaunch = await _isFirstLaunch();
    if (!isFirstLaunch) {
      final defaultCategoryExists = await box.getAsync(1);
      if (defaultCategoryExists != null &&
          defaultCategoryExists.deletedAt == null) {
        Defaults().defaultCategory = defaultCategoryExists;
      }
      return;
    }

    final defaultCategories = [
      Category(
        title: 'Food',
        descriptionForAI: 'Expenses related to food and dining',
        colorValue: AppStyle.predefinedColors[3].value, // Orange
        iconCodePoint: AppStyle.predefinedIcons[7].codePoint, // Restaurant
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Transportation',
        descriptionForAI:
            'Expenses related to transportation like fuel, public transit, taxis',
        colorValue: AppStyle.predefinedColors[1].value, // Blue
        iconCodePoint: AppStyle.predefinedIcons[2].codePoint, // Directions Car
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Accomodation',
        descriptionForAI: 'Expenses related to housing, rent, hotels',
        colorValue: AppStyle.predefinedColors[6].value, // Brown
        iconCodePoint: AppStyle.predefinedIcons[9].codePoint, // Home
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Groceries',
        descriptionForAI:
            'Expenses related to grocery shopping and household supplies',
        colorValue: AppStyle.predefinedColors[2].value, // Green
        iconCodePoint: AppStyle.predefinedIcons[8].codePoint, // Shopping Cart
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Junk Food',
        descriptionForAI: 'Expenses related to snacks and fast food',
        colorValue: AppStyle.predefinedColors[0].value, // Red
        iconCodePoint: AppStyle.predefinedIcons[1].codePoint, // Fast Food
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Services',
        descriptionForAI:
            'Expenses related to various services and subscriptions',
        colorValue: AppStyle.predefinedColors[11].value, // Indigo
        iconCodePoint:
            AppStyle.predefinedIcons[10].codePoint, // Miscellaneous Services
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Fitness',
        descriptionForAI:
            'Expenses related to gym memberships and fitness activities',
        colorValue: AppStyle.predefinedColors[10].value, // Deep Orange
        iconCodePoint: AppStyle.predefinedIcons[11].codePoint, // Fitness Center
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Entertainment',
        descriptionForAI:
            'Expenses related to entertainment and leisure activities',
        colorValue: AppStyle.predefinedColors[4].value, // Purple
        iconCodePoint: AppStyle.predefinedIcons[12].codePoint, // Sports Esports
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Healthcare',
        descriptionForAI:
            'Expenses related to medical care and health services',
        colorValue: AppStyle.predefinedColors[0].value, // Red
        iconCodePoint: AppStyle.predefinedIcons[5].codePoint, // Local Hospital
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Utilities',
        descriptionForAI:
            'Expenses related to utilities like electricity, water, internet',
        colorValue: AppStyle.predefinedColors[1].value, // Blue
        iconCodePoint: AppStyle.predefinedIcons[13].codePoint, // Power
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Clothing',
        descriptionForAI: 'Expenses related to clothes and accessories',
        colorValue: AppStyle.predefinedColors[5].value, // Pink
        iconCodePoint: AppStyle.predefinedIcons[6].codePoint, // Shopping Bag
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Deposit',
        descriptionForAI: 'Money deposited or saved from bottle returns',
        colorValue: AppStyle.predefinedColors[7].value, // Amber
        iconCodePoint: AppStyle.predefinedIcons[14].codePoint, // Recycling
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Other Expenses',
        descriptionForAI:
            'Miscellaneous expenses that don\'t fit other categories',
        colorValue: AppStyle.predefinedColors[8].value, // Grey
        iconCodePoint: AppStyle.predefinedIcons[15].codePoint, // More Horiz
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Salary',
        descriptionForAI: 'Regular income from employment',
        colorValue: AppStyle.predefinedColors[2].value, // Green
        iconCodePoint: AppStyle.predefinedIcons[16].codePoint, // Work
        typeValue: TransactionType.income.index,
      ),
      Category(
        title: 'Gifts',
        descriptionForAI: 'Recieved gifts',
        colorValue: AppStyle.predefinedColors[5].value, // Pink
        iconCodePoint: AppStyle.predefinedIcons[17].codePoint, // Card Giftcard
        typeValue: TransactionType.income.index,
      ),
      Category(
        title: 'Side Hustle',
        descriptionForAI: 'Income from side jobs or freelance work',
        colorValue: AppStyle.predefinedColors[9].value, // Teal
        iconCodePoint:
            AppStyle.predefinedIcons[18].codePoint, // Business Center
        typeValue: TransactionType.income.index,
      ),
      Category(
        title: 'Other Income',
        descriptionForAI:
            'Miscellaneous income that doesn\'t fit other categories',
        colorValue: AppStyle.predefinedColors[8].value, // Grey
        iconCodePoint: AppStyle.predefinedIcons[15].codePoint, // More Horiz
        typeValue: TransactionType.income.index,
      ),
      Category(
        title: 'Discount for item',
        descriptionForAI: 'Money saved through discounts and rebates',
        colorValue: AppStyle.predefinedColors[2].value, // Green
        iconCodePoint: AppStyle.predefinedIcons[19].codePoint, // Local Offer
        typeValue: TransactionType.income.index,
      ),
      Category(
        title: 'Overall discount',
        descriptionForAI: 'Money saved through discounts and rebates',
        colorValue: AppStyle.predefinedColors[2].value, // Green
        iconCodePoint: AppStyle.predefinedIcons[19].codePoint, // Local Offer
        typeValue: TransactionType.income.index,
      ),
    ];

    for (final defaultCategory in defaultCategories) {
      final query = box
          .query(Category_.title
              .equals(defaultCategory.title)
              .and(_userIdCondition()))
          .build();
      final existing = await query.findFirstAsync();
      query.close();

      if (existing == null) {
        try {
          await put(defaultCategory, syncSource: SyncSource.local);
          print('Added default category: ${defaultCategory.title}');
        } catch (e) {
          print('Error adding default category ${defaultCategory.title}: $e');
        }
      }
    }

    final defaultCategory = await getById(1);
    if (defaultCategory != null) {
      Defaults().defaultCategory = defaultCategory;
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
  Future<bool> _hasTransactionsForCategory(int categoryId) async {
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
          .query(Category_.id
              .equals(item.id)
              .and(Category_.userId.equals(newUserId)))
          .build();
      final existingUserItem = await existingUserItemQuery.findFirstAsync();
      existingUserItemQuery.close();

      if (existingUserItem != null) {
        print(
            "Skipping assignment for category ${item.id}: Already exists for user $newUserId.");
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
          "No categories needed userId assignment after checking for existing entries.");
      return 0;
    }
  }

  /// Soft removes all categories for the current user.
  /// Skips categories that are currently in use by active transactions.
  Future<int> removeAllForCurrentUser() async {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId == null) {
      print(
          "Warn: Attempted to remove all categories for current user, but no user is logged in.");
      return 0;
    }
    final query = box
        .query(
            Category_.userId.equals(currentUserId).and(_notDeletedCondition()))
        .build();
    final itemsToRemove = await query.findAsync();
    query.close();

    if (itemsToRemove.isEmpty) {
      print(
          "No active categories found for user $currentUserId to soft remove.");
      return 0;
    }

    int successCount = 0;
    int skippedCount = 0;
    for (final item in itemsToRemove) {
      if (await remove(item.id)) {
        successCount++;
      } else {
        skippedCount++;
      }
    }
    print("Soft removed $successCount categories for user $currentUserId." +
        (skippedCount > 0
            ? " Skipped $skippedCount due to active transactions."
            : ""));
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
