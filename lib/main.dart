import 'package:flutter/material.dart';
import 'package:pvp_projektas/backend/transaction_repository/transaction_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:pvp_projektas/front/home_screen/widgets/navbar.dart';
import 'package:pvp_projektas/front/home_screen/cubit/transaction_cubit.dart';

/// Transaction repository provider
late TransactionRepository transactionRepository;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  transactionRepository = await TransactionRepository.create();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (context) => transactionRepository,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                TransactionCubit(context.read<TransactionRepository>()),
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
