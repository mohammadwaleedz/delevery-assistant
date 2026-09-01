import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'security_service.dart';
import 'settings_screen.dart';
import 'manifest_sheet_screen.dart' as manifest_file;
import 'recycle_bin_screen.dart' as recycle_file;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مساعد التوصيل',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.grey.shade50,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ============================================================================
// نموذج بيانات الشحنة (DeliveryOrder Model)
// ============================================================================

@immutable
class DeliveryOrder {
  final int? id;
  final String orderId;
  final String customerName;
  final String phone;
  final String region;
  final String address;
  final String pageName;
  final double totalAmount;
  final double deliveryFee;
  final String status;
  final String paymentMethod;
  final double actualCollectedAmount;
  final bool isFeeCollectedOnCancel;
  final String notes;
  final String? updatedAt;

  const DeliveryOrder({
    this.id,
    required this.orderId,
    required this.customerName,
    required this.phone,
    required this.region,
    required this.address,
    this.pageName = '',
    required this.totalAmount,
    required this.deliveryFee,
    this.status = 'قيد التوصيل',
    this.paymentMethod = 'نقداً',
    double? actualCollectedAmount,
    this.isFeeCollectedOnCancel = false,
    this.notes = '',
    this.updatedAt,
  }) : actualCollectedAmount = actualCollectedAmount ?? totalAmount;

  DeliveryOrder copyWith({
    int? id,
    String? orderId,
    String? customerName,
    String? phone,
    String? region,
    String? address,
    String? pageName,
    double? totalAmount,
    double? deliveryFee,
    String? status,
    String? paymentMethod,
    double? actualCollectedAmount,
    bool? isFeeCollectedOnCancel,
    String? notes,
    String? updatedAt,
  }) {
    return DeliveryOrder(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      customerName: customerName ?? this.customerName,
      phone: phone ?? this.phone,
      region: region ?? this.region,
      address: address ?? this.address,
      pageName: pageName ?? this.pageName,
      totalAmount: totalAmount ?? this.totalAmount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      actualCollectedAmount: actualCollectedAmount ?? this.actualCollectedAmount,
      isFeeCollectedOnCancel: isFeeCollectedOnCancel ?? this.isFeeCollectedOnCancel,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory DeliveryOrder.fromMap(Map<String, dynamic> map) {
    return DeliveryOrder(
      id: map['id'],
      orderId: map['orderId'] ?? '',
      customerName: map['customerName'] ?? '',
      phone: map['mobile'] ?? '',
      region: map['address'] ?? '',
      address: map['itemDescription'] ?? '',
      pageName: map['pageName'] ?? '',
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

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'orderId': orderId,
      'customerName': customerName,
      'mobile': phone,
      'address': region,
      'itemDescription': address,
      'pageName': pageName,
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

  double get driverShare => (status == 'تم التوصيل' || (status == 'ملغاة' && isFeeCollectedOnCancel)) ? deliveryFee : 0.0;
  double get shopShare => status == 'تم التوصيل' ? actualCollectedAmount - deliveryFee : 0.0;
}

// ============================================================================
// إدارة قاعدة البيانات (DatabaseHelper Class)
// ============================================================================

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async => _database ??= await _initDB('delivery_manifest.db');

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    return await openDatabase(join(dbPath, filePath), version: 6, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future<void> _createDB(Database db, int version) async {
    const schema = '''
      id INTEGER PRIMARY KEY AUTOINCREMENT, orderId TEXT, customerName TEXT, mobile TEXT, address TEXT,
      pcs INTEGER DEFAULT 1, goodsValue REAL, deliveryFee REAL, collectionAmount REAL, paymentMethod TEXT,
      status TEXT DEFAULT 'قيد التوصيل', isFeeCollectedOnCancel INTEGER, actualCollectedAmount REAL,
      customCollectedAmount REAL, notes TEXT, lat REAL, lng REAL, itemDescription TEXT, updatedAt TEXT
    ''';
    await db.execute('CREATE TABLE manifest ($schema)');
    await db.execute('CREATE TABLE recycle_bin ($schema)');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS manifest');
      await db.execute('DROP TABLE IF EXISTS recycle_bin');
      await _createDB(db, newVersion);
      return;
    }
    const queries = [
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
    for (var q in queries) {
      try { await db.execute(q); } catch (_) {}
    }
  }

  Future<List<DeliveryOrder>> getDeliveryOrders() async {
    final db = await database;
    final maps = await db.query('manifest', orderBy: 'id DESC');
    return maps.map((m) => DeliveryOrder.fromMap(m)).toList();
  }

  Future<int> insertManifestItem(Map<String, dynamic> data) async {
    final db = await database;
    data['updatedAt'] ??= DateTime.now().toIso8601String();
    return await db.insert('manifest', data);
  }

  Future<int> updateManifestItem(dynamic arg1, [Map<String, dynamic>? arg2]) async {
    final db = await database;
    int? id;
    late Map<String, dynamic> data;

    if (arg1 is int && arg2 != null) {
      id = arg1;
      data = Map<String, dynamic>.from(arg2);
    } else if (arg1 is Map<String, dynamic>) {
      id = arg1['id'];
      data = Map<String, dynamic>.from(arg1);
    } else {
      return 0;
    }

    data['updatedAt'] = DateTime.now().toIso8601String();
    return await db.update('manifest', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteManifestItem(int id) async {
    final db = await database;
    final item = await db.query('manifest', where: 'id = ?', whereArgs: [id]);
    if (item.isNotEmpty) {
      final data = Map<String, dynamic>.from(item.first)..remove('id');
      await db.insert('recycle_bin', data);
      await db.delete('manifest', where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<int> clearManifest() async {
    final db = await database;
    return await db.delete('manifest');
  }

  Future<Object?> getManifestItems() async {}
}

// ============================================================================
// واجهة المستخدم الرئيسية (HomeScreen)
// ============================================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _extractedOrders = [];
  final Set<String> _sentPhones = {};
  bool _isLoading = false;
  bool _isAuthenticated = false;
  bool _hasPinSet = false;
  final _pinInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkSecurity();
  }

  @override
  void dispose() {
    _pinInputController.dispose();
    super.dispose();
  }

  Future<void> _checkSecurity() async {
    final hasPin = await SecurityService.isPinSet();
    if (!mounted) return;
    setState(() {
      _hasPinSet = hasPin;
      _isAuthenticated = !hasPin;
    });
  }

  Future<void> _verifyEnteredPin() async {
    final isValid = await SecurityService.verifyPin(_pinInputController.text.trim());
    if (isValid) {
      setState(() {
        _isAuthenticated = true;
        _pinInputController.clear();
      });
    } else {
      _showMessage('كلمة المرور غير صحيحة!');
    }
  }

  void _navigateToScreen(Widget screen) async {
    await Navigator.push(context as BuildContext, MaterialPageRoute(builder: (_) => screen));
    _checkSecurity();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context as BuildContext).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context as BuildContext,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('التقاط صورة بالكاميرا'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndRecognizeText(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('اختيار من المعرض'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndRecognizeText(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndRecognizeText(ImageSource source) async {
    final image = await ImagePicker().pickImage(source: source);
    if (image == null) return;

    setState(() {
      _isLoading = true;
      _extractedOrders.clear();
      _sentPhones.clear();
    });

    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognizedText = await textRecognizer.processImage(InputImage.fromFilePath(image.path));
      final matches = RegExp(r'\+?[0-9]{8,15}').allMatches(recognizedText.text).map((m) => m.group(0)!).toSet().toList();

      List<Map<String, dynamic>> tempOrders = [];
      final nowIso = DateTime.now().toIso8601String();

      for (int i = 0; i < matches.length; i++) {
        final orderData = {
          'orderId': '${1000 + i}',
          'customerName': 'عميل مستخرج ${i + 1}',
          'mobile': matches[i],
          'address': 'عمان - تحديد الموقع عبر الخريطة',
          'goodsValue': 15.0,
          'deliveryFee': 2.0,
          'itemDescription': 'طرد شحنة توصيل مستخرج',
          'status': 'قيد التوصيل',
          'updatedAt': nowIso,
        };
        await DatabaseHelper.instance.insertManifestItem(orderData);
        tempOrders.add(orderData);
      }

      if (!mounted) return;
      setState(() => _extractedOrders = tempOrders);
      _showMessage(matches.isEmpty ? 'لم يتم العثور على أرقام هواتف في الصورة' : 'تم استخراج وحفظ ${matches.length} رقم بنجاح');
    } catch (e) {
      _showMessage('حدث خطأ أثناء قراءة الصورة: $e');
    } finally {
      await textRecognizer.close();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (!cleanPhone.startsWith('0') && cleanPhone.length == 9) cleanPhone = '0$cleanPhone';

    final uri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        _showMessage('تعذر فتح تطبيق الاتصال');
      }
    } catch (_) {
      _showMessage('حدث خطأ أثناء إجراء الاتصال');
    }
  }

  Future<void> _openWhatsApp(String phone, [StateSetter? setSheetState]) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '962${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('962') && cleanPhone.length == 9) {
      cleanPhone = '962$cleanPhone';
    }

    const msg = "الله يعطيك العافية\nمعك مندوب شركة التوصيل\nإذا سمحت أرسل موقعك";
    final uri = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(msg)}");

    try {
      if (await canLaunchUrl(uri)) {
        if (mounted) {
          setState(() => _sentPhones.add(phone));
          setSheetState?.call(() {});
        }
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showMessage('تطبيق واتساب غير مثبت على الجهاز');
      }
    } catch (_) {
      _showMessage('تعذر إرسال الرسالة عبر واتساب');
    }
  }

  void _showContactOptions(String phone) {
    showModalBottomSheet(
      context: this.context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('خيارات التواصل ($phone)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.phone, color: Colors.white)),
                title: const Text('اتصال هاتفي بشكل مباشر'),
                onTap: () { Navigator.pop(ctx); _makePhoneCall(phone); },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.chat, color: Colors.white)),
                title: const Text('التواصل عبر واتساب'),
                onTap: () { Navigator.pop(ctx); _openWhatsApp(phone); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhonesDialog() {
    showModalBottomSheet(
      context: this.context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('الأرقام المكتشفة (${_extractedOrders.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text('تم مراسلة ${_sentPhones.length} من ${_extractedOrders.length}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
                const Divider(height: 20),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _extractedOrders.length,
                    itemBuilder: (ctx, index) {
                      final order = _extractedOrders[index];
                      final phone = order['mobile'].toString();
                      final isSent = _sentPhones.contains(phone);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(isSent ? Icons.check_circle : Icons.phone_android, color: isSent ? Colors.green : Colors.blueGrey),
                          title: Text(phone, style: TextStyle(fontWeight: FontWeight.bold, decoration: isSent ? TextDecoration.lineThrough : null)),
                          subtitle: Text('رقم الشحنة: ${order['orderId']}'),
                          trailing: ElevatedButton.icon(
                            onPressed: () => _openWhatsApp(phone, setSheetState),
                            icon: Icon(isSent ? Icons.done : Icons.send, size: 16),
                            label: Text(isSent ? 'تم' : 'إرسال'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSent ? Colors.grey.shade300 : Colors.green,
                              foregroundColor: isSent ? Colors.black54 : Colors.white,
                              elevation: isSent ? 0 : 2,
                            ),
                          ),
                          onTap: () { Navigator.pop(ctx); _showContactOptions(phone); },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated && _hasPinSet) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_person, size: 80, color: Colors.green),
                const SizedBox(height: 16),
                const Text('ادخل كلمة المرور لدخول التطبيق', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: _pinInputController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, letterSpacing: 8),
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '****'),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _verifyEnteredPin,
                  icon: const Icon(Icons.key),
                  label: const Text('دخول'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('مساعد التوصيل الاحترافي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _navigateToScreen(const SettingsScreen()),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Colors.green),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text('د', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
              ),
              accountName: Text('مساعد التوصيل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              accountEmail: Text('driver.account@app.com', style: TextStyle(fontSize: 12, color: Colors.white70)),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined, color: Colors.green),
              title: const Text('الرئيسية'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.list_alt_rounded, color: Colors.green),
              title: const Text('كشف التوصيل المالي (Manifest)'),
              onTap: () {
                Navigator.pop(context);
                _navigateToScreen(const manifest_file.ManifestSheetScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.green),
              title: const Text('سلة المحذوفات'),
              onTap: () {
                Navigator.pop(context);
                _navigateToScreen(const recycle_file.RecycleBinScreen());
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: Colors.grey),
              title: const Text('الإعدادات'),
              onTap: () {
                Navigator.pop(context);
                _navigateToScreen(const SettingsScreen());
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildActionCard(
              onTap: _isLoading ? null : _showImageSourceDialog,
              color: Colors.green,
              icon: _isLoading ? null : Icons.camera_alt_rounded,
              isLoading: _isLoading,
              title: _isLoading ? 'جاري قراءة الصورة...' : 'إضافة صورة جديدة (كاميرا / معرض)',
              subtitle: 'التقاط بوليصة الشحن أو الفاتورة واستخراج الأرقام',
              isPrimary: true,
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              onTap: () => _navigateToScreen(const manifest_file.ManifestSheetScreen()),
              color: Colors.blueGrey.shade50,
              iconColor: Colors.blueGrey,
              icon: Icons.assignment_turned_in_rounded,
              title: 'عرض كشف التوصيل المالي (Manifest)',
              subtitle: 'مراجعة وتعديل بيانات الشحنات المسجلة',
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              onTap: _extractedOrders.isEmpty || _isLoading
                  ? null
                  : () => _extractedOrders.length == 1
                      ? _showContactOptions(_extractedOrders.first['mobile'].toString())
                      : _showPhonesDialog(),
              color: _extractedOrders.isEmpty ? Colors.grey.shade100 : Colors.green.shade50,
              iconColor: _extractedOrders.isEmpty ? Colors.grey : Colors.green,
              icon: _extractedOrders.isEmpty ? Icons.person_off : Icons.contact_phone,
              title: _extractedOrders.isEmpty
                  ? 'لم يتم العثور على رقم هاتف'
                  : _extractedOrders.length == 1
                      ? 'التواصل مع العميل'
                      : 'مراسلة الأرقام المكتشفة',
              subtitle: _extractedOrders.isEmpty ? 'قم بالتقاط صورة أولاً لاستخراج الأرقام' : 'عدد الأرقام المتاحة: ${_extractedOrders.length}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required VoidCallback? onTap,
    required Color color,
    required IconData? icon,
    required String title,
    required String subtitle,
    bool isPrimary = false,
    Color iconColor = Colors.white,
    bool isLoading = false,
  }) {
    return Material(
      color: isPrimary ? color : Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: isPrimary ? 4 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: isPrimary
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isPrimary ? Colors.white.withValues(alpha: 0.2) : color,
                  shape: isPrimary ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: isPrimary ? null : BorderRadius.circular(12),
                ),
                child: _buildIconWidget(isPrimary, icon, iconColor, isLoading),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isPrimary ? 16 : 15,
                        fontWeight: FontWeight.bold,
                        color: isPrimary ? Colors.white : (onTap == null ? Colors.grey : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isPrimary ? Colors.white.withValues(alpha: 0.8) : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: isPrimary ? Colors.white : Colors.grey,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconWidget(bool isPrimary, IconData? icon, Color iconColor, bool isLoading) {
    if (isLoading && isPrimary) {
      return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
    }
    return Icon(icon, color: isPrimary ? Colors.white : iconColor, size: 24);
  }
}