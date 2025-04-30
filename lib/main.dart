import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_owl/backend/repositories/account_repository.dart';
import 'package:money_owl/backend/repositories/base_repository.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/repositories/transaction_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/services/auth_service.dart'; // Import AuthService
import 'package:money_owl/front/auth/auth_bloc/auth_bloc.dart'
    as auth_bloc; // Use a prefix for your local auth bloc to avoid name collision
import 'package:money_owl/front/transactions_screen/cubit/transactions_cubit.dart';
import 'package:money_owl/front/transactions_screen/widgets/navbar.dart';
import 'package:money_owl/front/settings_screen/cubit/csv_cubit.dart';
import 'package:money_owl/front/shared/filter_cubit/filter_cubit.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'backend/services/sync_service.dart';
import 'front/transactions_screen/cubit/date_cubit.dart';
import 'config/env.dart';

/// Repository providers
late TransactionRepository txRepository;
late CategoryRepository categoryRepository;
late AccountRepository accountRepository;
late SyncService syncService;
late AuthService authService; // Add AuthService instance

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  txRepository = TransactionRepository(store);

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
        RepositoryProvider<AuthService>.value(
            value: authService), // Provide AuthService
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
          BlocProvider<TransactionsCubit>(
            create: (context) => TransactionsCubit(
              context.read<TransactionRepository>(),
              context.read<AccountRepository>(),
              context.read<CategoryRepository>(),
              context.read<FilterCubit>(), // Provide FilterCubit
            ),
          ),
          BlocProvider<CsvCubit>(
            create: (context) => CsvCubit(),
          ),
          // LoginCubit and SignupCubit are provided locally in their respective screens
        ],
        child: MaterialApp(
          title: 'Money Owl',
          themeMode: ThemeMode.system,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
            useMaterial3: true,
          ),
          // Use SupabaseAuthState to handle UI based on auth state
          home: BlocBuilder<auth_bloc.AuthBloc, auth_bloc.AuthState>(
            // Use the prefix here for both Bloc and State
            builder: (context, state) {
              // Check authentication state
              if (state.status == auth_bloc.AuthStatus.authenticated) {
                // Use the prefix here
                // User is logged in, show the main app (Navigation)
                return const Navigation();
              } else {
                // User is not authenticated, show login UI
                return Scaffold(
                  appBar: AppBar(title: const Text('Login / Sign Up')),
                  body: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SupaEmailAuth(
                      onSignInComplete: (response) {
                        // AuthBloc listener will handle sync
                        print('Sign in complete');
                      },
                      onSignUpComplete: (response) {
                        // AuthBloc listener will handle sync if auto-confirm is on
                        // Or show a message if email confirmation is needed
                        print('Sign up complete');
                        if (response.session == null && response.user != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Please check your email to confirm your account.'),
                              duration: Duration(seconds: 5),
                            ),
                          );
                        }
                      },
                      onError: (error) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Authentication Error: ${error.toString()}'),
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
                          ),
                        );
                      },
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
