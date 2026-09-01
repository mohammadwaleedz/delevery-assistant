import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DeliveryOrder {
  final int? id;
  final String phone;
  final String customerName;
  final String orderId;
  final String region;
  final String address;
  final String pageName;
  final String status;
  final double totalAmount;
  final double deliveryFee;
  final double actualCollectedAmount;
  final double driverShare;
  final double shopShare;
  final String paymentMethod;
  final bool isFeeCollectedOnCancel;
  final String notes;
  final bool isDeleted; // حقل خاص بسلة المحذوفات

  DeliveryOrder({
    this.id,
    required this.phone,
    required this.customerName,
    required this.orderId,
    required this.region,
    this.address = '',
    this.pageName = '',
    required this.status,
    required this.totalAmount,
    required this.deliveryFee,
    required this.actualCollectedAmount,
    required this.driverShare,
    required this.shopShare,
    this.paymentMethod = 'نقداً',
    this.isFeeCollectedOnCancel = false,
    this.notes = '',
    this.isDeleted = false,
  });

  DeliveryOrder copyWith({
    int? id,
    String? phone,
    String? customerName,
    String? orderId,
    String? region,
    String? address,
    String? pageName,
    String? status,
    double? totalAmount,
    double? deliveryFee,
    double? actualCollectedAmount,
    double? driverShare,
    double? shopShare,
    String? paymentMethod,
    bool? isFeeCollectedOnCancel,
    String? notes,
    bool? isDeleted,
  }) {
    return DeliveryOrder(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      customerName: customerName ?? this.customerName,
      orderId: orderId ?? this.orderId,
      region: region ?? this.region,
      address: address ?? this.address,
      pageName: pageName ?? this.pageName,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      actualCollectedAmount: actualCollectedAmount ?? this.actualCollectedAmount,
      driverShare: driverShare ?? this.driverShare,
      shopShare: shopShare ?? this.shopShare,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isFeeCollectedOnCancel: isFeeCollectedOnCancel ?? this.isFeeCollectedOnCancel,
      notes: notes ?? this.notes,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phone': phone,
      'customerName': customerName,
      'orderId': orderId,
      'region': region,
      'address': address,
      'pageName': pageName,
      'status': status,
      'totalAmount': totalAmount,
      'deliveryFee': deliveryFee,
      'actualCollectedAmount': actualCollectedAmount,
      'driverShare': driverShare,
      'shopShare': shopShare,
      'paymentMethod': paymentMethod,
      'isFeeCollectedOnCancel': isFeeCollectedOnCancel ? 1 : 0,
      'notes': notes,
      'isDeleted': isDeleted ? 1 : 0,
    };
  }

  factory DeliveryOrder.fromMap(Map<String, dynamic> map) {
    return DeliveryOrder(
      id: map['id'],
      phone: map['phone'] ?? map['mobile'] ?? '',
      customerName: map['customerName'] ?? map['name'] ?? '',
      orderId: map['orderId'] ?? '',
      region: map['region'] ?? '',
      address: map['address'] ?? '',
      pageName: map['pageName'] ?? '',
      status: map['status'] ?? 'قيد التوصيل',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? (map['collectionAmount'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (map['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      actualCollectedAmount: (map['actualCollectedAmount'] as num?)?.toDouble() ?? 0.0,
      driverShare: (map['driverShare'] as num?)?.toDouble() ?? 0.0,
      shopShare: (map['shopShare'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['paymentMethod'] ?? 'نقداً',
      isFeeCollectedOnCancel: map['isFeeCollectedOnCancel'] == 1,
      notes: map['notes'] ?? map['itemDescription'] ?? '',
      isDeleted: map['isDeleted'] == 1,
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('manifest_orders.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4, // تحديث الإصدار لتحديث بنية الجدول
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE manifest_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            phone TEXT,
            customerName TEXT,
            orderId TEXT,
            region TEXT,
            address TEXT,
            pageName TEXT,
            status TEXT,
            totalAmount REAL,
            deliveryFee REAL,
            actualCollectedAmount REAL,
            driverShare REAL,
            shopShare REAL,
            paymentMethod TEXT,
            isFeeCollectedOnCancel INTEGER,
            notes TEXT,
            isDeleted INTEGER DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('DROP TABLE IF EXISTS manifest_items');
        await db.execute('''
          CREATE TABLE manifest_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            phone TEXT,
            customerName TEXT,
            orderId TEXT,
            region TEXT,
            address TEXT,
            pageName TEXT,
            status TEXT,
            totalAmount REAL,
            deliveryFee REAL,
            actualCollectedAmount REAL,
            driverShare REAL,
            shopShare REAL,
            paymentMethod TEXT,
            isFeeCollectedOnCancel INTEGER,
            notes TEXT,
            isDeleted INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<int> insertManifestItem(Map<String, dynamic> row) async {
    final db = await instance.database;
    final order = DeliveryOrder(
      phone: row['mobile'] ?? row['phone'] ?? '',
      customerName: row['customerName'] ?? row['name'] ?? 'بدون اسم',
      orderId: row['orderId'] ?? '',
      region: row['region'] ?? '',
      address: row['address'] ?? '',
      pageName: row['pageName'] ?? '',
      status: row['status'] ?? 'قيد التوصيل',
      totalAmount: (row['collectionAmount'] as num?)?.toDouble() ?? (row['totalAmount'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (row['deliveryFee'] as num?)?.toDouble() ?? 2.0,
      actualCollectedAmount: (row['actualCollectedAmount'] as num?)?.toDouble() ?? 0.0,
      driverShare: (row['driverShare'] as num?)?.toDouble() ?? 2.0,
      shopShare: (row['shopShare'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: row['paymentMethod'] ?? 'نقداً',
      isFeeCollectedOnCancel: row['isFeeCollectedOnCancel'] == 1 ? true : false,
      notes: row['itemDescription'] ?? row['notes'] ?? '',
      isDeleted: false,
    );
    return await db.insert('manifest_items', order.toMap());
  }

  Future<int> insertDeliveryOrder(DeliveryOrder order) async {
    final db = await instance.database;
    return await db.insert('manifest_items', order.toMap());
  }

  // جلب الشحنات غير المحذوفة فقط للكشف النشط
  Future<List<DeliveryOrder>> getDeliveryOrders() async {
    final db = await instance.database;
    final result = await db.query(
      'manifest_items',
      where: 'isDeleted = ? OR isDeleted IS NULL',
      whereArgs: [0],
      orderBy: 'id DESC',
    );
    return result.map((json) => DeliveryOrder.fromMap(json)).toList();
  }

  Future<int> updateDeliveryOrder(DeliveryOrder order) async {
    final db = await instance.database;
    return await db.update(
      'manifest_items',
      order.toMap(),
      where: 'id = ?',
      whereArgs: [order.id],
    );
  }

  Future<int> updateManifestItem(int id, Map<String, dynamic> values) async {
    final db = await instance.database;
    return await db.update(
      'manifest_items',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateManifestItemAddress(String orderId, String newAddress) async {
    final db = await instance.database;
    return await db.update(
      'manifest_items',
      {'address': newAddress},
      where: 'orderId = ?',
      whereArgs: [orderId],
    );
  }

  // نقل الشحنة إلى سلة المحذوفات بدلاً من الحذف النهائي الفوري
  Future<int> deleteDeliveryOrder(int id) async {
    final db = await instance.database;
    return await db.update(
      'manifest_items',
      {'isDeleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteManifestItem(int id) async {
    return await deleteDeliveryOrder(id);
  }

  // دوال سلة المحذوفات المطلوبة
  Future<List<Map<String, dynamic>>> getRecycleBinItems() async {
    final db = await instance.database;
    final result = await db.query(
      'manifest_items',
      where: 'isDeleted = ?',
      whereArgs: [1],
      orderBy: 'id DESC',
    );
    return result.map((row) => {
      'id': row['id'],
      'customer_name': row['customerName'],
      'phone': row['phone'],
      'store_name': row['pageName'],
      'price': row['totalAmount'],
    }).toList();
  }

  Future<int> restoreFromRecycleBin(int id) async {
    final db = await instance.database;
    return await db.update(
      'manifest_items',
      {'isDeleted': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> permanentlyDelete(int id) async {
    final db = await instance.database;
    return await db.delete(
      'manifest_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearRecycleBin() async {
    final db = await instance.database;
    return await db.delete(
      'manifest_items',
      where: 'isDeleted = ?',
      whereArgs: [1],
    );
  }
}