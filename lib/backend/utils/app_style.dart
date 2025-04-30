import 'package:flutter/material.dart';

class ColorPalette {
  static const Color primary =
      Color(0xFF669bbc); // Consider using AppStyle.primaryColor
  static const Color secondary = Color(0xFF003049);
  static const Color background = Color(0xFFfdf0d5);
  static const Color text =
      Color(0xFF151515); // Consider using AppStyle.textColorPrimary
  static const Color expense =
      Color(0xFFc1121f); // Consider using AppStyle.expenseColor
  static const Color income =
      Color(0xFF669bbc); // Consider using AppStyle.incomeColor
}

class AppStyle {
  // --- Colors ---
  static const Color primaryColor = Colors.amber; // Main theme color
  static const Color accentColor = Colors.deepOrangeAccent; // Accent color
  static const Color backgroundColor =
      Color(0xFFF5F5F5); // Light grey background
  static const Color cardColor = Colors.white; // Card background
  static const Color textColorPrimary =
      Color(0xFF333333); // Dark grey for main text
  static const Color textColorSecondary =
      Color(0xFF757575); // Lighter grey for subtitles
  static const Color incomeColor = Colors.green; // Color for income amounts
  static const Color expenseColor = Colors.red; // Color for expense amounts
  static const Color dividerColor = Color(0xFFE0E0E0); // Light divider color

  // --- Padding & Spacing ---
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;

  // --- Text Styles ---
  static const TextStyle heading1 = TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.bold,
    color: textColorPrimary,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 20.0,
    fontWeight: FontWeight.w600, // Semi-bold
    color: textColorPrimary,
  );

  static const TextStyle titleStyle = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w500, // Medium weight
    color: textColorPrimary,
  );

  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 14.0,
    color: textColorSecondary,
  );

  static const TextStyle bodyText = TextStyle(
    fontSize: 14.0,
    color: textColorPrimary,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 12.0,
    color: textColorSecondary,
  );

  static const TextStyle amountIncomeStyle = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.bold,
    color: incomeColor,
  );

  static const TextStyle amountExpenseStyle = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.bold,
    color: expenseColor,
  );

  static const TextStyle buttonTextStyle = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w500,
    color: Colors.white, // Assuming buttons have dark background
  );

  // --- Button Styles ---
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white, // Text color
    padding: const EdgeInsets.symmetric(
        horizontal: paddingLarge, vertical: paddingMedium / 1.2),
    textStyle: buttonTextStyle,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(paddingSmall),
    ),
  );

  static final ButtonStyle secondaryButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: primaryColor, // Text color
    side: const BorderSide(color: primaryColor),
    padding: const EdgeInsets.symmetric(
        horizontal: paddingLarge, vertical: paddingMedium / 1.2),
    textStyle:
        buttonTextStyle.copyWith(color: primaryColor), // Adjust text color
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(paddingSmall),
    ),
  );

  // --- Predefined Colors & Icons (Keep as they are used elsewhere) ---
  static const List<Color> predefinedColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.yellow,
    Colors.brown,
    Colors.pink,
    Colors.teal,
    Colors.amber,
    Colors.grey,
    Colors.deepOrange,
    Colors.indigo,
  ];

  static const List<IconData> predefinedIcons = [
    Icons.category,
    Icons.fastfood,
    Icons.directions_car,
    Icons.movie,
    Icons.attach_money,
    Icons.local_hospital,
    Icons.lightbulb,
    Icons.restaurant,
    Icons.shopping_cart,
    Icons.home,
    Icons.miscellaneous_services,
    Icons.fitness_center,
    Icons.sports_esports,
    Icons.power,
    Icons.shopping_bag,
    Icons.recycling,
    Icons.card_giftcard,
    Icons.business_center,
    Icons.local_offer,
    Icons.more_horiz,
    Icons.account_balance,
    Icons.account_balance_wallet,
  ];
}
