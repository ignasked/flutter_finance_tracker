import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart'; // Import for date formatting initialization
import 'package:money_owl/backend/repositories/account_repository.dart';
import 'package:money_owl/backend/repositories/base_repository.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/repositories/transaction_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/services/auth_service.dart'; // Import AuthService
import 'package:money_owl/front/auth/auth_bloc/auth_bloc.dart'
    as auth_bloc; // Use a prefix for your local auth bloc to avoid name collision
import 'package:money_owl/front/shared/data_management_cubit/data_management_cubit.dart';
import 'package:money_owl/front/shared/navbar.dart';
import 'package:money_owl/front/shared/filter_cubit/filter_cubit.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'backend/services/sync_service.dart';
import 'front/shared/data_management_cubit/date_cubit.dart';
import 'config/env.dart';

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

  // Initialize ObjectBox Store
  final store = await BaseRepository.createStore();

  // Initialize Repositories
  accountRepository = AccountRepository(store);
  categoryRepository = CategoryRepository(store);
  txRepository = TransactionRepository(store, supabase);

  // Initialize Services
  authService = AuthService(supabase); // Instantiate AuthService
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
          BlocProvider<auth_bloc.AuthBloc>(
            create: (context) => auth_bloc.AuthBloc(
              authService: context.read<AuthService>(),
              syncService: context.read<SyncService>(),
            )..add(auth_bloc.AuthSubscriptionRequested()),
          ),
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
            // The actual UI based on auth state (always shows Navigation now)
            child: BlocBuilder<auth_bloc.AuthBloc, auth_bloc.AuthState>(
              builder: (context, state) {
                // Always show the main navigation.
                return const Navigation();
              },
            ),
          ),
        ),
      ),
    );
  }
}
