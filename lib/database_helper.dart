import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// ============================================================================
// 1. نموذج بيانات الشحنة (DeliveryOrder Model)
// ============================================================================

class DeliveryOrder {
  final int? id; // المعرف الفريد بقاعدة البيانات
  final String orderId;
  final String customerName;
  final String phone;
  final String region;
  final String address;
  final String pageName;
  final double totalAmount;
  final double deliveryFee;
  
  String status;
  String paymentMethod;
  double actualCollectedAmount;
  bool isFeeCollectedOnCancel;
  String notes;
  String? updatedAt;

  DeliveryOrder({
    this.id,
    required this.orderId,
    required this.customerName,
    required this.phone,
    required this.region,
    required this.address,
    required this.pageName,
    required this.totalAmount,
    required this.deliveryFee,
    this.status = 'قيد التوصيل',
    this.paymentMethod = 'نقداً',
    double? actualCollectedAmount,
    this.isFeeCollectedOnCancel = false,
    this.notes = '',
    this.updatedAt,
  }) : actualCollectedAmount = actualCollectedAmount ?? totalAmount;

  // تحويل البيانات من خريطة قاعدة البيانات Map إلى كائن DeliveryOrder
  factory DeliveryOrder.fromMap(Map<String, dynamic> map) {
    return DeliveryOrder(
      id: map['id'],
      orderId: map['orderId'] ?? '',
      customerName: map['customerName'] ?? '',
      phone: map['mobile'] ?? '',
      region: map['address'] ?? '',
      address: map['itemDescription'] ?? '',
      pageName: '', 
      totalAmount: (map['goodsValue'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (map['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'قيد التوصيل',
      paymentMethod: map['paymentMethod'] ?? 'نقداً',
      actualCollectedAmount: (map['actualCollectedAmount'] as num?)?.toDouble() ?? 0.0,
      isFeeCollectedOnCancel: (map['isFeeCollectedOnCancel'] == 1),
      notes: map['notes'] ?? '',
      updatedAt: map['updatedAt'],
    );
  }

  // تحويل كائن DeliveryOrder إلى خريطة Map لحفظه أو تعديله في قاعدة البيانات
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'orderId': orderId,
      'customerName': customerName,
      'mobile': phone,
      'address': region,
      'itemDescription': address,
      'goodsValue': totalAmount,
      'deliveryFee': deliveryFee,
      'status': status,
      'paymentMethod': paymentMethod,
      'actualCollectedAmount': actualCollectedAmount,
      'customCollectedAmount': actualCollectedAmount,
      'isFeeCollectedOnCancel': isFeeCollectedOnCancel ? 1 : 0,
      'notes': notes,
      'updatedAt': updatedAt ?? DateTime.now().toIso8601String(),
    };
  }

  // حساب مستحقات السائق
  double get driverShare {
    if (status == 'تم التوصيل') {
      return deliveryFee;
    } else if (status == 'ملغاة' && isFeeCollectedOnCancel) {
      return deliveryFee;
    }
    return 0.0;
  }

  // حساب المستحق للمتجر
  double get shopShare {
    if (status == 'تم التوصيل') {
      return actualCollectedAmount - deliveryFee;
    } else if (status == 'ملغاة' && isFeeCollectedOnCancel) {
      return 0.0;
    }
    return 0.0;
  }
}

// ============================================================================
// 2. كلاس إدارة قاعدة البيانات (DatabaseHelper Class)
// ============================================================================

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('delivery_manifest.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 6, // إصدار قاعدة البيانات 6
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. جدول الشحنات النشطة
    await db.execute('''
      CREATE TABLE manifest (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderId TEXT,
        customerName TEXT,
        mobile TEXT,
        address TEXT,
        pcs INTEGER DEFAULT 1,
        goodsValue REAL,
        deliveryFee REAL,
        collectionAmount REAL,
        paymentMethod TEXT,
        status TEXT DEFAULT 'قيد التوصيل',
        isFeeCollectedOnCancel INTEGER,
        actualCollectedAmount REAL,
        customCollectedAmount REAL,
        notes TEXT,
        lat REAL,
        lng REAL,
        itemDescription TEXT,
        updatedAt TEXT
      )
    ''');

    // 2. جدول سلة المحذوفات
    await db.execute('''
      CREATE TABLE recycle_bin (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderId TEXT,
        customerName TEXT,
        mobile TEXT,
        address TEXT,
        pcs INTEGER DEFAULT 1,
        goodsValue REAL,
        deliveryFee REAL,
        collectionAmount REAL,
        paymentMethod TEXT,
        status TEXT DEFAULT 'قيد التوصيل',
        isFeeCollectedOnCancel INTEGER,
        actualCollectedAmount REAL,
        customCollectedAmount REAL,
        notes TEXT,
        lat REAL,
        lng REAL,
        itemDescription TEXT,
        updatedAt TEXT
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS manifest');
      await db.execute('DROP TABLE IF EXISTS recycle_bin');
      await _createDB(db, newVersion);
    } else {
      List<String> alterQueries = [
        'ALTER TABLE manifest ADD COLUMN customerName TEXT',
        'ALTER TABLE manifest ADD COLUMN goodsValue REAL',
        'ALTER TABLE manifest ADD COLUMN deliveryFee REAL',
        'ALTER TABLE manifest ADD COLUMN paymentMethod TEXT',
        'ALTER TABLE manifest ADD COLUMN isFeeCollectedOnCancel INTEGER',
        'ALTER TABLE manifest ADD COLUMN actualCollectedAmount REAL',
        'ALTER TABLE manifest ADD COLUMN customCollectedAmount REAL',
        'ALTER TABLE manifest ADD COLUMN notes TEXT',
        'ALTER TABLE manifest ADD COLUMN lat REAL',
        'ALTER TABLE manifest ADD COLUMN lng REAL',
        'ALTER TABLE manifest ADD COLUMN itemDescription TEXT',
        'ALTER TABLE manifest ADD COLUMN status TEXT DEFAULT "قيد التوصيل"',
        'ALTER TABLE manifest ADD COLUMN updatedAt TEXT',
      ];

      for (var query in alterQueries) {
        try {
          await db.execute(query);
        } catch (_) {}
      }

      if (oldVersion < 5) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS recycle_bin (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            orderId TEXT,
            customerName TEXT,
            mobile TEXT,
            address TEXT,
            pcs INTEGER DEFAULT 1,
            goodsValue REAL,
            deliveryFee REAL,
            collectionAmount REAL,
            paymentMethod TEXT,
            status TEXT DEFAULT 'قيد التوصيل',
            isFeeCollectedOnCancel INTEGER,
            actualCollectedAmount REAL,
            customCollectedAmount REAL,
            notes TEXT,
            lat REAL,
            lng REAL,
            itemDescription TEXT,
            updatedAt TEXT
          )
        ''');
      }

      if (oldVersion < 6) {
        try {
          await db.execute('ALTER TABLE recycle_bin ADD COLUMN updatedAt TEXT');
        } catch (_) {}
      }
    }
  }

  Map<String, dynamic> _normalizeRowData(Map<String, dynamic> row) {
    final Map<String, dynamic> data = Map<String, dynamic>.from(row);

    if (data.containsKey('customCollectedAmount')) {
      data['actualCollectedAmount'] = data['customCollectedAmount'];
    } else if (data.containsKey('actualCollectedAmount')) {
      data['customCollectedAmount'] = data['actualCollectedAmount'];
    }

    return data;
  }

  // ==========================================
  //    دوال جدول الشحنات الرئيسي (Manifest)
  // ==========================================

  Future<int> insertManifestItem(Map<String, dynamic> row) async {
    final db = await instance.database;
    final data = _normalizeRowData(row);
    data['updatedAt'] ??= DateTime.now().toIso8601String();

    return await db.insert(
      'manifest',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getManifestItems() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> items =
        await db.query('manifest', orderBy: 'id DESC');

    return items.map((item) {
      final map = Map<String, dynamic>.from(item);
      map['customCollectedAmount'] ??= map['actualCollectedAmount'];
      return map;
    }).toList();
  }

  // جلب العناصر على شكل قائمة كائنات DeliveryOrder جاهزة الاستخدام
  Future<List<DeliveryOrder>> getDeliveryOrders() async {
    final maps = await getManifestItems();
    return maps.map((map) => DeliveryOrder.fromMap(map)).toList();
  }

  Future<int> updateStatus(int id, String newStatus) async {
    final db = await instance.database;
    return await db.update(
      'manifest',
      {
        'status': newStatus,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateManifestItemData(int id, Map<String, dynamic> row) async {
    final db = await instance.database;
    final data = _normalizeRowData(row);
    data['updatedAt'] = DateTime.now().toIso8601String();

    return await db.update(
      'manifest',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateManifestItem(dynamic arg1,
      [Map<String, dynamic>? arg2]) async {
    if (arg1 is Map<String, dynamic>) {
      if (arg1.containsKey('id') && arg1['id'] != null) {
        int id = arg1['id'];
        return await updateManifestItemData(id, arg1);
      }
    } else if (arg1 is int && arg2 != null) {
      return await updateManifestItemData(arg1, arg2);
    }
    return 0;
  }

  // نقل الشحنة إلى سلة المحذوفات
  Future<void> deleteManifestItem(int id) async {
    final db = await instance.database;
    final item = await db.query('manifest', where: 'id = ?', whereArgs: [id]);

    if (item.isNotEmpty) {
      var itemData = Map<String, dynamic>.from(item.first);
      itemData.remove('id');
      itemData['updatedAt'] = DateTime.now().toIso8601String();

      await db.insert('recycle_bin', itemData);
      await db.delete('manifest', where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<int> clearManifestItems() async {
    final db = await instance.database;
    return await db.delete('manifest');
  }

  Future<int> clearManifest() async => await clearManifestItems();
  Future<int> clearAllItems() async => await clearManifestItems();

  // ==========================================
  //    دوال سلة المحذوفات (Recycle Bin)
  // ==========================================

  Future<List<Map<String, dynamic>>> getRecycleBinItems() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> items =
        await db.query('recycle_bin', orderBy: 'id DESC');

    return items.map((item) {
      final map = Map<String, dynamic>.from(item);
      map['customCollectedAmount'] ??= map['actualCollectedAmount'];
      return map;
    }).toList();
  }

  Future<void> restoreManifestItem(int id) async {
    final db = await instance.database;
    final item = await db.query('recycle_bin', where: 'id = ?', whereArgs: [id]);

    if (item.isNotEmpty) {
      var itemData = Map<String, dynamic>.from(item.first);
      itemData.remove('id');
      itemData['updatedAt'] = DateTime.now().toIso8601String();

      await db.insert('manifest', itemData);
      await db.delete('recycle_bin', where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<int> permanentlyDeleteManifestItem(int id) async {
    final db = await instance.database;
    return await db.delete('recycle_bin', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> clearRecycleBin() async {
    final db = await instance.database;
    return await db.delete('recycle_bin');
  }
}