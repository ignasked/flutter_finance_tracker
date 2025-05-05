import 'package:flutter/material.dart';

// ==========================================================================
// NEW Color Palette - Professional Blue/Teal Theme
// ==========================================================================
class ColorPalette {
  // --- Primary (Blue) ---
  static const Color primary = Color(0xFF0A84FF); // A strong, accessible blue
  static const Color primaryContainer =
      Color(0xFFD1E8FF); // Light blue container
  static const Color onPrimary = Colors.white; // Text/icon on primary
  static const Color primaryInverse =
      Color(0xFF003A75); // For inverse surface, if needed

  // --- Secondary (Teal/Green Accent) ---
  static const Color secondary = Color(0xFF40C4A0); // Teal accent
  static const Color secondaryContainer =
      Color(0xFFD9F7EF); // Light teal container
  static const Color onSecondary =
      Color(0xFF00382B); // Dark text/icon on secondary
  static const Color onSecondaryContainer =
      Color(0xFF00513F); // Dark text/icon on secondary container

  // --- Tertiary (Neutral Warm Grey/Subtle Contrast) ---
  static const Color tertiary = Color(0xFFB0A8B9); // Muted lavender/grey
  static const Color tertiaryContainer =
      Color(0xFFF0EBF4); // Very light version
  static const Color onTertiary = Color(0xFF3E3546); // Dark text on tertiary
  static const Color onTertiaryContainer =
      Color(0xFF281E30); // Dark text on tertiary container

  // --- Backgrounds ---
  static const Color background =
      Color(0xFFF8F9FA); // Slightly off-white background
  static const Color onBackground =
      Color(0xFF1A1A1A); // Very dark grey text on background
  static const Color surface =
      Color(0xFFFFFFFF); // Pure white for cards/surfaces
  static const Color onSurface =
      Color(0xFF1A1A1A); // Very dark grey text on surfaces
  static const Color surfaceVariant =
      Color(0xFFEEF0F2); // Slightly grey surface variant
  static const Color onSurfaceVariant =
      Color(0xFF43474E); // Medium grey text on surface variant
  static const Color outline = Color(0xFFDCDFE4); // Border color

  // --- Status & Financial ---
  static const Color error = Color(0xFFD8344F); // Slightly softer red for error
  static const Color onError = Colors.white;
  static const Color errorContainer = Color(0xFFFFDADB);
  static const Color onErrorContainer = Color(0xFF410002);

  static const Color income = Color(0xFF28A745); // A clear, positive green
  static const Color expense =
      Color(0xFFDC3545); // A clear, warning red (matches error slightly)

  static const Color warning = Color(0xFFFFC107); // Standard warning yellow
  static const Color onWarning = Color(0xFF332700); // Dark text for warning bg
  static const Color warningContainer =
      Color(0xFFFFE083); // Light warning container

  static const Color success = Color(0xFF198754); // Bootstrap success green
  static const Color info = Color(0xFF0D6EFD); // Bootstrap info blue

  // --- Text ---
  static const Color textPrimary =
      Color(0xFF1A1A1A); // Main text (onBackground/onSurface)
  static const Color textSecondary =
      Color(0xFF6E6E73); // Subdued text (iOS secondary grey)
  static const Color textHint =
      Color(0xFF8A8A8E); // Hint text (iOS tertiary grey)
  static const Color link = primary; // Use primary color for links
  static const Color disabled = Color(0xFFBDBDBD); // Disabled elements

  // --- Utility ---
  static const Color divider =
      Color(0xFFE5E5EA); // Light divider (iOS separator grey)
}

// ==========================================================================
// AppStyle - References the NEW ColorPalette
// ==========================================================================
class AppStyle {
  // --- Colors (Referencing new ColorPalette) ---
  static const Color primaryColor = ColorPalette.primary;
  static const Color accentColor =
      ColorPalette.secondary; // Use new secondary as accent
  static const Color secondaryColor = ColorPalette.secondary;
  static const Color tertiaryColor = ColorPalette.tertiary;
  static const Color backgroundColor = ColorPalette.background;
  static const Color cardColor = ColorPalette.surface; // White cards
  static const Color chipBackgroundColor =
      ColorPalette.primaryContainer; // Light blue chips
  static const Color textColorPrimary = ColorPalette.textPrimary;
  static const Color textColorSecondary = ColorPalette.textSecondary;
  static const Color incomeColor = ColorPalette.income; // New income green
  static const Color expenseColor = ColorPalette.expense; // New expense red
  static const Color dividerColor = ColorPalette.divider; // New divider grey
  static const Color warningColor = ColorPalette.warning;
  static const Color linkColor = ColorPalette.link; // Uses primary blue

  // --- Padding & Spacing (Unchanged) ---
  static const double paddingXSmall = 4.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  // --- Border Radius (Unchanged) ---
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;
  static const double borderRadiusXLarge = 24.0;

  // --- Elevation (Shadow) (Unchanged) ---
  static const double elevationSmall =
      1.0; // Slightly reduced elevation for flatter look
  static const double elevationMedium = 3.0;
  static const double cardElevation = elevationMedium; // Alias for common usage

  // --- Text Styles (Updated Colors) ---
  static const TextStyle heading1 = TextStyle(
    fontSize: 28.0,
    fontWeight: FontWeight.bold,
    color: textColorPrimary, // Updated color
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 22.0,
    fontWeight: FontWeight.w600,
    color: textColorPrimary, // Updated color
    letterSpacing: -0.25,
    height: 1.3,
  );
  static const TextStyle headingStyle =
      heading2; // Alias for common usage (e.g., card titles)

  static const TextStyle titleStyle = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w500, // Medium weight
    color: textColorPrimary, // Updated color
    letterSpacing: 0.1, // Slightly tighter spacing
    height: 1.4,
  );

  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.normal, // Normal weight for subtitle
    color: textColorSecondary, // Updated color
    letterSpacing: 0.1,
    height: 1.5,
  );

  static const TextStyle bodyText = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.normal,
    color: textColorPrimary, // Updated color
    letterSpacing: 0.3, // Adjusted spacing
    height: 1.5,
  );
  static const TextStyle bodyTextSecondary =
      captionStyle; // Alias for less important text

  static const TextStyle captionStyle = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.normal,
    color: textColorSecondary, // Updated color
    letterSpacing: 0.25,
    height: 1.4,
  );

  static const TextStyle amountIncomeStyle = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w600, // Semibold for amounts
    color: incomeColor, // Updated color
    letterSpacing: 0.1,
  );

  static const TextStyle amountExpenseStyle = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w600, // Semibold for amounts
    color: expenseColor, // Updated color
    letterSpacing: 0.1,
  );

  // Button text is usually onPrimary or on<Color>
  static const TextStyle buttonTextStyle = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5, // Less spacing for buttons
    // Color is defined by ButtonStyle foregroundColor
  );

  static const TextStyle linkTextStyle = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: linkColor, // Updated color
  );

  // --- Button Styles (Updated Colors & Minor Tweaks) ---
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor, // Updated color
    foregroundColor: ColorPalette.onPrimary, // Updated color
    padding: const EdgeInsets.symmetric(
        horizontal: paddingLarge, vertical: paddingMedium),
    textStyle: buttonTextStyle,
    elevation: elevationSmall,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadiusMedium),
    ),
  );

  static final ButtonStyle secondaryButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: primaryColor, // Updated color
    side: const BorderSide(color: primaryColor, width: 1.5), // Updated color
    padding: const EdgeInsets.symmetric(
        horizontal: paddingLarge, vertical: paddingMedium),
    textStyle: buttonTextStyle.copyWith(
        color: primaryColor), // Text color matches foreground
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadiusMedium),
    ),
  );

  static final ButtonStyle textButtonStyle = TextButton.styleFrom(
    foregroundColor: primaryColor, // Updated color
    padding: const EdgeInsets.symmetric(
        horizontal: paddingMedium, vertical: paddingSmall),
    textStyle: buttonTextStyle.copyWith(
        color: primaryColor), // Text color matches foreground
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadiusMedium),
    ),
  );

  static final ButtonStyle dangerButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: expenseColor, // Updated color (using expense red)
    foregroundColor: ColorPalette.onError, // Text on error color
    padding: const EdgeInsets.symmetric(
        horizontal: paddingLarge, vertical: paddingMedium),
    textStyle: buttonTextStyle,
    elevation: elevationSmall,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadiusMedium),
    ),
  );

  // --- Input Decoration (Updated Colors) ---
  static InputDecoration getInputDecoration({
    required String labelText,
    String? helperText,
    String? errorText,
    Widget? prefixIcon, // Added optional prefix/suffix icons
    Widget? suffixIcon,
    Color? fillColor, // Allow overriding fill color
    InputBorder? border, // Allow overriding border
    EdgeInsets? contentPadding, // Allow overriding padding
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle:
          captionStyle.copyWith(color: textColorSecondary), // Updated color
      helperText: helperText,
      helperStyle: captionStyle.copyWith(
          fontSize: 12, color: textColorSecondary), // Updated color
      errorText: errorText,
      errorStyle: captionStyle.copyWith(
          color: ColorPalette.error, fontSize: 12), // Updated color
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fillColor ?? cardColor, // Default to cardColor (white)
      contentPadding: contentPadding ??
          const EdgeInsets.symmetric(
              horizontal: paddingMedium, vertical: paddingMedium),
      border: border ??
          OutlineInputBorder(
            // Default border style
            borderRadius: BorderRadius.circular(borderRadiusMedium),
            borderSide: const BorderSide(
                color: ColorPalette.outline), // Use outline color
          ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusMedium),
        borderSide:
            const BorderSide(color: ColorPalette.outline), // Use outline color
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusMedium),
        borderSide:
            const BorderSide(color: primaryColor, width: 2.0), // Updated color
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusMedium),
        borderSide:
            const BorderSide(color: ColorPalette.error), // Updated color
      ),
      focusedErrorBorder: OutlineInputBorder(
        // Added focused error border
        borderRadius: BorderRadius.circular(borderRadiusMedium),
        borderSide: const BorderSide(color: ColorPalette.error, width: 2.0),
      ),
      disabledBorder: OutlineInputBorder(
        // Added disabled border
        borderRadius: BorderRadius.circular(borderRadiusMedium),
        borderSide: BorderSide(color: ColorPalette.outline.withOpacity(0.5)),
      ),
    );
  }

  // --- Card Decoration (Updated Shadow) ---
  static BoxDecoration cardDecoration = BoxDecoration(
    color: cardColor, // Updated color (white)
    borderRadius: BorderRadius.circular(borderRadiusMedium),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.06), // Even subtler shadow
        spreadRadius: 0, // No spread
        blurRadius: 10, // Soft blur
        offset: const Offset(0, 4), // Slightly larger offset
      ),
    ],
  );

  // --- List Tile Style (Unchanged, relies on theme) ---
  static ListTileThemeData listTileTheme = ListTileThemeData(
    // Define it explicitly
    contentPadding: const EdgeInsets.symmetric(
      horizontal: paddingMedium,
      vertical: paddingSmall,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(
        Radius.circular(borderRadiusMedium),
      ),
    ),
    tileColor: cardColor, // Set default tile color if needed
    selectedTileColor: primaryColor.withOpacity(0.1), // Example selection color
  );

  // --- Chart Styles (Updated Colors) ---
  // Note: ChartStyle class itself doesn't need changes, just its usage
  static ChartStyle chartStyle = ChartStyle(
    backgroundColor: cardColor, // Updated color
    titleStyle: titleStyle, // Uses updated text style
    labelStyle: captionStyle, // Uses updated text style
    axisLineColor: dividerColor, // Updated color
    gridLineColor: dividerColor.withOpacity(0.5), // Updated color
  );

  // --- Predefined Colors & Icons (Updated Palette) ---
  // Use these for default category colors etc.
  static final List<Color> predefinedColors = [
    ColorPalette.primary, // Blue
    ColorPalette.secondary, // Teal
    ColorPalette.income, // Green
    ColorPalette.warning, // Yellow
    ColorPalette.tertiary, // Warm Grey/Lavender
    ColorPalette.info, // Info Blue
    Color(0xFFFD6A5C), // Salmon Pink/Coral
    Color(0xFF8E44AD), // Purple
    Color(0xFF3498DB), // Lighter Blue
    Color(0xFFE67E22), // Orange
    Color(0xFF7F8C8D), // Grey
    Color(0xFF1ABC9C), // Turquoise
  ];

  // Predefined Icons (Keep as is, or update if desired)
  static const List<IconData> predefinedIcons = [
    Icons.category_outlined, // Use outlined versions for modern feel
    Icons.fastfood_outlined,
    Icons.directions_car_filled_outlined, // Can mix outlined/filled
    Icons.movie_outlined,
    Icons.attach_money, // Keep filled for money
    Icons.local_hospital_outlined,
    Icons.lightbulb_outline,
    Icons.restaurant_outlined,
    Icons.shopping_cart_outlined,
    Icons.home_outlined,
    Icons.miscellaneous_services_outlined,
    Icons.fitness_center_outlined,
    Icons.sports_esports_outlined,
    Icons.power_settings_new, // Different power icon
    Icons.shopping_bag_outlined,
    Icons.recycling_outlined,
    Icons.card_giftcard_outlined,
    Icons.business_center_outlined,
    Icons.local_offer_outlined,
    Icons.more_horiz,
    Icons.account_balance_outlined,
    Icons.account_balance_wallet_outlined,
  ];
}

// ChartStyle class (Keep as is)
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
