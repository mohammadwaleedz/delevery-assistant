// app_utils.dart
// ملف للوظائف المساعدة المشتركة عبر التطبيق
// يهدف إلى تقليل التكرار وتوحيد منطق معالجة البيانات

import 'app_constants.dart';

/// أدوات معالجة أرقام الهواتف
class PhoneUtils {
  PhoneUtils._();

  /// تنظيف رقم الهاتف من الرموز غير الرقمية
  static String clean(String phone) {
    return phone.replaceAll(RegExp(r'[^\d]'), '');
  }

  /// تنسيق الرقم المحلي (إضافة 0 في البداية إذا كان الرقم 9 خانات)
  static String toLocalFormat(String phone) {
    final cleaned = clean(phone);
    if (cleaned.isEmpty) return '---';
    if (!cleaned.startsWith('0') && cleaned.length == 9) {
      return '0$cleaned';
    }
    return cleaned;
  }

  /// تحويل الرقم إلى صيغة دولية (962) لواتساب
  static String toInternationalFormat(String phone) {
    var cleaned = clean(phone);
    if (cleaned.startsWith('0')) {
      cleaned = '962${cleaned.substring(1)}';
    } else if (!cleaned.startsWith('962') && cleaned.length == 9) {
      cleaned = '962$cleaned';
    }
    return cleaned;
  }

  /// إنشاء رابط واتساب مع رسالة
  static Uri buildWhatsAppUri(String phone, String message) {
    final international = toInternationalFormat(phone);
    return Uri.parse(
      'https://wa.me/$international?text=${Uri.encodeComponent(message)}',
    );
  }

  /// إنشاء رابط اتصال هاتفي
  static Uri buildTelUri(String phone) {
    final cleaned = clean(phone);
    return Uri(scheme: 'tel', path: cleaned);
  }
}

/// أدوات معالجة العناوين
class AddressUtils {
  AddressUtils._();

  /// التحقق مما إذا كان العنوان هو عنوان افتراضي/غير محدد
  static bool isPlaceholder(String? address) {
    if (address == null) return true;
    return DefaultAddresses.isPlaceholder(address);
  }

  /// الحصول على نص العرض المناسب للعنوان
  static String getDisplayAddress(String? address) {
    if (isPlaceholder(address)) {
      return DefaultAddresses.notRequested;
    }
    return address!.trim();
  }

  /// استخراج الإحداثيات من رابط خرائط جوجل
  static (double?, double?)? extractCoordsFromUrl(String url) {
    try {
      final regExp = RegExp(r'(@|query=)(-?\d+\.\d+),(-?\d+\.\d+)');
      final match = regExp.firstMatch(url);
      if (match != null && match.groupCount >= 3) {
        final lat = double.tryParse(match.group(2)!);
        final lng = double.tryParse(match.group(3)!);
        if (lat != null && lng != null) {
          return (lat, lng);
        }
      }
    } catch (_) {}
    return null;
  }

  /// التحقق مما إذا كان النص رابطاً
  static bool isUrl(String text) {
    return text.startsWith('http://') || text.startsWith('https://');
  }
}

/// أدوات معالجة المسافات
class DistanceUtils {
  DistanceUtils._();

  /// تنسيق المسافة بشكل مقروء (متر/كم)
  static String format(double distanceInMeters) {
    if (distanceInMeters > 1000) {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} كم';
    }
    return '${distanceInMeters.toStringAsFixed(0)} متر';
  }
}

/// أدوات معالجة المبالغ المالية
class MoneyUtils {
  MoneyUtils._();

  /// تنسيق المبلغ بشكل مقروء
  static String format(double amount) {
    return amount.toStringAsFixed(2);
  }

  /// تنسيق المبلغ مع العملة
  static String formatWithCurrency(double amount) {
    return '${format(amount)} د.أ';
  }
}

/// أدوات معالجة الحالات
class StatusUtils {
  StatusUtils._();

  /// توحيد الحالة من أي صيغة قديمة إلى الصيغة الموحدة
  static String normalize(String? status) {
    if (status == null || status.isEmpty) return OrderStatus.pending;
    return OrderStatus.normalize(status);
  }

  /// التحقق مما إذا كانت الحالة "قيد التنفيذ"
  static bool isActive(String status) {
    return OrderStatus.active.contains(normalize(status));
  }

  /// التحقق مما إذا كانت الحالة "مكتملة"
  static bool isCompleted(String status) {
    return OrderStatus.completed.contains(normalize(status));
  }
}