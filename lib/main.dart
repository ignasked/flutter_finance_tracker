import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart'; // Required for initializing localized date formatting
import 'package:money_owl/backend/repositories/account_repository.dart';
import 'package:money_owl/backend/repositories/base_repository.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/repositories/transaction_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/services/auth_service.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/front/auth/auth_bloc/auth_bloc.dart'
    as auth_bloc; // Aliased to avoid name collision with other AuthBlocs
import 'package:money_owl/front/common/loading_widget.dart';
import 'package:money_owl/front/shared/data_management_cubit/data_management_cubit.dart';
import 'package:money_owl/front/shared/navbar.dart'; // Main authenticated view (Navigation)
import 'package:money_owl/front/shared/filter_cubit/filter_cubit.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'backend/services/sync_service.dart';
import 'front/shared/data_management_cubit/date_cubit.dart';
import 'config/env.dart';
import 'package:money_owl/front/settings_screen/cubit/importer_cubit.dart';
import 'package:money_owl/front/auth/auth_screen.dart';

/// Repository providers
late TransactionRepository txRepository;
late CategoryRepository categoryRepository;
late AccountRepository accountRepository;
late SyncService syncService;
late AuthService authService;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize date formatting
  await initializeDateFormatting();

  // Initialize Supabase
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );
  final supabase = Supabase.instance.client;

  // Initialize Services
  authService = AuthService(supabase);

  await Defaults().loadDefaults();

  // Initialize ObjectBox Store
  final store = await BaseRepository.createStore();

  // Initialize Repositories with null SyncService
  accountRepository = AccountRepository(store, authService, null);
  categoryRepository = CategoryRepository(store, authService, null);
  txRepository = TransactionRepository(store, authService, null);

  // Initialize SyncService using the repository instances and callbacks
  syncService = SyncService(
    supabaseClient: supabase,
    transactionRepository: txRepository,
    accountRepository: accountRepository,
    categoryRepository: categoryRepository,
    onSyncStart: () {
      final context = navigatorKey.currentContext;
      if (context != null) {
        showLoadingPopup(context, message: 'Syncing data...');
      } else {
        print(
            "Error: navigatorKey.currentContext is null when trying to show loading popup via SyncService callback.");
      }
    },
    onSyncEnd: () {
      final context = navigatorKey.currentContext;
      if (context != null && Navigator.of(context).canPop()) {
        hideLoadingPopup(context);
      }
    },
  );

  // Inject SyncService back into Repositories
  accountRepository.syncService = syncService;
  categoryRepository.syncService = syncService;
  txRepository.syncService = syncService;

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
              context.read<FilterCubit>(),
            ),
          ),
          BlocProvider<ImporterCubit>(
            create: (context) => ImporterCubit(),
          ),
          BlocProvider<auth_bloc.AuthBloc>(
            create: (context) {
              void syncCompleteCallback() {
                print(
                    "AuthBloc Callback: Requesting DataManagementCubit refresh.");
                try {
                  context.read<DataManagementCubit>().refreshData();
                } catch (e) {
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
          builder: (context, child) {
            return MultiBlocListener(
              listeners: [
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
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: BlocBuilder<auth_bloc.AuthBloc, auth_bloc.AuthState>(
            builder: (context, state) {
              switch (state.status) {
                case auth_bloc.AuthStatus.authenticated:
                  return const Navigation();
                case auth_bloc.AuthStatus.unauthenticated:
                  return FutureBuilder<bool>(
                    future: _hasAnyLocalData(context),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        print("Error checking local data: ${snapshot.error}");
                        return const AuthScreen(isMandatory: false);
                      }
                      final bool hasLocalData = snapshot.data ?? false;
                      return AuthScreen(isMandatory: hasLocalData);
                    },
                  );
                case auth_bloc.AuthStatus.unknown:
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
              }
            },
          ),
        ),
      ),
    );
  }

  Future<bool> _hasAnyLocalData(BuildContext context) async {
    final txRepo = context.read<TransactionRepository>();
    final catRepo = context.read<CategoryRepository>();

    final results = await Future.wait([
      txRepo.hasLocalOnlyData(),
      catRepo.hasLocalOnlyData(),
    ]);

    return results.any((result) => result);
  }
}
