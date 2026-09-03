import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'database_helper.dart';

class DeliveryMapScreen extends StatefulWidget {
  const DeliveryMapScreen({super.key});

  @override
  State<DeliveryMapScreen> createState() => _DeliveryMapScreenState();
}

class _DeliveryMapScreenState extends State<DeliveryMapScreen> {
  List<Map<String, dynamic>> _customers = [];
  LatLng? _currentPosition;
  bool _isLoading = true;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadDataAndCurrentLocation();
  }

  // جلب موقع السائق الفعلي + بيانات الشحنات من قاعدة البيانات
  Future<void> _loadDataAndCurrentLocation() async {
    setState(() => _isLoading = true);

    // 1. جلب بيانات الشحنات والعملاء من قاعدة البيانات
    final customers = await DatabaseHelper.instance.getSortedCustomersByDistance();

    // 2. محاولة جلب موقع الهاتف الحالي بدقة
    LatLng initialCenter = const LatLng(31.9539, 35.9106); // نقطة افتراضية (عمان)
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          initialCenter = LatLng(position.latitude, position.longitude);
          _currentPosition = initialCenter;
        }
      }
    } catch (e) {
      debugPrint("خطأ أثناء جلب الموقع الجغرافي: $e");
    }

    // إذا لم يتوفر موقع الجهاز، نأخذ موقع أول شحنة تحتوي على إحداثيات صحيحة
    if (_currentPosition == null && customers.isNotEmpty) {
      for (var c in customers) {
        if (c['lat'] != null && c['lng'] != null && c['lat'] != 0 && c['lng'] != 0) {
          initialCenter = LatLng(c['lat'], c['lng']);
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _customers = customers;
      _currentPosition = initialCenter;
      _isLoading = false;
    });
  }

  // فتح خرائط جوجل للتوجيه والإبحار نحو إحداثيات العميل
  Future<void> _openGoogleMapsNavigation(double lat, double lng, String customerName) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح تطبيق الخرائط')),
        );
      }
    } catch (e) {
      debugPrint('خطأ في فتح الخريطة: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('خريطة الشحنات التفاعلية'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'موقعي الحالي',
            onPressed: () {
              if (_currentPosition != null) {
                _mapController.move(_currentPosition!, 15.0);
              } else {
                _loadDataAndCurrentLocation();
              }
            },
          ),
        ],
      ),
      body: _isLoading || _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentPosition!,
                initialZoom: 14.0,
              ),
              children: [
                // طبقة الخريطة الأساسية
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.delivery_app',
                ),
                // طبقة العلامات التفاعلية
                MarkerLayer(
                  markers: [
                    // علامة موقع السائق الحالي (باللون الأزرق)
                    if (_currentPosition != null)
                      Marker(
                        point: _currentPosition!,
                        width: 45,
                        height: 45,
                        child: const Icon(
                          Icons.my_location_rounded,
                          color: Colors.blueAccent,
                          size: 40,
                        ),
                      ),
                    
                    // علامات الشحنات والعملاء (باللون الأحمر التفاعلي)
                    ..._customers
                        .where((c) => c['lat'] != null && c['lng'] != null && c['lat'] != 0 && c['lng'] != 0)
                        .map((customer) {
                      final double lat = customer['lat'];
                      final double lng = customer['lng'];
                      return Marker(
                        point: LatLng(lat, lng),
                        width: 45,
                        height: 45,
                        child: GestureDetector(
                          onTap: () {
                            // عند الضغط على العلامة تفتح نافذة تفاصيل تفاعلية أسفل الشاشة
                            _showCustomerDetails(context, customer);
                          },
                          child: const Icon(
                            Icons.location_pin,
                            color: Colors.red,
                            size: 45,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
    );
  }

  // نافذة تفاصيل العميل التفاعلية عند الضغط على أي دبوس في الخريطة
  void _showCustomerDetails(BuildContext context, Map<String, dynamic> customer) {
    final double? lat = customer['lat'];
    final double? lng = customer['lng'];
    final String customerName = customer['customerName'] ?? 'عميل بدون اسم';
    final String phone = customer['phone'] ?? 'غير متوفر';
    final String region = customer['region'] ?? 'غير متوفر';
    final double amount = customer['totalAmount'] ?? 0.0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    customerName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Chip(
                    label: Text('$amount دينار', style: const TextStyle(color: Colors.white)),
                    backgroundColor: Colors.green,
                  ),
                ],
              ),
              const Divider(height: 20),
              Text('📞 الهاتف: $phone', style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 6),
              Text('📍 المنطقة: $region', style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (lat != null && lng != null && lat != 0 && lng != 0)
                      ? () {
                          Navigator.pop(context);
                          _openGoogleMapsNavigation(lat, lng, customerName);
                        }
                      : null,
                  icon: const Icon(Icons.directions, color: Colors.white),
                  label: const Text('بدء التوجيه عبر خرائط جوجل', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}