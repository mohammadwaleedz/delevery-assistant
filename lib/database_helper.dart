import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
      version: 5, // تم رفع الإصدار لإنشاء جدول سلة المحذوفات تلقائياً
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
        itemDescription TEXT
      )
    ''');

    // 2. جدول سلة المحذوفات بنفس البنية
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
        itemDescription TEXT
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
      ];

      for (var query in alterQueries) {
        try {
          await db.execute(query);
        } catch (_) {
          // يتجاهل الخطأ إذا كان العمود مضافاً مسبقاً
        }
      }

      // إضافة جدول سلة المحذوفات في الترقية إلى الإصدار 5
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
            itemDescription TEXT
          )
        ''');
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
  //     دوال جدول الشحنات الرئيسي (Manifest)
  // ==========================================

  Future<int> insertManifestItem(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert(
      'manifest',
      _normalizeRowData(row),
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

  Future<int> updateStatus(int id, String newStatus) async {
    final db = await instance.database;
    return await db.update(
      'manifest',
      {'status': newStatus},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateManifestItemData(int id, Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.update(
      'manifest',
      _normalizeRowData(row),
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

  // نقل الشحنة إلى سلة المحذوفات بدلاً من مسحها فوراً
  Future<void> deleteManifestItem(int id) async {
    final db = await instance.database;
    final item = await db.query('manifest', where: 'id = ?', whereArgs: [id]);

    if (item.isNotEmpty) {
      var itemData = Map<String, dynamic>.from(item.first);
      itemData.remove('id'); // إزالة ID القديم ليتم إنشاؤه تلقائياً في السلة

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
  //     دوال سلة المحذوفات (Recycle Bin)
  // ==========================================

  // جلب العناصر من سلة المحذوفات
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

  // استعادة الشحنة من سلة المحذوفات إلى الكشف الرئيسي
  Future<void> restoreManifestItem(int id) async {
    final db = await instance.database;
    final item = await db.query('recycle_bin', where: 'id = ?', whereArgs: [id]);

    if (item.isNotEmpty) {
      var itemData = Map<String, dynamic>.from(item.first);
      itemData.remove('id'); // إزالة المعرف القديم

      await db.insert('manifest', itemData);
      await db.delete('recycle_bin', where: 'id = ?', whereArgs: [id]);
    }
  }

  // حذف نهائي لشحنة محددة من السلة
  Future<int> permanentlyDeleteManifestItem(int id) async {
    final db = await instance.database;
    return await db.delete('recycle_bin', where: 'id = ?', whereArgs: [id]);
  }

  // تفريغ سلة المحذوفات كاملاً
  Future<int> clearRecycleBin() async {
    final db = await instance.database;
    return await db.delete('recycle_bin');
  }
}