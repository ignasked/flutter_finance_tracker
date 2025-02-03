import 'package:flutter/material.dart';
import 'package:pvp_projektas/backend/transaction_repository/transaction_repository.dart';
import 'backend/objectbox_repository/objectbox.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:pvp_projektas/front/home_screen/home_screen.dart';
import 'package:pvp_projektas/front/home_screen/widgets/navbar.dart';
import 'package:pvp_projektas/backend/models/transaction.dart';
import 'package:pvp_projektas/front/home_screen/cubit/transaction_cubit.dart';

/// Provides access to the ObjectBox Store throughout the app.
late ObjectBox objectbox;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  objectbox = await ObjectBox.create();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (context) => TransactionRepository(objectbox),
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
          home: const MyHomePage(title: "Finance tracker"),
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  int currentPageIndex = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return const NavigationExample();
  }
}
