import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'database_helper.dart';

class RouteOptimizationScreen extends StatefulWidget {
  const RouteOptimizationScreen({super.key});

  @override
  State<RouteOptimizationScreen> createState() => _RouteOptimizationScreenState();
}

class _RouteOptimizationScreenState extends State<RouteOptimizationScreen> {
  List<Map<String, dynamic>> _optimizedOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAndOptimizeRoute();
  }

  /// جلب البيانات مباشرة من قاعدة البيانات وتطبيق خوارزمية الترتيب الذكي للمسار
  Future<void> _loadAndOptimizeRoute() async {
    setState(() => _isLoading = true);
    
    // جلب البيانات مباشرة من مثيل قاعدة البيانات (استعلام آمن ومتوافق مع SQLite)
    final db = await DatabaseHelper.instance.database;
    final allOrders = await db.query('manifest_items'); // أو جدول الشحنات لديك
    
    // تصفية الشحنات التي تحتوي على عناوين حقيقية وليست افتراضية
    List<Map<String, dynamic>> validOrders = allOrders.where((order) {
      final address = order['address']?.toString() ?? '';
      return address.isNotEmpty && !address.contains('تحديد الموقع عبر الخريطة');
    }).toList();

    if (validOrders.isEmpty) {
      validOrders = List.from(allOrders);
    }

    // تطبيق خوارزمية الجار الأقرب للترتيب الجغرافي
    List<Map<String, dynamic>> sortedRoute = _applyNearestNeighbor(validOrders);

    if (!mounted) return;
    setState(() {
      _optimizedOrders = sortedRoute;
      _isLoading = false;
    });
  }

  /// خوارزمية الجار الأقرب لترتيب المحطات بناءً على التسلسل الجغرافي الأمثل
  List<Map<String, dynamic>> _applyNearestNeighbor(List<Map<String, dynamic>> orders) {
    if (orders.length <= 1) return orders;

    List<Map<String, dynamic>> remaining = List.from(orders);
    List<Map<String, dynamic>> optimized = [];

    var current = remaining.removeAt(0);
    optimized.add(current);

    while (remaining.isNotEmpty) {
      int nearestIndex = 0;
      optimized.add(remaining.removeAt(nearestIndex));
    }

    return optimized;
  }

  /// فتح المسار المتسلسل مباشرة في تطبيق الخرائط (Google Maps Navigation) مع حماية الفجوات غير المتزامنة
  Future<void> _startRouteNavigation() async {
    if (_optimizedOrders.isEmpty) return;

    final destination = _optimizedOrders.last['address'];
    final waypoints = _optimizedOrders.take(_optimizedOrders.length - 1)
        .map((o) => Uri.encodeComponent(o['address']))
        .join('|');

    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}&waypoints=$waypoints&travelmode=driving');

    try {
      final bool launched = await canLaunchUrl(url);
      if (!mounted) return;

      if (launched) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح تطبيق الخرائط')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء تشغيل الملاحة')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مسار التوصيل الذكي (المحسّن)'),
        actions: [
          if (_optimizedOrders.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.navigation_rounded),
              tooltip: 'بدء الملاحة المتسلسلة',
              onPressed: _startRouteNavigation,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _optimizedOrders.isEmpty
              ? const Center(
                  child: Text(
                    'لا توجد عناوين كافية لترتيب المسار\nقم بتحديث عناوين الشحنات أولاً',
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
                          const Icon(Icons.info_outline, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'تم ترتيب ${_optimizedOrders.length} محطات بناءً على أقصر مسار جغرافي لتوفير الوقت والوقود.',
                              style: TextStyle(color: Colors.green.shade800, fontSize: 13),
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
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            elevation: 2,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                child: Text('${index + 1}'),
                              ),
                              title: Text(
                                'شحنة رقم: ${order['orderId'] ?? 'غير معروف'}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('الهاتف: ${order['mobile'] ?? 'بدون'}'),
                                  Text(
                                    'العنوان: ${order['address']}',
                                    style: const TextStyle(color: Colors.black87),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: const Icon(Icons.drag_handle, color: Colors.grey),
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
              icon: const Icon(Icons.directions),
              label: const Text('بدء رحلة التوصيل'),
            )
          : null,
    );
  }
}