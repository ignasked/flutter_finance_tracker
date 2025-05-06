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
import 'package:money_owl/front/shared/navbar.dart';
import 'package:money_owl/front/shared/filter_cubit/filter_cubit.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'backend/services/sync_service.dart';
import 'front/shared/data_management_cubit/date_cubit.dart';
import 'config/env.dart';
import 'package:money_owl/front/settings_screen/cubit/importer_cubit.dart'; // Import ImporterCubit

/// Repository providers
late TransactionRepository txRepository;
late CategoryRepository categoryRepository;
late AccountRepository accountRepository;
late SyncService syncService;
late AuthService authService; // Add AuthService instance

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

  // Initialize Repositories - Inject AuthService
  accountRepository =
      AccountRepository(store, authService); // Inject AuthService
  categoryRepository =
      CategoryRepository(store, authService); // Inject AuthService
  txRepository = TransactionRepository(store, authService); // Already injected

  print("Initializing repositories...");
  await accountRepository.init();
  await categoryRepository.init();
  print("Repositories initialized.");

  // Initialize Services
  syncService = SyncService(
    supabaseClient: supabase,
    transactionRepository: txRepository,
    accountRepository: accountRepository,
    categoryRepository: categoryRepository,
  );

  // No initial sync here, AuthBloc will trigger it after login

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
          title: 'Money Owl',
          themeMode: ThemeMode.system,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
            useMaterial3: true,
          ),
          // Listen for auth state changes to show snackbar on initial auto-login
          home: BlocListener<auth_bloc.AuthBloc, auth_bloc.AuthState>(
            // Only listen when the state changes FROM non-authenticated TO authenticated
            listenWhen: (previous, current) {
              return previous.status != auth_bloc.AuthStatus.authenticated &&
                  current.status == auth_bloc.AuthStatus.authenticated;
            },
            listener: (context, state) {
              // Now we know this listener only runs on the specific transition we want
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Successfully signed in.'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 5), // Give it a short duration
                  ),
                );
            },
            // Add BlocListener to manage loading popup based on isSyncing
            child: BlocListener<auth_bloc.AuthBloc, auth_bloc.AuthState>(
              listener: (context, state) {
                if (state.status == auth_bloc.AuthStatus.authenticated) {
                  if (state.isSyncing) {
                    showLoadingPopup(context, message: 'Syncing data...');
                  } else {
                    if (Navigator.of(context).canPop()) {
                      hideLoadingPopup(context);
                    }
                  }
                }
              },
              child: BlocBuilder<auth_bloc.AuthBloc, auth_bloc.AuthState>(
                builder: (context, state) {
                  // Always show the main navigation.
                  return const Navigation();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
