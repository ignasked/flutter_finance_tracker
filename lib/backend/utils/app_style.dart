import 'package:flutter/material.dart';

// Updated ColorPalette (Example - expand as needed)
class ColorPalette {
  // Primary colors
  static const Color primary = Color(0xFF6750A4); // Primary Purple
  static const Color primaryContainer = Color(0xFFEADDFF);
  static const Color onPrimary = Colors.white;
  static const Color primaryInverse = Color(0xFF31007B);

  // Secondary Colors (Accents)
  static const Color secondary = Color(0xFF625B71); // A muted purple
  static const Color secondaryContainer = Color(0xFFE8DEF8);
  static const Color onSecondary = Colors.white;

  // Tertiary Colors
  static const Color tertiary = Color(0xFF7D5260);
  static const Color tertiaryContainer = Color(0xFFFFD8E4);
  static const Color onTertiary = Colors.white;

  // Background Colors
  static const Color background = Color(0xFFFEFBFF);
  static const Color onBackground = Color(0xFF1C1B1F);
  static const Color surface = Color(0xFFFEFBFF); // Use background for surface
  static const Color onSurface = Color(0xFF1C1B1F);

  // Error Colors
  static const Color error = Color(0xFFB3261E);
  static const Color onError = Colors.white;
  static const Color errorContainer = Color(0xFFF9DEDC);
  static const Color onErrorContainer = Color(0xFF410E0B);

  // Text Colors
  static const Color textPrimary = Color(0xFF1C1B1F); // Dark grey
  static const Color textSecondary = Color(0xFF444746); // Slightly lighter grey
  static const Color textHint = Color(0xFF79747E);
  static const Color link = Color(0xFF0062A0); // For links

  // Status Colors
  static const Color success = Color(0xFF1E88E5); // Blue for success
  static const Color info = Color(0xFF1976D2); // Darker blue for info
  static const Color warning = Color(0xFFFFC107); // Yellow for warning
  static const Color disabled = Color(0xFFBDBDBD);

  // Financial Colors
  static const Color expense = Color(0xFFD32F2F); // Darker red for expenses
  static const Color income = Color(0xFF388E3C); // Darker green for income
  static const Color divider = Color(0xFFE0E0E0);
}

class AppStyle {
  // --- Colors (now using ColorPalette) ---
  static const Color primaryColor = ColorPalette.primary;
  static const Color accentColor = Colors.deepOrangeAccent; // Accent color
  static const Color secondaryColor = ColorPalette.secondary;
  static const Color tertiaryColor = ColorPalette.tertiary;
  static const Color backgroundColor = ColorPalette.background;
  static const Color cardColor =
      ColorPalette.surface; // Use background for surface
  static const Color chipBackgroundColor =
      ColorPalette.primaryContainer; // Changed
  static const Color textColorPrimary = ColorPalette.textPrimary;
  static const Color textColorSecondary = ColorPalette.textSecondary;
  static const Color incomeColor = ColorPalette.income;
  static const Color expenseColor = ColorPalette.expense;
  static const Color dividerColor = ColorPalette.divider;
  static const Color warningColor = ColorPalette.warning;
  static const Color linkColor = ColorPalette.link;

  // --- Padding & Spacing ---
  static const double paddingXSmall = 4.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  // --- Border Radius ---
  static const double borderRadiusSmall = 8.0; // Increased radius
  static const double borderRadiusMedium = 12.0; // Increased radius
  static const double borderRadiusLarge = 16.0;
  static const double borderRadiusXLarge = 24.0;

  // --- Elevation (Shadow) ---
  static const double elevationSmall = 2.0;
  static const double elevationMedium = 4.0;

  // --- Text Styles ---
  static const TextStyle heading1 = TextStyle(
    fontSize: 28.0,
    fontWeight: FontWeight.bold,
    color: textColorPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 22.0,
    fontWeight: FontWeight.w600,
    color: textColorPrimary,
    letterSpacing: -0.25,
    height: 1.3,
  );

  static const TextStyle titleStyle = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w500,
    color: textColorPrimary,
    letterSpacing: 0.15,
    height: 1.4,
  );

  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w500,
    color: textColorSecondary,
    letterSpacing: 0.1,
    height: 1.5,
  );

  static const TextStyle bodyText = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.normal,
    color: textColorPrimary,
    letterSpacing: 0.5,
    height: 1.5,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.normal,
    color: textColorSecondary,
    letterSpacing: 0.25,
    height: 1.4,
  );

  static const TextStyle amountIncomeStyle = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.bold,
    color: incomeColor,
    letterSpacing: 0.1,
  );

  static const TextStyle amountExpenseStyle = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.bold,
    color: expenseColor,
    letterSpacing: 0.1,
  );

  static const TextStyle buttonTextStyle = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.0,
    color: Colors.white,
  );

  static const TextStyle linkTextStyle = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: linkColor,
  );

  // --- Button Styles ---
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(
        horizontal: paddingLarge, vertical: paddingMedium),
    textStyle: buttonTextStyle,
    elevation: elevationSmall,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadiusMedium),
    ),
  );

  static final ButtonStyle secondaryButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: primaryColor,
    side: const BorderSide(color: primaryColor, width: 1.5),
    padding: const EdgeInsets.symmetric(
        horizontal: paddingLarge, vertical: paddingMedium),
    textStyle: buttonTextStyle.copyWith(color: primaryColor),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadiusMedium),
    ),
  );

  static final ButtonStyle textButtonStyle = TextButton.styleFrom(
    foregroundColor: primaryColor,
    padding: const EdgeInsets.symmetric(
        horizontal: paddingMedium, vertical: paddingSmall),
    textStyle: buttonTextStyle.copyWith(color: primaryColor),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadiusMedium),
    ),
  );

  static final ButtonStyle dangerButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: expenseColor,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(
        horizontal: paddingLarge, vertical: paddingMedium),
    textStyle: buttonTextStyle,
    elevation: elevationSmall,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadiusMedium),
    ),
  );

  // --- Input Decoration ---
  static InputDecoration getInputDecoration(
      {required String labelText, String? helperText, String? errorText}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: captionStyle.copyWith(color: textColorSecondary),
      helperText: helperText,
      helperStyle: captionStyle.copyWith(fontSize: 12),
      errorText: errorText,
      errorStyle:
          captionStyle.copyWith(color: ColorPalette.error, fontSize: 12),
      filled: true,
      fillColor: cardColor,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: paddingMedium, vertical: paddingMedium),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusMedium),
        borderSide: const BorderSide(color: dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusMedium),
        borderSide: const BorderSide(color: dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusMedium),
        borderSide: const BorderSide(color: primaryColor, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusMedium),
        borderSide: const BorderSide(color: ColorPalette.error),
      ),
    );
  }

  // --- Card Decoration ---
  static BoxDecoration cardDecoration = BoxDecoration(
    color: cardColor,
    borderRadius: BorderRadius.circular(borderRadiusMedium),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1), // Reduced opacity
        spreadRadius: 1,
        blurRadius: 5,
        offset: const Offset(0, 2),
      ),
    ],
  );

  // --- List Tile Style ---
  static ListTileThemeData listTileTheme = const ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(
      horizontal: paddingMedium,
      vertical: paddingSmall,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(
        Radius.circular(borderRadiusMedium),
      ),
    ),
  );

  // --- Chart Styles ---
  static ChartStyle chartStyle = ChartStyle(
    backgroundColor: cardColor,
    titleStyle: titleStyle,
    labelStyle: captionStyle,
    axisLineColor: dividerColor,
    gridLineColor: dividerColor.withOpacity(0.5),
  );

  // --- Predefined Colors & Icons (Keep as they are used elsewhere) ---
  static final List<Color> predefinedColors = [
    ColorPalette.expense, // Red
    ColorPalette.info, // Blue
    ColorPalette.income, // Green
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFFFDD835), // Yellow
    Color(0xFF795548), // Brown
    Color(0xFFE91E63), // Pink
    Color(0xFF009688), // Teal
    primaryColor, // Primary color
    Color(0xFF9E9E9E), // Grey
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF3F51B5), // Indigo
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

class ChartStyle {
  final Color backgroundColor;
  final TextStyle titleStyle;
  final TextStyle labelStyle;
  final Color axisLineColor;
  final Color gridLineColor;

  const ChartStyle({
    required this.backgroundColor,
    required this.titleStyle,
    required this.labelStyle,
    required this.axisLineColor,
    required this.gridLineColor,
  });
}
