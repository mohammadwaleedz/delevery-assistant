import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:url_launcher/url_launcher.dart';
import 'database_helper.dart';
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
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
    bool hasPin = await SecurityService.isPinSet();
    if (!mounted) return;
    setState(() {
      _hasPinSet = hasPin;
      _isAuthenticated = !hasPin; 
    });
  }

  Future<void> _verifyEnteredPin() async {
    String input = _pinInputController.text.trim();
    bool isValid = await SecurityService.verifyPin(input);

    if (isValid) {
      setState(() {
        _isAuthenticated = true;
      });
      _pinInputController.clear();
    } else {
      _showMessage('كلمة المرور غير صحيحة!');
    }
  }

  void _navigateToScreen(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
    _checkSecurity();
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image == null) return;

    setState(() {
      _isLoading = true;
      _extractedOrders.clear();
      _sentPhones.clear();
    });

    final inputImage = InputImage.fromFilePath(image.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      final RegExp phoneRegex = RegExp(r'\+?[0-9]{8,15}');
      final matches = phoneRegex.allMatches(recognizedText.text).map((m) => m.group(0)!).toSet().toList();

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

      setState(() {
        _extractedOrders = tempOrders;
      });

      _showMessage(
        matches.isEmpty 
            ? 'لم يتم العثور على أرقام هواتف في الصورة' 
            : 'تم استخراج وحفظ ${matches.length} رقم بنجاح في كشف التوصيل'
      );
    } catch (e) {
      _showMessage('حدث خطأ أثناء قراءة الصورة: $e');
    } finally {
      await textRecognizer.close();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (!cleanPhone.startsWith('0') && cleanPhone.length == 9) cleanPhone = '0$cleanPhone';

    final Uri uri = Uri(scheme: 'tel', path: cleanPhone);
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

    const defaultMessage = "الله يعطيك العافية\nمعك مندوب شركة التوصيل\nإذا سمحت أرسل موقعك";
    final Uri uri = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(defaultMessage)}");

    try {
      if (await canLaunchUrl(uri)) {
        if (mounted) {
          setState(() {
            _sentPhones.add(phone);
          });
          if (setSheetState != null) {
            setSheetState(() {});
          }
        }
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showMessage('تطبيق واتساب غير مثبت على الجهاز');
      }
    } catch (_) {
      _showMessage('تعذر إرسال الرسالة عبر واتساب');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showContactOptions(String phone) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('خيارات التواصل ($phone)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.phone, color: Colors.white)),
                title: const Text('اتصال هاتفي بشكل مباشر'),
                onTap: () {
                  Navigator.pop(ctx);
                  _makePhoneCall(phone);
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.chat, color: Colors.white)),
                title: const Text('التواصل عبر واتساب (مع رسالة جاهزة)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openWhatsApp(phone);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhonesDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
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
          );
        },
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
                const Text(
                  'ادخل كلمة المرور لدخول التطبيق',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _pinInputController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, letterSpacing: 8),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '****',
                  ),
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

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مساعد التوصيل'),
          centerTitle: true,
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _navigateToScreen(const SettingsScreen()),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.home), text: 'الرئيسية'),
              Tab(icon: Icon(Icons.assignment), text: 'الكشف'),
              Tab(icon: Icon(Icons.delete_outline), text: 'المحذوفات'),
            ],
          ),
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.green),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_shipping, size: 48, color: Colors.white),
                    SizedBox(height: 10),
                    Text(
                      'مساعد التوصيل',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home, color: Colors.green),
                title: const Text('الرئيسية'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.assignment, color: Colors.blueGrey),
                title: const Text('كشف التوصيل (Manifest)'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToScreen(const manifest_file.ManifestSheetScreen());
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.teal),
                title: const Text('سلة المحذوفات'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToScreen(const recycle_file.RecycleBinScreen());
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.grey),
                title: const Text('الإعدادات'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToScreen(const SettingsScreen());
                },
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _showImageSourceDialog,
                      icon: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.add_a_photo),
                      label: Text(_isLoading ? 'جاري قراءة الصورة...' : 'إضافة صورة (كاميرا / معرض)'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _navigateToScreen(const manifest_file.ManifestSheetScreen()),
                      icon: const Icon(Icons.assignment, color: Colors.white),
                      label: const Text('عرض كشف التوصيل المالي (Manifest)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey.shade800,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _extractedOrders.isEmpty || _isLoading
                          ? null
                          : () {
                              if (_extractedOrders.length == 1) {
                                _showContactOptions(_extractedOrders.first['mobile'].toString());
                              } else {
                                _showPhonesDialog();
                              }
                            },
                      icon: Icon(
                        _extractedOrders.isEmpty ? Icons.person_off : Icons.contact_phone,
                        color: _extractedOrders.isEmpty ? Colors.grey.shade600 : Colors.white,
                      ),
                      label: Text(
                        _extractedOrders.isEmpty
                            ? 'لم يتم العثور على رقم هاتف'
                            : _extractedOrders.length == 1
                                ? 'التواصل مع العميل (${_extractedOrders.first['mobile']})'
                                : 'مراسلة الأرقام المكتشفة (${_extractedOrders.length} أرقام)',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _extractedOrders.isEmpty ? Colors.grey.shade300 : Colors.green.shade700,
                        foregroundColor: _extractedOrders.isEmpty ? Colors.grey.shade600 : Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade600,
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const manifest_file.ManifestSheetScreen(),
            const recycle_file.RecycleBinScreen(),
          ],
        ),
      ),
    );
  }
}