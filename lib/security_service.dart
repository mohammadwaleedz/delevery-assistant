import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityService {
  static const _storage = FlutterSecureStorage();
  static const _pinKey = 'user_app_pin';

  /// فحص هل قام المستخدم بإنشاء كلمة مرور سابقاً
  static Future<bool> isPinSet() async {
    String? pin = await _storage.read(key: _pinKey);
    return pin != null && pin.isNotEmpty;
  }

  /// تعيين/حفظ كلمة مرور جديدة
  static Future<void> setPin(String newPin) async {
    await _storage.write(key: _pinKey, value: newPin);
  }

  /// التحقق من صحة كلمة المرور المدخلة
  static Future<bool> verifyPin(String enteredPin) async {
    String? savedPin = await _storage.read(key: _pinKey);
    return savedPin == enteredPin;
  }
}