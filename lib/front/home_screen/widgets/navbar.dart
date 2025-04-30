import 'package:flutter/material.dart';
import 'package:money_owl/front/home_screen/home_screen.dart';
import 'package:money_owl/front/settings_screen/settings_screen.dart';
import 'package:money_owl/front/stat_screen/stat_screen.dart';
import 'package:money_owl/backend/utils/app_style.dart'; // Import AppStyle

class Navigation extends StatefulWidget {
  const Navigation({super.key});

  @override
  State<Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> {
  int currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        indicatorColor: AppStyle.primaryColor
            .withOpacity(0.2), // Use AppStyle primary color with opacity
        backgroundColor:
            AppStyle.cardColor, // Use AppStyle card color for background
        selectedIndex: currentPageIndex,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.receipt,
                color: AppStyle.primaryColor), // Use AppStyle primary color
            icon: Icon(Icons.receipt_outlined,
                color: AppStyle
                    .textColorSecondary), // Use AppStyle secondary text color
            label: 'Transactions',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.show_chart,
                color: AppStyle.primaryColor), // Use AppStyle primary color
            icon: Icon(Icons.show_chart_outlined,
                color: AppStyle
                    .textColorSecondary), // Use AppStyle secondary text color
            label: 'Statistics',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.settings,
                color: AppStyle.primaryColor), // Use AppStyle primary color
            icon: Icon(Icons.settings_outlined,
                color: AppStyle
                    .textColorSecondary), // Use AppStyle secondary text color
            label: 'Settings',
          ),
        ],
      ),
      body: <Widget>[
        const HomeScreen(),
        const StatScreen(),
        const SettingsScreen(),
      ][currentPageIndex],
    );
  }
}
