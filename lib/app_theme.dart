import 'package:flutter/material.dart';

class AppTheme {
  // الألوان الأساسية للتطبيق
  static const Color primaryColor = Color(0xFF2E7D32); // اللون الأخضر الأساسي
  static const Color primaryLight = Color(0xFFE8F5E9); // لون خلفية فاتح متوافق مع الأساسي
  
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
          fontFamily: 'Cairo', // أو أي خط تستخدمه
        ),
      ),
    );
  }
}