import 'package:flutter/material.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/repositories/transaction_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:money_owl/front/home_screen/widgets/navbar.dart';
import 'package:money_owl/front/home_screen/cubit/transaction_cubit.dart';

import 'front/home_screen/cubit/transaction_summary_cubit.dart';

/// Repository providers
late TransactionRepository transactionRepository;
late CategoryRepository categoryRepository;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  transactionRepository = await TransactionRepository.create();
  categoryRepository = await CategoryRepository.create();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TransactionRepository>(
          create: (context) => transactionRepository,
        ),
        RepositoryProvider<CategoryRepository>(
          create: (context) => categoryRepository,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<TransactionCubit>(
            create: (context) => TransactionCubit(transactionRepository),
          ),
          BlocProvider<TransactionSummaryCubit>(
            create: (context) => TransactionSummaryCubit(),
          ),
        ],
        child: MaterialApp(
          title: 'Finance tracker',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
            useMaterial3: true,
          ),
          home: const Navigation(),
        ),
      ),
    );
  }
}
