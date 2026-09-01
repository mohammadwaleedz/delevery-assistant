import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:url_launcher/url_launcher.dart';
import 'database_helper.dart';
import 'security_service.dart';
import 'settings_screen.dart';
import 'app_theme.dart'; // استيراد الثيم الحقيقي
import 'route_optimization_screen.dart'; // استيراد شاشة مسار التوصيل الذكي الجديدة
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
      theme: AppTheme.lightTheme, // الاعتماد على الثيم الحقيقي المستورد بنجاح
      home: const HomeScreen(),
    );
  }
}

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
    if (!mounted) return;
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
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _checkSecurity();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
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

    if (!mounted) return;
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
          'mobile': matches[i],
          'address': 'عمان - تحديد الموقع عبر الخريطة',
          'pcs': 1,
          'collectionAmount': 15.0,
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

  Future<void> _openWhatsApp(String phone) async {
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
        if (!mounted) return;
        setState(() => _sentPhones.add(phone));
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
      context: context,
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

  void _showLocationInputDialog(String phone, String orderId, StateSetter setSheetState) {
    final TextEditingController locationController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تحديد موقع العميل (شحنة: $orderId)'),
        content: TextField(
          controller: locationController,
          decoration: const InputDecoration(
            labelText: 'أدخل تفاصيل الموقع أو العنوان',
            hintText: 'مثال: عمان - الجبيهة - شارع الجامعة',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              String newLocation = locationController.text.trim();
              if (newLocation.isNotEmpty) {
                await DatabaseHelper.instance.updateManifestItemAddress(orderId, newLocation);
                
                if (!mounted) return;

                setState(() {
                  final index = _extractedOrders.indexWhere((o) => o['orderId'] == orderId);
                  if (index != -1) {
                    _extractedOrders[index]['address'] = newLocation;
                  }
                });

                setSheetState(() {});
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _showMessage('تم حفظ موقع العميل بنجاح');
              }
            },
            child: const Text('حفظ الموقع'),
          ),
        ],
      ),
    );
  }

  void _showPhonesDialog() {
    showModalBottomSheet(
      context: context,
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
                    Text(
                      'تم تحديد مواقع لـ ${_extractedOrders.where((o) => o['address'] != 'عمان - تحديد الموقع عبر الخريطة').length}', 
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
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
                      final orderId = order['orderId'].toString();
                      final currentAddress = order['address'] ?? '';
                      bool hasLocation = currentAddress != 'عمان - تحديد الموقع عبر الخريطة' && currentAddress.isNotEmpty;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            hasLocation ? Icons.location_on : Icons.location_off, 
                            color: hasLocation ? Colors.green : Colors.orange,
                          ),
                          title: Text(phone, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('رقم الشحنة: $orderId'),
                              Text(
                                'الموقع: $currentAddress', 
                                style: TextStyle(fontSize: 12, color: hasLocation ? Colors.black87 : Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: ElevatedButton.icon(
                            onPressed: () => _showLocationInputDialog(phone, orderId, setSheetState),
                            icon: const Icon(Icons.edit_location_alt, size: 16),
                            label: const Text('الموقع'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasLocation ? Colors.green.shade50 : Colors.green,
                              foregroundColor: hasLocation ? Colors.green.shade800 : Colors.white,
                              elevation: hasLocation ? 0 : 2,
                            ),
                          ),
                          onTap: () { 
                            Navigator.pop(ctx); 
                            _showContactOptions(phone); 
                          },
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
          // أيقونة مسار التوصيل الذكي الجديدة في الأعلى
          IconButton(
            icon: const Icon(Icons.alt_route_rounded),
            tooltip: 'مسار التوصيل الذكي',
            onPressed: () => _navigateToScreen(const RouteOptimizationScreen()),
          ),
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
              leading: const Icon(Icons.alt_route_rounded, color: Colors.green),
              title: const Text('مسار التوصيل الذكي'),
              onTap: () {
                Navigator.pop(context);
                _navigateToScreen(const RouteOptimizationScreen());
              },
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
              isLoading: false,
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
                      : 'مراسلة وتحديد مواقع الأرقام',
              subtitle: _extractedOrders.isEmpty ? 'قم بالتقاط صورة أولاً لاستخراج الأرقام' : 'عدد الأرقام المتاحة: ${_extractedOrders.length}',
              isLoading: _isLoading,
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
    required bool isLoading,
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
                child: isLoadingWidget(isPrimary, icon, iconColor),
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

  Widget isLoadingWidget(bool isPrimary, IconData? icon, Color iconColor) {
    if (_isLoading && isPrimary) {
      return const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
    }
    return Icon(icon, color: isPrimary ? Colors.white : iconColor, size: 24);
  }
}