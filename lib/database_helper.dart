// database_helper.dart
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:geolocator/geolocator.dart';
import 'app_constants.dart';
import 'app_utils.dart';

class Coords {
  final double lat;
  final double lng;
  Coords(this.lat, this.lng);
}

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
  final bool isDeleted;
  final double? lat; // خط الطول للتوجيه والخرائط
  final double? lng; // خط العرض للتوجيه والخرائط
  final double? distance; // المسافة المحسوبة لحظياً عن المستخدم

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
    this.paymentMethod = PaymentMethod.cash,
    this.isFeeCollectedOnCancel = false,
    this.notes = '',
    this.isDeleted = false,
    this.lat,
    this.lng,
    this.distance,
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
    double? lat,
    double? lng,
    double? distance,
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
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      distance: distance ?? this.distance,
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
      'lat': lat,
      'lng': lng,
    };
  }

  factory DeliveryOrder.fromMap(Map<String, dynamic> map) {
    // توحيد الحالة من أي صيغة قديمة
    final rawStatus = map['status'] ?? OrderStatus.pending;
    return DeliveryOrder(
      id: map['id'],
      phone: map['phone'] ?? map['mobile'] ?? '',
      customerName: map['customerName'] ?? map['name'] ?? '',
      orderId: map['orderId'] ?? '',
      region: map['region'] ?? '',
      address: map['address'] ?? '',
      pageName: map['pageName'] ?? '',
      status: StatusUtils.normalize(rawStatus.toString()),
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? (map['collectionAmount'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (map['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      actualCollectedAmount: (map['actualCollectedAmount'] as num?)?.toDouble() ?? 0.0,
      driverShare: (map['driverShare'] as num?)?.toDouble() ?? 0.0,
      shopShare: (map['shopShare'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: PaymentMethod.normalize(map['paymentMethod']?.toString() ?? PaymentMethod.cash),
      isFeeCollectedOnCancel: map['isFeeCollectedOnCancel'] == 1,
      notes: map['notes'] ?? map['itemDescription'] ?? '',
      isDeleted: map['isDeleted'] == 1,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      distance: (map['distance'] as num?)?.toDouble(),
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
      version: 6,
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
            isDeleted INTEGER DEFAULT 0,
            lat REAL,
            lng REAL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 5) {
          try { await db.execute("ALTER TABLE manifest_items ADD COLUMN lat REAL;"); } catch (_) {}
          try { await db.execute("ALTER TABLE manifest_items ADD COLUMN lng REAL;"); } catch (_) {}
        }
        if (oldVersion < 6) {
          try { await db.execute("ALTER TABLE manifest_items ADD COLUMN isDeleted INTEGER DEFAULT 0;"); } catch (_) {}
        }
      },
    );
  }

  Future<int> insertManifestItem(Map<String, dynamic> row) async {
    final order = DeliveryOrder(
      phone: row['mobile'] ?? row['phone'] ?? '',
      customerName: row['customerName'] ?? row['name'] ?? 'بدون اسم',
      orderId: row['orderId'] ?? '',
      region: row['region'] ?? '',
      address: row['address'] ?? '',
      pageName: row['pageName'] ?? '',
      status: StatusUtils.normalize(row['status']?.toString()),
      totalAmount: (row['collectionAmount'] as num?)?.toDouble() ?? (row['totalAmount'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (row['deliveryFee'] as num?)?.toDouble() ?? 2.0,
      actualCollectedAmount: (row['actualCollectedAmount'] as num?)?.toDouble() ?? 0.0,
      driverShare: (row['driverShare'] as num?)?.toDouble() ?? 2.0,
      shopShare: (row['shopShare'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: PaymentMethod.normalize(row['paymentMethod']?.toString() ?? PaymentMethod.cash),
      isFeeCollectedOnCancel: row['isFeeCollectedOnCancel'] == 1 ? true : false,
      notes: row['itemDescription'] ?? row['notes'] ?? '',
      isDeleted: false,
      lat: (row['lat'] as num?)?.toDouble(),
      lng: (row['lng'] as num?)?.toDouble(),
    );
    final db = await instance.database;
    return await db.insert(DatabaseTables.manifestItems, order.toMap());
  }

  /// إدراج عدة عناصر دفعة واحدة (تحسين الأداء)
  Future<void> insertManifestItemsBatch(List<Map<String, dynamic>> rows) async {
    final db = await instance.database;
    final batch = db.batch();
    
    for (final row in rows) {
      final order = DeliveryOrder(
        phone: row['mobile'] ?? row['phone'] ?? '',
        customerName: row['customerName'] ?? row['name'] ?? 'بدون اسم',
        orderId: row['orderId'] ?? '',
        region: row['region'] ?? '',
        address: row['address'] ?? '',
        pageName: row['pageName'] ?? '',
        status: StatusUtils.normalize(row['status']?.toString()),
        totalAmount: (row['collectionAmount'] as num?)?.toDouble() ?? (row['totalAmount'] as num?)?.toDouble() ?? 0.0,
        deliveryFee: (row['deliveryFee'] as num?)?.toDouble() ?? 2.0,
        actualCollectedAmount: (row['actualCollectedAmount'] as num?)?.toDouble() ?? 0.0,
        driverShare: (row['driverShare'] as num?)?.toDouble() ?? 2.0,
        shopShare: (row['shopShare'] as num?)?.toDouble() ?? 0.0,
        paymentMethod: PaymentMethod.normalize(row['paymentMethod']?.toString() ?? PaymentMethod.cash),
        isFeeCollectedOnCancel: row['isFeeCollectedOnCancel'] == 1 ? true : false,
        notes: row['itemDescription'] ?? row['notes'] ?? '',
        isDeleted: false,
        lat: (row['lat'] as num?)?.toDouble(),
        lng: (row['lng'] as num?)?.toDouble(),
      );
      batch.insert(DatabaseTables.manifestItems, order.toMap());
    }
    
    await batch.commit(noResult: true);
  }

  Future<int> insertDeliveryOrder(DeliveryOrder order) async {
    final db = await instance.database;
    return await db.insert(DatabaseTables.manifestItems, order.toMap());
  }

  Future<List<DeliveryOrder>> getDeliveryOrders() async {
    final db = await instance.database;
    final result = await db.query(
      DatabaseTables.manifestItems,
      where: '${DatabaseColumns.isDeleted} = ? OR ${DatabaseColumns.isDeleted} IS NULL',
      whereArgs: [0],
      orderBy: '${DatabaseColumns.id} DESC',
    );
    return result.map((json) => DeliveryOrder.fromMap(json)).toList();
  }

  Future<List<Map<String, dynamic>>> getSortedCustomersByDistance() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        final orders = await getDeliveryOrders();
        return orders.map((e) => e.toMap()).toList();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          final orders = await getDeliveryOrders();
          return orders.map((e) => e.toMap()).toList();
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        final orders = await getDeliveryOrders();
        return orders.map((e) => e.toMap()).toList();
      }

      Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final db = await database;
      final result = await db.query(
        DatabaseTables.manifestItems,
        where: '${DatabaseColumns.isDeleted} = ? OR ${DatabaseColumns.isDeleted} IS NULL',
        whereArgs: [0],
      );

      List<Map<String, dynamic>> customersWithDistance = [];

      for (var row in result) {
        Map<String, dynamic> mutableCustomer = Map.from(row);
        double? destLat = (mutableCustomer['lat'] as num?)?.toDouble();
        double? destLng = (mutableCustomer['lng'] as num?)?.toDouble();

        if (destLat == null || destLng == null || destLat == 0 || destLng == 0) {
          String link = mutableCustomer['address']?.toString() ?? '';
          if (!AddressUtils.isUrl(link)) {
            link = mutableCustomer['notes']?.toString() ?? '';
          }
          
          final extracted = AddressUtils.extractCoordsFromUrl(link);
          if (extracted != null) {
            destLat = extracted.$1;
            destLng = extracted.$2;
          }
        }

        double distance = 999999.0;
        if (destLat != null && destLng != null && destLat != 0 && destLng != 0) {
          distance = Geolocator.distanceBetween(
            currentPosition.latitude,
            currentPosition.longitude,
            destLat,
            destLng,
          );
        }

        mutableCustomer['distance'] = distance;
        customersWithDistance.add(mutableCustomer);
      }

      customersWithDistance.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
      return customersWithDistance;
    } catch (_) {
      final orders = await getDeliveryOrders();
      return orders.map((e) => e.toMap()).toList();
    }
  }

  Future<int> updateDeliveryOrder(DeliveryOrder order) async {
    final db = await instance.database;
    return await db.update(
      DatabaseTables.manifestItems,
      order.toMap(),
      where: '${DatabaseColumns.id} = ?',
      whereArgs: [order.id],
    );
  }

  Future<int> updateManifestItem(int id, Map<String, dynamic> values) async {
    final db = await instance.database;
    return await db.update(
      DatabaseTables.manifestItems,
      values,
      where: '${DatabaseColumns.id} = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateManifestItemAddress(dynamic identifier, String newAddress) async {
    final db = await instance.database;
    if (identifier is int) {
      return await db.update(
        DatabaseTables.manifestItems,
        {DatabaseColumns.address: newAddress},
        where: '${DatabaseColumns.id} = ?',
        whereArgs: [identifier],
      );
    } else {
      return await db.update(
        DatabaseTables.manifestItems,
        {DatabaseColumns.address: newAddress},
        where: '${DatabaseColumns.orderId} = ? OR ${DatabaseColumns.id} = ?',
        whereArgs: [identifier.toString(), int.tryParse(identifier.toString()) ?? -1],
      );
    }
  }

  /// تحديث عنوان الشحنة مع إحداثياتها الجغرافية باستخدام id المضمون
  Future<int> updateManifestItemAddressWithCoordsById(int id, String address, double lat, double lng) async {
    final db = await instance.database;
    return await db.update(
      DatabaseTables.manifestItems,
      {
        DatabaseColumns.address: address,
        DatabaseColumns.lat: lat,
        DatabaseColumns.lng: lng,
      },
      where: '${DatabaseColumns.id} = ?',
      whereArgs: [id],
    );
  }

  /// تحديث عنوان الشحنة مع إحداثياتها الجغرافية الحقيقية المستخرجة
  Future<int> updateManifestItemAddressWithCoords(String orderId, String address, double lat, double lng) async {
    final db = await instance.database;
    return await db.update(
      DatabaseTables.manifestItems,
      {
        DatabaseColumns.address: address,
        DatabaseColumns.lat: lat,
        DatabaseColumns.lng: lng,
      },
      where: '${DatabaseColumns.orderId} = ?',
      whereArgs: [orderId],
    );
  }

  Future<int> deleteDeliveryOrder(int id) async {
    final db = await instance.database;
    return await db.update(
      DatabaseTables.manifestItems,
      {DatabaseColumns.isDeleted: 1},
      where: '${DatabaseColumns.id} = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteManifestItem(int id) async {
    return await deleteDeliveryOrder(id);
  }

  /// حذف عدة شحنات دفعة واحدة (نقل إلى سلة المهملات)
  Future<void> deleteDeliveryOrdersBatch(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await instance.database;
    final batch = db.batch();
    for (final id in ids) {
      batch.update(
        DatabaseTables.manifestItems,
        {DatabaseColumns.isDeleted: 1},
        where: '${DatabaseColumns.id} = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getRecycleBinItems() async {
    final db = await instance.database;
    final result = await db.query(
      DatabaseTables.manifestItems,
      where: '${DatabaseColumns.isDeleted} = ?',
      whereArgs: [1],
      orderBy: '${DatabaseColumns.id} DESC',
    );
    return result.map((row) => {
      'id': row['id'],
      'customer_name': row[DatabaseColumns.customerName],
      'phone': row[DatabaseColumns.phone],
      'store_name': row[DatabaseColumns.pageName],
      'price': row[DatabaseColumns.totalAmount],
    }).toList();
  }

  Future<int> restoreFromRecycleBin(int id) async {
    final db = await instance.database;
    return await db.update(
      DatabaseTables.manifestItems,
      {DatabaseColumns.isDeleted: 0},
      where: '${DatabaseColumns.id} = ?',
      whereArgs: [id],
    );
  }

  Future<int> permanentlyDelete(int id) async {
    final db = await instance.database;
    return await db.delete(
      DatabaseTables.manifestItems,
      where: '${DatabaseColumns.id} = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearRecycleBin() async {
    final db = await instance.database;
    return await db.delete(
      DatabaseTables.manifestItems,
      where: '${DatabaseColumns.isDeleted} = ?',
      whereArgs: [1],
    );
  }

  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
    }
  }
}