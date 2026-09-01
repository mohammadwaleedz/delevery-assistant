import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityService {
  // تهيئة الإعدادات الآمنة لنظامي Android و iOS للحماية من الثغرات
  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  static const _storage = FlutterSecureStorage(
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );

  static const _pinKey = 'user_app_pin';

  /// فحص هل قام المستخدم بإنشاء كلمة مرور سابقاً
  static Future<bool> isPinSet() async {
    try {
      String? pin = await _storage.read(key: _pinKey);
      return pin != null && pin.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// تعيين/حفظ كلمة مرور جديدة
  static Future<void> setPin(String newPin) async {
    try {
      await _storage.write(key: _pinKey, value: newPin);
    } on PlatformException {
      // تم حذف المتغير e للتخلص من التحذير (Unused catch clause)
      rethrow;
    }
  }

  /// التحقق من صحة كلمة المرور المدخلة
  static Future<bool> verifyPin(String enteredPin) async {
    try {
      String? savedPin = await _storage.read(key: _pinKey);
      return savedPin == enteredPin;
    } catch (e) {
      return false;
    }
  }

  /// (إضافة جديدة) مسح كلمة المرور/إعادة ضبط رمز الأمان
  static Future<void> clearPin() async {
    try {
      await _storage.delete(key: _pinKey);
    } catch (e) {
      // إهمال الخطأ إذا كان المفتاح غير موجود بالفعل
    }
  }
}