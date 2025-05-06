import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart'; // Import for date formatting initialization
import 'package:money_owl/backend/repositories/account_repository.dart';
import 'package:money_owl/backend/repositories/base_repository.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/repositories/transaction_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/services/auth_service.dart'; // Import AuthService
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/front/auth/auth_bloc/auth_bloc.dart'
    as auth_bloc; // Use a prefix for your local auth bloc to avoid name collision
import 'package:money_owl/front/common/loading_widget.dart';
import 'package:money_owl/front/shared/data_management_cubit/data_management_cubit.dart';
import 'package:money_owl/front/shared/navbar.dart'; // Assuming Navigation is your main authenticated view
import 'package:money_owl/front/shared/filter_cubit/filter_cubit.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart'; // Keep this for SupaEmailAuth
import 'backend/services/sync_service.dart';
import 'front/shared/data_management_cubit/date_cubit.dart';
import 'config/env.dart';
import 'package:money_owl/front/settings_screen/cubit/importer_cubit.dart'; // Import ImporterCubit
import 'package:money_owl/front/auth/auth_screen.dart'; // Import AuthScreen

/// Repository providers
late TransactionRepository txRepository;
late CategoryRepository categoryRepository;
late AccountRepository accountRepository;
late SyncService syncService;
late AuthService authService;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize date formatting - this fixes the LocaleDataException
  await initializeDateFormatting();

  // Initialize Supabase
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );
  final supabase = Supabase.instance.client;

  // Initialize Services
  authService = AuthService(supabase); // Instantiate AuthService

  await Defaults().loadDefaults();

  // Initialize ObjectBox Store
  final store = await BaseRepository.createStore();

  // --- MODIFIED Initialization Order ---
  // 1. Initialize Repositories with null SyncService
  accountRepository = AccountRepository(store, authService, null); // Pass null
  categoryRepository =
      CategoryRepository(store, authService, null); // Pass null
  txRepository = TransactionRepository(store, authService, null); // Pass null

  // 2. Initialize SyncService using the repository instances AND CALLBACKS
  syncService = SyncService(
    supabaseClient: supabase,
    transactionRepository: txRepository,
    accountRepository: accountRepository,
    categoryRepository: categoryRepository,
    // --- ADD CALLBACKS ---
    onSyncStart: () {
      // Use navigatorKey to get context safely
      final context = navigatorKey.currentContext;
      if (context != null) {
        showLoadingPopup(context, message: 'Syncing data...');
      } else {
        print(
            "Error: navigatorKey.currentContext is null when trying to show loading popup via SyncService callback.");
      }
    },
    onSyncEnd: () {
      // Use navigatorKey to get context safely
      final context = navigatorKey.currentContext;
      if (context != null && Navigator.of(context).canPop()) {
        hideLoadingPopup(context);
      } else {
        // print("Info: Could not hide loading popup via SyncService callback (maybe not shown or context invalid).");
      }
    },
    // --- END CALLBACKS ---
  );

  // 3. Inject SyncService back into Repositories using the public field
  accountRepository.syncService = syncService;
  categoryRepository.syncService = syncService;
  txRepository.syncService = syncService;
  // --- END MODIFIED Initialization Order ---

  print("Initializing repositories...");
  await accountRepository.init();
  await categoryRepository.init();
  print("Repositories initialized.");

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthService>.value(value: authService),
        RepositoryProvider<AccountRepository>.value(value: accountRepository),
        RepositoryProvider<CategoryRepository>.value(value: categoryRepository),
        RepositoryProvider<TransactionRepository>.value(value: txRepository),
        RepositoryProvider<SyncService>.value(value: syncService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<DateCubit>(
            create: (context) => DateCubit(),
          ),
          BlocProvider<FilterCubit>(
            create: (context) => FilterCubit(context.read<DateCubit>()),
          ),
          BlocProvider<DataManagementCubit>(
            create: (context) => DataManagementCubit(
              context.read<TransactionRepository>(),
              context.read<AccountRepository>(),
              context.read<CategoryRepository>(),
              context.read<FilterCubit>(), // Provide FilterCubit
            ),
          ),
          BlocProvider<ImporterCubit>(
            create: (context) => ImporterCubit(), // Initialize ImporterCubit
          ),
          BlocProvider<auth_bloc.AuthBloc>(
            create: (context) {
              // Define the callback function
              void syncCompleteCallback() {
                print(
                    "AuthBloc Callback: Requesting DataManagementCubit refresh.");
                // Use context.read inside the callback to get the Cubit instance
                // when the callback is actually executed.
                try {
                  context.read<DataManagementCubit>().refreshData();
                } catch (e) {
                  // Handle cases where context might be invalid if callback runs late
                  print(
                      "Error refreshing DataManagementCubit from AuthBloc callback: $e");
                }
              }

              return auth_bloc.AuthBloc(
                authService: context.read<AuthService>(),
                syncService: context.read<SyncService>(),
                transactionRepository: context.read<TransactionRepository>(),
                accountRepository: context.read<AccountRepository>(),
                categoryRepository: context.read<CategoryRepository>(),
                onSyncComplete: syncCompleteCallback,
              )..add(auth_bloc.AuthSubscriptionRequested());
            },
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Money Owl',
          themeMode: ThemeMode.system,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
            useMaterial3: true,
          ),
          // Use builder to wrap the home/navigator with global listeners
          builder: (context, child) {
            return MultiBlocListener(
              listeners: [
                // Listener for Snackbar on successful login
                BlocListener<auth_bloc.AuthBloc, auth_bloc.AuthState>(
                  listenWhen: (previous, current) {
                    return previous.status !=
                            auth_bloc.AuthStatus.authenticated &&
                        current.status == auth_bloc.AuthStatus.authenticated;
                  },
                  listener: (context, state) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text('Successfully signed in.'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 5),
                        ),
                      );
                  },
                ),
              ],
              // Pass the actual navigator content (child)
              // If builder provides a child, use it, otherwise default to SizedBox
              child: child ?? const SizedBox.shrink(),
            );
          },
          // --- MODIFIED: Initial Routing Logic ---
          home: BlocBuilder<auth_bloc.AuthBloc, auth_bloc.AuthState>(
            builder: (context, state) {
              switch (state.status) {
                case auth_bloc.AuthStatus.authenticated:
                  // User is logged in, show the main app navigation
                  return const Navigation(); // Or HomeScreen, whatever your main view is
                case auth_bloc.AuthStatus.unauthenticated:
                  // User is not logged in. Check for local data.
                  // Use a FutureBuilder to perform the async check.
                  return FutureBuilder<bool>(
                    // Combine checks from all relevant repositories
                    future: _hasAnyLocalData(context),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        // Show loading indicator while checking local data
                        return const Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        // Handle error during check, default to normal AuthScreen
                        print("Error checking local data: ${snapshot.error}");
                        return const AuthScreen(
                            isMandatory: false); // Fallback on error
                      }
                      final bool hasLocalData = snapshot.data ?? false;
                      // Navigate to AuthScreen, passing the mandatory flag
                      return AuthScreen(isMandatory: hasLocalData);
                    },
                  );
                case auth_bloc.AuthStatus.unknown:
                default:
                  // Initial state or error, show loading indicator
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
              }
            },
          ),
          // --- END MODIFIED ---
        ),
      ),
    );
  }

  // Helper function to check all repositories for local-only data
  Future<bool> _hasAnyLocalData(BuildContext context) async {
    final txRepo = context.read<TransactionRepository>();
    final catRepo = context.read<CategoryRepository>();

    // Run checks in parallel
    final results = await Future.wait([
      txRepo.hasLocalOnlyData(),
      catRepo.hasLocalOnlyData(),
    ]);

    // Return true if any repository reported local data
    return results.any((hasData) => hasData == true);
  }
}
