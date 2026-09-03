import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app_constants.dart';

class SecurityService {
  SecurityService._(); // منع إنشاء كائن من الفئة (Utility Class Pattern)

  // إعدادات التشفير المحسنة لنظامي التشغيل
  static const _androidOptions = AndroidOptions();
  static const _iosOptions = IOSOptions(accessibility: KeychainAccessibility.first_unlock);

  static const _storage = FlutterSecureStorage(
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );

  /// فحص هل قام المستخدم بإنشاء كلمة مرور سابقاً
  static Future<bool> isPinSet() async {
    try {
      final pin = await _storage.read(key: SecureStorageKeys.userPin);
      return pin?.isNotEmpty ?? false;
    } catch (_) {
      return false;
    }
  }

  /// تعيين/حفظ كلمة مرور جديدة
  static Future<void> setPin(String newPin) async {
    try {
      await _storage.write(key: SecureStorageKeys.userPin, value: newPin);
    } on PlatformException {
      rethrow;
    }
  }

  /// التحقق من صحة كلمة المرور المدخلة
  static Future<bool> verifyPin(String enteredPin) async {
    try {
      final savedPin = await _storage.read(key: SecureStorageKeys.userPin);
      return savedPin == enteredPin;
    } catch (_) {
      return false;
    }
  }

  /// مسح كلمة المرور / إعادة ضبط رمز الأمان
  static Future<void> clearPin() async {
    try {
      await _storage.delete(key: SecureStorageKeys.userPin);
    } catch (_) {
      // تجاهل الأخطاء في حال لم يكن المفتاح موجوداً
    }
  }
}