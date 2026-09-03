// app_theme.dart
import 'package:flutter/material.dart';

@immutable
abstract class AppTheme {
  const AppTheme._(); // منع إنشاء كائن من الكلاس

  // الألوان الأساسية للتطبيق
  static const Color primaryColor = Color(0xFF2E7D32); // الأخضر الأساسي
  static const Color primaryLight = Color(0xFFE8F5E9); // خلفية فاتحة متوافقة
  static const Color secondaryColor = Color(0xFF37474F); // الأزرق الداكن (كشف التوصيل)
  static const Color accentColor = Color(0xFF00897B); // التركواز (سلة المحذوفات)

  // ألوان النصوص
  static const Color textPrimary = Color(0xFF212121);   // النص الرئيسي الداكن
  static const Color textSecondary = Color(0xFF757575); // النص الثانوي (رمادي)

  // ألوان عامة إضافية
  static const Color backgroundColor = Color(0xFFF9F9F9);
  static const Color cardColor = Colors.white;

  // الثيم العام للتطبيق (ThemeData)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentColor,
        surface: cardColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Cairo',
        ),
      ),
      // توحيد نمط الأزرار
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      // توحيد نمط البطاقات
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      // توحيد نمط الحوارات
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      // توحيد نمط حقول الإدخال
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      // توحيد نمط القوائم الجانبية
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white,
      ),
      // توحيد نمط SnackBar
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
      // توحيد نمط القوائم السفلية
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }
}