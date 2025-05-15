// import 'package:money_owl/backend/models/account.dart';
// import 'package:money_owl/backend/models/category.dart';
// import 'package:money_owl/backend/models/transaction.dart';
// import 'package:money_owl/backend/repositories/account_repository.dart';
// import 'package:money_owl/backend/repositories/category_repository.dart';
// import 'package:money_owl/backend/repositories/transaction_repository.dart';
// import 'package:money_owl/backend/services/currency_service.dart';
// import 'package:money_owl/backend/utils/calculate_balances_utils.dart';
// import 'package:money_owl/backend/utils/enums.dart';
// import 'package:money_owl/front/shared/data_management_cubit/data_management_cubit.dart';
// import 'package:money_owl/front/shared/filter_cubit/filter_cubit.dart';
// import 'package:money_owl/front/shared/filter_cubit/filter_state.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:bloc_test/bloc_test.dart';
// import 'package:mockito/annotations.dart';
// import 'package:mockito/mockito.dart';
// import 'package:money_owl/backend/utils/enums.dart'
//     as money_owl_enums; // Alias for money_owl enums

// // Import the generated mocks
// import 'data_management_cubit_test.mocks.dart';

// // Define default filter state for tests
// final defaultInitialFilterState = FilterState(
//   startDate: DateTime(2020, 1, 1),
//   endDate: DateTime(2025, 12, 31),
//   selectedAccountIds: {},
//   selectedCategoryIds: {},
//   transactionType: money_owl_enums.TransactionType.all,
//   searchTerm: '',
//   showTransfers: true,
// );

// @GenerateMocks([
//   TransactionRepository,
//   AccountRepository,
//   CategoryRepository,
//   FilterCubit,
//   CurrencyService, // Added CurrencyService
// ])
// void main() {
//   late DataManagementCubit dataManagementCubit;
//   late MockTransactionRepository mockTransactionRepository;
//   late MockAccountRepository mockAccountRepository;
//   late MockCategoryRepository mockCategoryRepository;
//   late MockFilterCubit mockFilterCubit;
//   late MockCurrencyService mockCurrencyService; // Added mockCurrencyService

//   // Sample data
//   final mockAccount1 = Account(
//       id: 1,
//       uuid: 'acc1-uuid',
//       name: 'Account 1',
//       currency: 'USD',
//       typeValue: 0,
//       colorValue: 0,
//       iconCodePoint: 0,
//       balance: 1000);
//   final mockAccount2 = Account(
//       id: 2,
//       uuid: 'acc2-uuid',
//       name: 'Account 2',
//       currency: 'EUR',
//       typeValue: 0,
//       colorValue: 0,
//       iconCodePoint: 0,
//       balance: 500);
//   final mockCategory1 = Category(
//       id: 1,
//       uuid: 'cat1-uuid',
//       title: 'Food',
//       colorValue: 0,
//       iconCodePoint: 0,
//       typeValue: TransactionType.expense.index);
//   final mockCategory2 = Category(
//       id: 2,
//       uuid: 'cat2-uuid',
//       title: 'Salary',
//       colorValue: 0,
//       iconCodePoint: 0,
//       typeValue: TransactionType.income.index);

//   final mockTransaction1 = Transaction.createWithIds(
//     id: 1,
//     uuid: 'txn1-uuid',
//     title: 'Groceries',
//     amount: -50,
//     date: DateTime(2024, 1, 10),
//     categoryId: mockCategory1.id,
//     fromAccountId: mockAccount1.id,
//   );
//   final mockTransaction2 = Transaction.createWithIds(
//     id: 2,
//     uuid: 'txn2-uuid',
//     title: 'Salary',
//     amount: 2000,
//     date: DateTime(2024, 1, 15),
//     categoryId: mockCategory2.id,
//     fromAccountId: mockAccount1.id, // Assuming salary goes into Account 1
//   );

//   setUp(() {
//     mockTransactionRepository = MockTransactionRepository();
//     mockAccountRepository = MockAccountRepository();
//     mockCategoryRepository = MockCategoryRepository();
//     mockFilterCubit = MockFilterCubit();
//     mockCurrencyService =
//         MockCurrencyService(); // Initialize mockCurrencyService

//     // Stub the stream for FilterCubit
//     when(mockFilterCubit.stream)
//         .thenAnswer((_) => Stream.value(defaultInitialFilterState));
//     when(mockFilterCubit.state).thenReturn(defaultInitialFilterState);

//     // Stub CurrencyService convertAmount (important for _calculateSummary)
//     // This is a generic stub, adjust if specific conversions are needed for tests
//     when(mockCurrencyService.convertAmount(any, any, any))
//         .thenAnswer((invocation) async {
//       // For simplicity, assume 1:1 conversion if source and target are same, else just return amount
//       if (invocation.positionalArguments[1] ==
//           invocation.positionalArguments[2]) {
//         return invocation.positionalArguments[0] as double;
//       }
//       return invocation.positionalArguments[0]
//           as double; // Or a mocked conversion rate
//     });
//     when(mockCurrencyService.getBaseCurrency()).thenAnswer((_) async => 'USD');

//     dataManagementCubit = DataManagementCubit(
//       transactionRepository: mockTransactionRepository,
//       accountRepository: mockAccountRepository,
//       categoryRepository: mockCategoryRepository,
//       filterCubit: mockFilterCubit,
//       currencyService: mockCurrencyService, // Pass mockCurrencyService
//     );

//     // Default stubs for initial data loading to avoid UnimplementedError
//     when(mockTransactionRepository.getAllTransactions())
//         .thenAnswer((_) async => []);
//     when(mockAccountRepository.getAllAccounts()).thenAnswer((_) async => []);
//     when(mockCategoryRepository.getAllCategories()).thenAnswer((_) async => []);
//     when(mockAccountRepository.getAccountById(any))
//         .thenAnswer((_) async => null);
//     when(mockCategoryRepository.getCategoryById(any))
//         .thenAnswer((_) async => null);
//   });

//   tearDown(() {
//     dataManagementCubit.close();
//     reset(mockFilterCubit); // Reset the mock after each test
//   });

//   test('initial state is DataManagementInitial', () {
//     expect(dataManagementCubit.state, equals(DataManagementInitial()));
//   });

//   group('_loadInitialData (via refreshData)', () {
//     final transactions = [mockTransaction1, mockTransaction2];
//     final accounts = [mockAccount1, mockAccount2];
//     final categories = [mockCategory1, mockCategory2];

//     blocTest<DataManagementCubit, DataManagementState>(
//       'emits [DataManagementLoading, DataManagementLoaded] with all data when successful',
//       setUp: () {
//         when(mockTransactionRepository.getAllTransactions())
//             .thenAnswer((_) async => transactions);
//         when(mockAccountRepository.getAllAccounts())
//             .thenAnswer((_) async => accounts);
//         when(mockCategoryRepository.getAllCategories())
//             .thenAnswer((_) async => categories);

//         // Mock getById for summary calculation if transactions have relations
//         when(mockAccountRepository.getAccountById(mockAccount1.id))
//             .thenAnswer((_) async => mockAccount1);
//         when(mockAccountRepository.getAccountById(mockAccount2.id))
//             .thenAnswer((_) async => mockAccount2);
//         when(mockCategoryRepository.getCategoryById(mockCategory1.id))
//             .thenAnswer((_) async => mockCategory1);
//         when(mockCategoryRepository.getCategoryById(mockCategory2.id))
//             .thenAnswer((_) async => mockCategory2);
//       },
//       build: () => dataManagementCubit,
//       act: (cubit) => cubit.refreshData(source: 'test'),
//       expect: () {
//         final expectedSummary = CalculateBalancesUtils.calculateSummary(
//           transactions: transactions,
//           accounts: accounts,
//           categories: categories,
//           baseCurrency: 'USD', // Assuming USD is base from mockCurrencyService
//           currencyService: mockCurrencyService,
//           activeFilters: defaultInitialFilterState,
//         );
//         return [
//           DataManagementLoading(
//             state: DataManagementInitial(),
//             operation: CrudOperation.read,
//             dataType: DataType.all,
//           ),
//           isA<DataManagementLoaded>()
//               .having((state) => state.allTransactions, 'allTransactions',
//                   transactions)
//               .having(
//                   (state) => state.filteredTransactions,
//                   'filteredTransactions',
//                   transactions) // Assuming no filter initially
//               .having((state) => state.allAccounts, 'allAccounts', accounts)
//               .having(
//                   (state) => state.allCategories, 'allCategories', categories)
//               .having((state) => state.summary.totalIncome, 'totalIncome',
//                   expectedSummary.totalIncome)
//               .having((state) => state.summary.totalExpenses, 'totalExpenses',
//                   expectedSummary.totalExpenses)
//               .having((state) => state.summary.netBalance, 'netBalance',
//                   expectedSummary.netBalance),
//         ];
//       },
//       verify: (_) {
//         verify(mockTransactionRepository.getAllTransactions()).called(1);
//         verify(mockAccountRepository.getAllAccounts()).called(1);
//         verify(mockCategoryRepository.getAllCategories()).called(1);
//       },
//     );

//     blocTest<DataManagementCubit, DataManagementState>(
//       'emits [DataManagementLoading, DataManagementError] when repository throws error',
//       setUp: () {
//         when(mockTransactionRepository.getAllTransactions())
//             .thenThrow(Exception('Failed to load transactions'));
//         when(mockAccountRepository.getAllAccounts())
//             .thenAnswer((_) async => []); // Still provide defaults for others
//         when(mockCategoryRepository.getAllCategories())
//             .thenAnswer((_) async => []);
//       },
//       build: () => dataManagementCubit,
//       act: (cubit) => cubit.refreshData(source: 'test_error'),
//       expect: () => [
//         DataManagementLoading(
//           state: DataManagementInitial(),
//           operation: CrudOperation.read,
//           dataType: DataType.all,
//         ),
//         isA<DataManagementError>().having((e) => e.message, 'message',
//             contains('Failed to load initial data')),
//       ],
//     );
//   });

//   group('addTransaction', () {
//     final newTransaction = Transaction.createWithIds(
//       id: 3, // New ID
//       uuid: 'txn3-uuid',
//       title: 'New Expense',
//       amount: -25,
//       date: DateTime(2024, 1, 20),
//       categoryId: mockCategory1.id,
//       fromAccountId: mockAccount1.id,
//     );

//     // Initial data that will be in the state before adding
//     final initialTransactions = [mockTransaction1];
//     final initialAccounts = [mockAccount1];
//     final initialCategories = [mockCategory1];

//     // Data that will be returned by repositories after adding the new transaction
//     final transactionsAfterAdd = [...initialTransactions, newTransaction];

//     blocTest<DataManagementCubit, DataManagementState>(
//       'emits [DataManagementLoading, DataManagementLoaded] with new transaction and updated summary on successful add',
//       setUp: () {
//         // Mock the addTransaction repository call
//         when(mockTransactionRepository.addTransaction(newTransaction))
//             .thenAnswer((_) async => newTransaction.id);

//         // Mock repository calls for _loadInitialData:
//         // First call by constructor (via build), second call by refreshData (in act)
//         when(mockTransactionRepository.getAllTransactions())
//             .thenAnswer(
//                 (_) async => initialTransactions) // For constructor's load
//             .thenAnswer((_) async =>
//                 transactionsAfterAdd); // For refreshData's load after add

//         when(mockAccountRepository.getAllAccounts())
//             .thenAnswer((_) async => initialAccounts) // For constructor
//             .thenAnswer((_) async => initialAccounts); // For refreshData

//         when(mockCategoryRepository.getAllCategories())
//             .thenAnswer((_) async => initialCategories) // For constructor
//             .thenAnswer((_) async => initialCategories); // For refreshData

//         // Mocks for getById needed by summary calculation (called during _loadInitialData)
//         // Assuming these are called consistently for both initial load and refresh
//         when(mockAccountRepository.getAccountById(mockAccount1.id))
//             .thenAnswer((_) async => mockAccount1);
//         when(mockCategoryRepository.getCategoryById(mockCategory1.id))
//             .thenAnswer((_) async => mockCategory1);
//         // Ensure any other getById calls made by calculateSummary are mocked if newTransaction involves different accounts/categories
//       },
//       build: () => dataManagementCubit,
//       act: (cubit) => cubit.addTransaction(newTransaction),
//       expect: () {
//         final expectedSummaryAfterAdd = CalculateBalancesUtils.calculateSummary(
//           transactions: transactionsAfterAdd,
//           accounts: initialAccounts,
//           categories: initialCategories,
//           baseCurrency: 'USD',
//           currencyService: mockCurrencyService,
//           activeFilters: defaultInitialFilterState,
//         );

//         // Expected state after constructor has loaded initial data
//         final loadedStateAfterConstructor = isA<DataManagementLoaded>()
//             .having((s) => s.allTransactions, 'allTransactions',
//                 initialTransactions)
//             .having((s) => s.allAccounts, 'allAccounts', initialAccounts)
//             .having((s) => s.allCategories, 'allCategories', initialCategories);

//         return [
//           isA<DataManagementLoading>()
//               .having((s) => s.operation, 'operation', CrudOperation.create)
//               .having((s) => s.dataType, 'dataType', DataType.transaction)
//               .having((s) => s.state, 'previous state before add op',
//                   loadedStateAfterConstructor),
//           isA<DataManagementLoaded>()
//               .having((s) => s.allTransactions, 'allTransactions',
//                   transactionsAfterAdd)
//               .having((s) => s.filteredTransactions, 'filteredTransactions',
//                   transactionsAfterAdd)
//               .having((s) => s.allAccounts, 'allAccounts', initialAccounts)
//               .having(
//                   (s) => s.allCategories, 'allCategories', initialCategories)
//               .having((s) => s.summary.totalIncome, 'totalIncome',
//                   expectedSummaryAfterAdd.totalIncome)
//               .having((s) => s.summary.totalExpenses, 'totalExpenses',
//                   expectedSummaryAfterAdd.totalExpenses)
//               .having((s) => s.summary.netBalance, 'netBalance',
//                   expectedSummaryAfterAdd.netBalance)
//               .having((s) => s.lastOperation, 'lastOperation',
//                   CrudOperation.create) // Check last op
//               .having((s) => s.lastDataType, 'lastDataType',
//                   DataType.transaction), // Check last data type
//         ];
//       },
//       verify: (_) {
//         verify(mockTransactionRepository.addTransaction(newTransaction))
//             .called(1);
//         // getAllTransactions is called twice: once by constructor, once by refreshData
//         verify(mockTransactionRepository.getAllTransactions()).called(2);
//         verify(mockAccountRepository.getAllAccounts()).called(2);
//         verify(mockCategoryRepository.getAllCategories()).called(2);
//       },
//     );

//     blocTest<DataManagementCubit, DataManagementState>(
//       'emits [DataManagementLoading, DataManagementError] when addTransaction throws an error',
//       setUp: () {
//         // Mock for the failing addTransaction call
//         when(mockTransactionRepository.addTransaction(newTransaction))
//             .thenThrow(Exception('DB error'));

//         // Mocks for the initial data load by the constructor (which will succeed)
//         when(mockTransactionRepository.getAllTransactions())
//             .thenAnswer((_) async => initialTransactions);
//         when(mockAccountRepository.getAllAccounts())
//             .thenAnswer((_) async => initialAccounts);
//         when(mockCategoryRepository.getAllCategories())
//             .thenAnswer((_) async => initialCategories);
//         when(mockAccountRepository.getAccountById(mockAccount1.id))
//             .thenAnswer((_) async => mockAccount1);
//         when(mockCategoryRepository.getCategoryById(mockCategory1.id))
//             .thenAnswer((_) async => mockCategory1);
//       },
//       build: () => dataManagementCubit,
//       act: (cubit) => cubit.addTransaction(newTransaction),
//       expect: () {
//         // Expected state after constructor has loaded initial data (this is the state before addTransaction fails)
//         final loadedStateAfterConstructor = isA<DataManagementLoaded>()
//             .having((s) => s.allTransactions, 'allTransactions',
//                 initialTransactions)
//             .having((s) => s.allAccounts, 'allAccounts', initialAccounts)
//             .having((s) => s.allCategories, 'allCategories', initialCategories);

//         return [
//           isA<DataManagementLoading>()
//               .having((s) => s.operation, 'operation', CrudOperation.create)
//               .having((s) => s.dataType, 'dataType', DataType.transaction)
//               .having((s) => s.state, 'previous state before add op',
//                   loadedStateAfterConstructor),
//           isA<DataManagementError>()
//               .having((e) => e.message, 'message',
//                   'Failed to add transaction: Exception: DB error')
//               .having((e) => e.state, 'state before error',
//                   loadedStateAfterConstructor), // Error state should also hold the state before the failed op
//         ];
//       },
//       verify: (_) {
//         verify(mockTransactionRepository.addTransaction(newTransaction))
//             .called(1);
//         // getAllTransactions etc. from constructor load should be called once.
//         verify(mockTransactionRepository.getAllTransactions()).called(1);
//         verify(mockAccountRepository.getAllAccounts()).called(1);
//         verify(mockCategoryRepository.getAllCategories()).called(1);
//         // No second call from refreshData because addTransaction failed before it.
//       },
//     );
//   });
// }

// // Helper to create a simple loaded state for setting up tests if needed
// DataManagementLoaded createInitialLoadedState({
//   List<Transaction>? transactions,
//   List<Account>? accounts,
//   List<Category>? categories,
//   required MockCurrencyService currencyService,
//   required FilterState filterState,
// }) {
//   final txns = transactions ?? [];
//   final accs = accounts ?? [];
//   final cats = categories ?? [];
//   final summary = CalculateBalancesUtils.calculateSummary(
//     transactions: txns,
//     accounts: accs,
//     categories: cats,
//     baseCurrency: 'USD',
//     currencyService: currencyService,
//     activeFilters: filterState,
//   );
//   return DataManagementLoaded(
//     allTransactions: txns,
//     filteredTransactions: txns,
//     allAccounts: accs,
//     allCategories: cats,
//     summary: summary,
//     lastOperation: CrudOperation.read,
//     lastDataType: DataType.all,
//     timestamp: DateTime.now(),
//   );
// }
