// app_constants.dart
// ملف مركزي لجميع الثوابت المشتركة في التطبيق
// يهدف إلى تقليل التكرار وتوحيد القيم عبر جميع الشاشات

import 'package:flutter/material.dart';

/// حالات الشحنات الموحدة عبر التطبيق
class OrderStatus {
  OrderStatus._();

  static const String pending = 'قيد التوصيل';
  static const String delivered = 'تم التوصيل';
  static const String postponed = 'مؤجل';
  static const String cancelledWithFee = 'ملغي وتم تحصيل رسوم التوصيل';
  static const String cancelledWithoutFee = 'ملغي ولم يتم تحصيل رسوم التوصيل';

  /// جميع الحالات المتاحة
  static const List<String> all = [
    pending,
    delivered,
    postponed,
    cancelledWithFee,
    cancelledWithoutFee,
  ];

  /// الحالات المتوافقة مع الشاشات القديمة (لأغراض التوافق)
  static const List<String> legacy = [
    pending,
    delivered,
    'مؤجلة',
    'ملغاة',
  ];

  /// الحالات التي تعتبر "قيد التنفيذ"
  static const Set<String> active = {pending, postponed};

  /// الحالات المكتملة
  static const Set<String> completed = {delivered, cancelledWithFee, cancelledWithoutFee};

  /// الحالات الملغاة
  static const Set<String> cancelled = {cancelledWithFee, cancelledWithoutFee};

  /// الحصول على لون الحالة
  static Color getStatusColor(String status) {
    switch (status) {
      case delivered:
        return Colors.green;
      case postponed:
        return Colors.orange;
      case cancelledWithFee:
      case cancelledWithoutFee:
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  /// توحيد الحالة القديمة مع الجديدة
  static String normalize(String status) {
    switch (status) {
      case 'مؤجلة':
        return postponed;
      case 'ملغاة':
        return cancelledWithoutFee;
      case 'ملغي و لم يتم تحصيل رسوم التوصيل':
        return cancelledWithoutFee;
      case 'ملغي وتم تحصيل رسوم التوصيل':
        return cancelledWithFee;
      default:
        return status;
    }
  }
}

/// طرق الدفع الموحدة
class PaymentMethod {
  PaymentMethod._();

  static const String cash = 'نقداً';
  static const String cliq = 'كليك CliQ';
  static const String cliqShort = 'كليك';

  static const List<String> all = [cash, cliq];

  /// توحيد طريقة الدفع
  static String normalize(String method) {
    if (method == cliqShort) return cliq;
    return method;
  }
}

/// الرسائل النصية الموحدة
class AppMessages {
  AppMessages._();

  // رسالة واتساب الافتراضية
  static const String whatsappDefaultMessage =
      'الله يعطيك العافية\nمعك مندوب شركة التوصيل\nإذا سمحت أرسل موقعك';

  // رسالة واتساب للترحيب بالعميل
  static const String whatsappGreetingMessage =
      'مرحباً، معكم كابتن التوصيل.';

  // رسائل الخطأ العامة
  static const String errorGeneric = 'حدث خطأ غير متوقع';
  static const String errorWhatsAppNotInstalled = 'تطبيق واتساب غير مثبت على الجهاز';
  static const String errorPhoneCall = 'تعذر فتح تطبيق الاتصال';
  static const String errorMaps = 'تعذر فتح تطبيق الخرائط';
  static const String errorLocationInvalid = 'الموقع غير صحيح يرجى ادخال عنوان العميل بشكل صحيح';

  // رسائل النجاح
  static const String successLocationSaved = 'تم حفظ موقع العميل بنجاح وتحديثه على الخريطة';
  static const String successOrdersSaved = 'تم استخراج وحفظ الأرقام بنجاح';
  static const String noPhonesFound = 'لم يتم العثور على أرقام هواتف في الصورة';
}

/// عناوين افتراضية
class DefaultAddresses {
  DefaultAddresses._();

  static const String placeholder = 'عمان - تحديد الموقع عبر الخريطة';
  static const String notRequested = 'لم تطلب الموقع من العميل';

  /// التحقق مما إذا كان العنوان هو عنوان افتراضي/غير محدد
  static bool isPlaceholder(String address) {
    final trimmed = address.trim();
    return trimmed.isEmpty ||
        trimmed.contains('تحديد الموقع عبر الخريطة') ||
        trimmed.contains('تحديد الموقع');
  }
}

/// مفاتيح التخزين الآمن
class SecureStorageKeys {
  SecureStorageKeys._();

  static const String userPin = 'user_app_pin';
}

/// أسماء جداول قاعدة البيانات
class DatabaseTables {
  DatabaseTables._();

  static const String manifestItems = 'manifest_items';
}

/// أسماء أعمدة قاعدة البيانات
class DatabaseColumns {
  DatabaseColumns._();

  static const String id = 'id';
  static const String phone = 'phone';
  static const String mobile = 'mobile';
  static const String customerName = 'customerName';
  static const String name = 'name';
  static const String orderId = 'orderId';
  static const String region = 'region';
  static const String address = 'address';
  static const String pageName = 'pageName';
  static const String status = 'status';
  static const String totalAmount = 'totalAmount';
  static const String collectionAmount = 'collectionAmount';
  static const String deliveryFee = 'deliveryFee';
  static const String actualCollectedAmount = 'actualCollectedAmount';
  static const String driverShare = 'driverShare';
  static const String shopShare = 'shopShare';
  static const String paymentMethod = 'paymentMethod';
  static const String isFeeCollectedOnCancel = 'isFeeCollectedOnCancel';
  static const String notes = 'notes';
  static const String itemDescription = 'itemDescription';
  static const String isDeleted = 'isDeleted';
  static const String lat = 'lat';
  static const String lng = 'lng';
  static const String distance = 'distance';
}

/// إحداثيات افتراضية (عمان، الأردن)
class DefaultCoordinates {
  DefaultCoordinates._();

  static const double ammanLat = 31.9539;
  static const double ammanLng = 35.9106;
}