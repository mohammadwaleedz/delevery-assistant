// route_optimization_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'database_helper.dart';

class RouteOptimizationScreen extends StatefulWidget {
  const RouteOptimizationScreen({super.key});

  @override
  State<RouteOptimizationScreen> createState() => _RouteOptimizationScreenState();
}

class _RouteOptimizationScreenState extends State<RouteOptimizationScreen> {
  List<Map<String, dynamic>> _optimizedOrders = [];
  final Set<int> _selectedIndices = {};
  bool _isLoading = true;
  int _currentNavigationIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAndOptimizeRoute();
  }

  bool _hasValidLocation(Map<String, dynamic> order) {
    final lat = order['lat'];
    final lng = order['lng'];
    final address = order['address']?.toString() ?? '';
    final notes = order['notes']?.toString() ?? '';

    if (lat != null && lng != null && lat.toString().isNotEmpty && lng.toString().isNotEmpty && lat.toString() != '0' && lng.toString() != '0') {
      return true;
    }
    if ((address.startsWith('http://') || address.startsWith('https://')) && !address.contains('تحديد الموقع')) {
      return true;
    }
    if (notes.startsWith('http://') || notes.startsWith('https://')) {
      return true;
    }
    if (address.isNotEmpty && 
        !address.contains('تحديد الموقع عبر الخريطة') && 
        !address.contains('تحديد الموقع')) {
      return true;
    }
    return false;
  }

  /// دالة لجلب وترتيب العملاء ذكياً بناءً على الموقع الحالي (الأقرب للأبعد)
  Future<void> _loadAndOptimizeRoute() async {
    setState(() => _isLoading = true);
    
    try {
      // جلب العملاء مرتبين تصاعدياً بناءً على المسافة الحالية للمستخدم عبر قاعدة البيانات
      List<Map<String, dynamic>> sortedRoute = await DatabaseHelper.instance.getSortedCustomersByDistance();

      Set<int> initialSelected = {};
      for (int i = 0; i < sortedRoute.length; i++) {
        if (_hasValidLocation(sortedRoute[i])) {
          initialSelected.add(i);
        }
      }

      if (!mounted) return;
      setState(() {
        _optimizedOrders = sortedRoute;
        _selectedIndices.clear();
        _selectedIndices.addAll(initialSelected);
        _currentNavigationIndex = initialSelected.isNotEmpty ? initialSelected.first : 0;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _optimizedOrders = [];
        _isLoading = false;
      });
    }
  }

  /// دالة يتم استدعاؤها عند الوصول للعميل لإعادة حساب الموقع وترتيب المسار تلقائياً
  Future<void> _onClientReached(int index) async {
    // يمكنك هنا تحديث حالة العميل إلى مكتمل في قاعدة البيانات إن أردت
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم الوصول للعميل! جاري إعادة تحديد موقعك وترتيب الأقرب...'),
        duration: Duration(seconds: 2),
      ),
    );

    // إعادة تحميل وترتيب القائمة بالكامل بناءً على الموقع اللحظي الجديد
    await _loadAndOptimizeRoute();
  }

  String _getBaseMapLink(Map<String, dynamic> order) {
    final lat = order['lat'];
    final lng = order['lng'];
    final address = order['address']?.toString().trim() ?? '';
    final notes = order['notes']?.toString().trim() ?? '';
    
    if (lat != null && lng != null) {
      final latStr = lat.toString().trim();
      final lngStr = lng.toString().trim();
      if (latStr.isNotEmpty && lngStr.isNotEmpty && latStr != '0' && lngStr != '0') {
        return 'https://www.google.com/maps/search/?api=1&query=$latStr,$lngStr';
      }
    }
    
    if (address.startsWith('http://') || address.startsWith('https://')) {
      return address;
    }
    if (notes.startsWith('http://') || notes.startsWith('https://')) {
      return notes;
    }
    
    if (address.isNotEmpty && 
        !address.contains('تحديد الموقع عبر الخريطة') && 
        !address.contains('تحديد الموقع')) {
      return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';
    }
    
    return 'https://www.google.com/maps/search/?api=1&query=Amman';
  }

  Future<String> _resolveAndCleanMapUrl(String inputUrl) async {
    try {
      String targetUrl = inputUrl.trim();

      if (targetUrl.contains('maps.app.goo.gl') || targetUrl.contains('goo.gl/maps')) {
        final uriObj = Uri.parse(targetUrl);
        final response = await http.get(uriObj);
        if (response.request?.url != null) {
          targetUrl = response.request!.url.toString();
        }
      }

      final uri = Uri.parse(targetUrl);

      if (uri.queryParameters.containsKey('q')) {
        final qValue = uri.queryParameters['q']!;
        if (RegExp(r'^-?\d+(\.\d+)?,-?\d+(\.\d+)?$').hasMatch(qValue)) {
          return 'https://www.google.com/maps/search/?api=1&query=$qValue';
        }
        return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(qValue)}';
      }

      if (uri.queryParameters.containsKey('sll')) {
        final sllValue = uri.queryParameters['sll']!;
        return 'https://www.google.com/maps/search/?api=1&query=$sllValue';
      }

      for (var segment in uri.pathSegments) {
        if (segment.startsWith('@')) {
          final coords = segment.substring(1).split(',');
          if (coords.length >= 2) {
            final lat = coords[0];
            final lng = coords[1];
            if (double.tryParse(lat) != null && double.tryParse(lng) != null) {
              return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
            }
          }
        }
      }

      return targetUrl;
    } catch (_) {
      return inputUrl;
    }
  }

  String _getDisplayAddress(Map<String, dynamic> order) {
    final address = order['address']?.toString() ?? '';
    if (address.startsWith('http')) return address;
    final notes = order['notes']?.toString() ?? '';
    if (notes.startsWith('http')) return notes;
    return address.isEmpty ? 'تحديد الموقع عبر الخريطة' : address;
  }

  void _smartSelectValidLocationsOnly() {
    setState(() {
      _selectedIndices.clear();
      for (int i = 0; i < _optimizedOrders.length; i++) {
        if (_hasValidLocation(_optimizedOrders[i])) {
          _selectedIndices.add(i);
        }
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تحديد ${_selectedIndices.length} شحنة التي تمتلك مواقع حقيقية مضافة فقط')),
    );
  }

  Future<void> _startRouteNavigation() async {
    if (_optimizedOrders.isEmpty) return;

    List<int> selectedList = _selectedIndices.toList()..sort();
    if (selectedList.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تحديد شحنة واحدة على الأقل لها موقع حقيقي لبدء الملاحة')),
      );
      return;
    }

    if (!selectedList.contains(_currentNavigationIndex)) {
      _currentNavigationIndex = selectedList.first;
    }

    final targetOrder = _optimizedOrders[_currentNavigationIndex];
    final baseLink = _getBaseMapLink(targetOrder);
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جاري تجهيز الرابط الإحداثي للملاحة...'), duration: Duration(milliseconds: 800)),
    );

    final finalMapLink = await _resolveAndCleanMapUrl(baseLink);
    final url = Uri.parse(finalMapLink);

    try {
      final bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;

      if (launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('جاري بدء ملاحة المحطة رقم ${_currentNavigationIndex + 1} (الأقرب إليك)'),
            action: SnackBarAction(
              label: 'تم الوصول ✅',
              onPressed: () {
                // عند الضغط هنا يعتبر أنه وصل، فيتم إعادة الترتيب الذكي فوراً
                _onClientReached(_currentNavigationIndex);
              },
            ),
            duration: const Duration(seconds: 8),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تشغيل تطبيق الملاحة الخارجي')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تشغيل الملاحة: $e')),
      );
    }
  }

  Future<void> _exportToPdfFile() async {
    if (_optimizedOrders.isEmpty) return;

    final itemsToExport = _selectedIndices.isNotEmpty
        ? _optimizedOrders.where((element) => _selectedIndices.contains(_optimizedOrders.indexOf(element))).toList()
        : _optimizedOrders;

    final pdf = pw.Document();
    pw.Font font;
    pw.Font boldFont;

    try {
      final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final boldFontData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
      font = pw.Font.ttf(fontData);
      boldFont = pw.Font.ttf(boldFontData);
    } catch (_) {
      font = pw.Font.helvetica();
      boldFont = pw.Font.helveticaBold();
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'تقرير مسار التوصيل الجغرافي الذكي المترتب',
                    style: pw.TextStyle(font: boldFont, fontSize: 22, color: PdfColors.green800),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'إجمالي المحطات المُصدرة: ${itemsToExport.length}',
                    style: pw.TextStyle(font: font, fontSize: 13),
                  ),
                  pw.SizedBox(height: 15),
                  pw.TableHelper.fromTextArray(
                    context: context,
                    border: pw.TableBorder.all(color: PdfColors.grey400),
                    headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 11),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
                    cellStyle: pw.TextStyle(font: font, fontSize: 10),
                    cellAlignment: pw.Alignment.centerRight,
                    headers: ['التسلسل', 'رقم الشحنة', 'المسافة التقريبية', 'الهاتف', 'العنوان / الرابط'],
                    data: List<List<String>>.generate(itemsToExport.length, (index) {
                      final order = itemsToExport[index];
                      double dist = order['distance'] ?? 0.0;
                      String distStr = dist > 1000 ? '${(dist / 1000).toStringAsFixed(1)} كم' : '${dist.toStringAsFixed(0)} متر';
                      return [
                        '${index + 1}',
                        '${order['orderId'] ?? order['id'] ?? 'غير معروف'}',
                        distStr,
                        '${order['mobile'] ?? order['phone'] ?? 'بدون'}',
                        _getDisplayAddress(order),
                      ];
                    }),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    try {
      final output = await getApplicationDocumentsDirectory();
      final file = File('${output.path}/optimized_delivery_route.pdf');
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تصدير ملف الـ PDF بنجاح: ${file.path}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل في حفظ ملف الـ PDF')),
      );
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد مسح البيانات'),
        content: const Text('هل أنت متأكد من رغبتك في حذف جميع سجلات المسار والشحنات؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف الكل'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('manifest_items');

      if (!mounted) return;
      setState(() {
        _optimizedOrders.clear();
        _selectedIndices.clear();
        _currentNavigationIndex = 0;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم مسح السجلات بنجاح')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المسار الذكي التلقائي'),
        actions: [
          if (_optimizedOrders.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'تحديث الموقع وإعادة الترتيب',
              onPressed: _loadAndOptimizeRoute,
            ),
            IconButton(
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              tooltip: 'تحديد الشحنات ذات المواقع الحقيقية فقط',
              onPressed: _smartSelectValidLocationsOnly,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              tooltip: 'حذف البيانات',
              onPressed: _clearAllData,
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'تصدير PDF',
              onPressed: _exportToPdfFile,
            ),
            IconButton(
              icon: const Icon(Icons.navigation_rounded),
              tooltip: 'بدء الملاحة التسلسلية',
              onPressed: _startRouteNavigation,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _optimizedOrders.isEmpty
              ? const Center(
                  child: Text(
                    'لا توجد محطات متاحة لترتيب المسار\nقم بإضافة شحنات جديدة للمتابعة',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.green.shade50,
                      child: Row(
                        children: [
                          const Icon(Icons.alt_route, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ترتيب تلقائي حسب الأقرب | المحطات: ${_optimizedOrders.length} | المحددة: ${_selectedIndices.length}',
                              style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _optimizedOrders.length,
                        itemBuilder: (context, index) {
                          final order = _optimizedOrders[index];
                          final displayAddress = _getDisplayAddress(order);
                          final isSelected = _selectedIndices.contains(index);
                          final isCurrentNavTarget = _currentNavigationIndex == index;
                          final hasLocation = _hasValidLocation(order);

                          double distanceInMeters = order['distance'] ?? 0.0;
                          String distanceText = distanceInMeters > 1000
                              ? '${(distanceInMeters / 1000).toStringAsFixed(1)} كم'
                              : '${distanceInMeters.toStringAsFixed(0)} متر';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            elevation: isSelected ? 3 : 1,
                            color: isCurrentNavTarget ? Colors.green.shade50 : (isSelected ? Colors.white : Colors.grey.shade100),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isCurrentNavTarget ? Colors.green : (isSelected ? Colors.green.shade300 : Colors.transparent),
                                width: isCurrentNavTarget ? 2.0 : 1.5,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: Colors.green,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedIndices.add(index);
                                        } else {
                                          _selectedIndices.remove(index);
                                        }
                                      });
                                    },
                                  ),
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: index == 0 ? Colors.green : (isCurrentNavTarget ? Colors.orange : (hasLocation ? Colors.blueGrey : Colors.grey)),
                                    foregroundColor: Colors.white,
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'شحنة: ${order['orderId'] ?? order['id'] ?? 'غير معروف'}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: index == 0 ? Colors.green.shade100 : Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      index == 0 ? '📍 الأقرب إليك' : 'المسافة: $distanceText',
                                      style: TextStyle(
                                        color: index == 0 ? Colors.green.shade800 : Colors.blue.shade800,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('الهاتف: ${order['mobile'] ?? order['phone'] ?? 'بدون'}', style: const TextStyle(fontSize: 12)),
                                  Text(
                                    'الموقع: $displayAddress',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: hasLocation ? Colors.blue : Colors.red.shade700,
                                      fontWeight: hasLocation ? FontWeight.normal : FontWeight.bold,
                                      decoration: hasLocation ? TextDecoration.underline : TextDecoration.none,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.directions_car, color: Colors.green, size: 22),
                                    tooltip: 'بدء الملاحة لهذه المحطة',
                                    onPressed: () async {
                                      setState(() {
                                        _currentNavigationIndex = index;
                                      });
                                      await _startRouteNavigation();
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.done_all, color: Colors.orange, size: 22),
                                    tooltip: 'تم الوصول (إعادة ترتيب المسار للأقرب)',
                                    onPressed: () => _onClientReached(index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _optimizedOrders.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _startRouteNavigation,
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.navigation),
              label: Text('بدء ملاحة الأقرب (${_selectedIndices.length})'),
            )
          : null,
    );
  }
}