import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:url_launcher/url_launcher.dart';
import 'app_constants.dart';
import 'app_theme.dart';
import 'app_utils.dart';
import 'database_helper.dart';

class ManifestSheetScreen extends StatefulWidget {
  const ManifestSheetScreen({super.key});

  @override
  State<ManifestSheetScreen> createState() => _ManifestSheetScreenState();
}

class _ManifestSheetScreenState extends State<ManifestSheetScreen> {
  List<DeliveryOrder> _orders = [];
  bool _isLoading = true;
  final Set<int> _selectedOrderIds = {};
  bool _isSelectAll = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseHelper.instance.getDeliveryOrders();
      setState(() {
        _orders = data;
        _sortOrdersList();
        _isLoading = false;
        _selectedOrderIds.clear();
        _isSelectAll = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تحميل البيانات: $e')),
        );
      }
    }
  }

  void _sortOrdersList() {
    _orders.sort((a, b) {
      bool aIsPending = StatusUtils.isActive(a.status);
      bool bIsPending = StatusUtils.isActive(b.status);
      if (aIsPending && !bIsPending) return -1;
      if (!aIsPending && bIsPending) return 1;
      return 0;
    });
  }

  Future<void> _launchWhatsApp(String phone) async {
    final uri = PhoneUtils.buildWhatsAppUri(phone, AppMessages.whatsappDefaultMessage);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر فتح تطبيق الواتساب')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    }
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _isSelectAll = value ?? false;
      if (_isSelectAll) {
        _selectedOrderIds.clear();
        for (var order in _orders) {
          if (order.id != null) _selectedOrderIds.add(order.id!);
        }
      } else {
        _selectedOrderIds.clear();
      }
    });
  }

  Future<void> _deleteSingleOrder(int id) async {
    try {
      await DatabaseHelper.instance.deleteDeliveryOrder(id);
      setState(() {
        _selectedOrderIds.remove(id);
        _orders.removeWhere((order) => order.id == id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الشحنة بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحذف: $e')),
        );
      }
    }
  }

  Future<void> _deleteSelectedOrders() async {
    if (_selectedOrderIds.isEmpty) return;
    try {
      // استخدام الحذف الجماعي لتحسين الأداء
      await DatabaseHelper.instance.deleteDeliveryOrdersBatch(_selectedOrderIds.toList());
      setState(() {
        _orders.removeWhere((order) => order.id != null && _selectedOrderIds.contains(order.id));
        _selectedOrderIds.clear();
        _isSelectAll = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الشحنات المحددة بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحذف الجماعي: $e')),
        );
      }
    }
  }

  Future<void> _updateOrderInDb(DeliveryOrder order) async {
    try {
      await DatabaseHelper.instance.updateDeliveryOrder(order);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحفظ في قاعدة البيانات: $e')),
        );
      }
    }
  }

  // دالة بدء الملاحة والتوجه إلى إحداثيات العميل باستخدام url_launcher
  Future<void> _startNavigation(double latitude, double longitude) async {
    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'
    );
    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppMessages.errorMaps)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فتح تطبيق الخرائط: $e')),
      );
    }
  }

  // دالة إدخال وتحديث موقع العميل والتحقق منه عبر مكتبة geocoding
  Future<void> _showLocationInputDialog(BuildContext context, DeliveryOrder order) async {
    final TextEditingController locationController = TextEditingController();
    bool isSaveEnabled = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('تحديث موقع: ${order.customerName}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: locationController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'أدخل عنوان العميل أو المنطقة الجغرافية',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        isSaveEnabled = value.trim().isNotEmpty;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'سيتم تحويل العنوان إلى إحداثيات وحفظه تلقائياً',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('إلغاء'),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSaveEnabled ? Colors.green : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSaveEnabled
                      ? () async {
                          final newLocation = locationController.text.trim();
                          Navigator.pop(dialogContext);
                          await _saveLocation(context, order, newLocation);
                        }
                      : null,
                  child: const Text('حفظ وبحث'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveLocation(BuildContext context, DeliveryOrder order, String newLocation) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('جاري البحث عن الموقع وحفظه...'),
          ],
        ),
        duration: Duration(seconds: 3),
      ),
    );

    try {
      final geocoding.Geocoding geocoder = geocoding.Geocoding();
      List<geocoding.Location> locations = await geocoder.locationFromAddress(newLocation);

      if (locations.isNotEmpty) {
        double lat = locations.first.latitude;
        double lng = locations.first.longitude;

        // حفظ باستخدام id المضمون
        if (order.id != null) {
          await DatabaseHelper.instance.updateManifestItemAddressWithCoordsById(order.id!, newLocation, lat, lng);
        }

        // تحديث العنوان في الواجهة مباشرة
        setState(() {
          final index = _orders.indexWhere((o) => o.id == order.id);
          if (index != -1) {
            _orders[index] = order.copyWith(address: newLocation, lat: lat, lng: lng);
          }
        });

        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('${AppMessages.successLocationSaved}\n$newLocation')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'عرض على الخريطة',
              textColor: Colors.white,
              onPressed: () => _startNavigation(lat, lng),
            ),
          ),
        );
      } else {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text(AppMessages.errorLocationInvalid),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('خطأ في البحث عن الموقع: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showAmountInputDialog({
    required String title,
    required String label,
    required Function(double) onSubmit,
  }) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(labelText: label),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                double? val = double.tryParse(controller.text);
                if (val != null) {
                  Navigator.pop(context);
                  onSubmit(val);
                }
              },
              child: const Text('موافق'),
            ),
          ],
        );
      },
    );
  }

  double get _totalRequired =>
      _orders.fold(0.0, (sum, item) => sum + item.totalAmount);

  double get _totalCollected =>
      _orders.fold(0.0, (sum, item) => sum + item.actualCollectedAmount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('كشف التوصيل المالي'),
        backgroundColor: AppTheme.secondaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedOrderIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _deleteSelectedOrders,
              tooltip: 'حذف المحدد',
            ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {},
            tooltip: 'طباعة الكشف',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.grey.shade100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _isSelectAll,
                            onChanged: _toggleSelectAll,
                          ),
                          const SizedBox(width: 4),
                          const Text('تحديد الكل', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Text(
                        'المطلوب: ${MoneyUtils.formatWithCurrency(_totalRequired)} | المحصل: ${MoneyUtils.formatWithCurrency(_totalCollected)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selectedOrderIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    color: Colors.blue.shade50,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('تم تحديد ${_selectedOrderIds.length} شحنة', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                _showApplyDialog(isStatus: true);
                              },
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('تغيير الحالة للكل', style: TextStyle(fontSize: 11)),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                _showApplyDialog(isStatus: false);
                              },
                              icon: const Icon(Icons.payment, size: 16),
                              label: const Text('تغيير الدفع للكل', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 1, thickness: 1),
                Expanded(
                  child: _orders.isEmpty
                      ? const Center(
                          child: Text(
                            'لا توجد شحنات مسجلة حالياً',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _orders.length,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          itemBuilder: (context, index) {
                            final order = _orders[index];
                            final isSelected = order.id != null &&
                                _selectedOrderIds.contains(order.id);
                            final displayAddress = AddressUtils.getDisplayAddress(
                                '${order.region.isNotEmpty ? '${order.region} - ' : ''}${order.address}');
                            final hasValidAddr = displayAddress != DefaultAddresses.notRequested;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Checkbox(
                                                value: isSelected,
                                                onChanged: (bool? value) {
                                                  if (order.id == null) return;
                                                  setState(() {
                                                    if (value == true) {
                                                      _selectedOrderIds.add(order.id!);
                                                    } else {
                                                      _selectedOrderIds.remove(order.id!);
                                                      _isSelectAll = false;
                                                    }
                                                  });
                                                },
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'رقم الشحنة: ${order.orderId.isNotEmpty ? order.orderId : '---'}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (order.id != null)
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                              onPressed: () => _deleteSingleOrder(order.id!),
                                              tooltip: 'حذف الشحنة',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                        ],
                                      ),
                                      
                                      Padding(
                                        padding: const EdgeInsets.only(right: 36.0, bottom: 4.0),
                                        child: Text(
                                          'المبلغ المطلوب: ${MoneyUtils.formatWithCurrency(order.totalAmount)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.indigo,
                                          ),
                                        ),
                                      ),

                                      Padding(
                                        padding: const EdgeInsets.only(right: 36.0, bottom: 8.0),
                                        child: Text(
                                          'المبلغ المحصل: ${MoneyUtils.formatWithCurrency(order.actualCollectedAmount)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                      
                                      Padding(
                                        padding: const EdgeInsets.only(right: 36.0, left: 4.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'هاتف: ${PhoneUtils.toLocalFormat(order.phone)}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.blue,
                                                decoration: TextDecoration.underline,
                                              ),
                                            ),
                                            ElevatedButton.icon(
                                              onPressed: () => _launchWhatsApp(order.phone),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                minimumSize: const Size(0, 32),
                                              ),
                                              icon: const Icon(Icons.send, size: 14),
                                              label: const Text('إرسال', style: TextStyle(fontSize: 12)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Padding(
                                        padding: const EdgeInsets.only(right: 36.0),
                                        child: Row(
                                          children: [
                                            Icon(Icons.location_on, size: 16, color: hasValidAddr ? Colors.grey.shade600 : Colors.orange),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'العنوان: $displayAddress',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: hasValidAddr ? Colors.grey.shade700 : Colors.orange.shade800,
                                                  fontWeight: hasValidAddr ? FontWeight.normal : FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () => _showLocationInputDialog(context, order),
                                              borderRadius: BorderRadius.circular(20),
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(Icons.edit_location_alt, size: 18, color: Colors.blue.shade700),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      Padding(
                                        padding: const EdgeInsets.only(right: 36.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              decoration: BoxDecoration(
                                                border: Border.all(color: Colors.grey.shade400),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  isExpanded: true,
                                                  value: PaymentMethod.all.contains(order.paymentMethod) 
                                                      ? order.paymentMethod 
                                                      : PaymentMethod.all.first,
                                                  items: PaymentMethod.all.map((String method) {
                                                    return DropdownMenuItem<String>(
                                                      value: method,
                                                      child: Text(method, style: const TextStyle(fontSize: 12)),
                                                    );
                                                  }).toList(),
                                                  onChanged: (String? newValue) async {
                                                    if (newValue != null) {
                                                      final updatedOrder = order.copyWith(paymentMethod: newValue);
                                                      setState(() {
                                                        final index = _orders.indexWhere((o) => o.id == order.id);
                                                        if (index != -1) {
                                                          _orders[index] = updatedOrder;
                                                        }
                                                      });
                                                      await _updateOrderInDb(updatedOrder);
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              decoration: BoxDecoration(
                                                border: Border.all(color: Colors.grey.shade400),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  isExpanded: true,
                                                  value: OrderStatus.all.contains(order.status) 
                                                      ? order.status 
                                                      : OrderStatus.all.first,
                                                  items: OrderStatus.all.map((String status) {
                                                    return DropdownMenuItem<String>(
                                                      value: status,
                                                      child: Text(status, style: const TextStyle(fontSize: 12)),
                                                    );
                                                  }).toList(),
                                                  onChanged: (String? newValue) async {
                                                    if (newValue != null) {
                                                      if (newValue == OrderStatus.delivered) {
                                                        _showAmountInputDialog(
                                                          title: 'أدخل المبلغ المحصل',
                                                          label: 'المبلغ المحصل (د.أ)',
                                                          onSubmit: (collected) async {
                                                            final updatedOrder = order.copyWith(
                                                              status: newValue,
                                                              actualCollectedAmount: collected,
                                                            );
                                                            setState(() {
                                                              final index = _orders.indexWhere((o) => o.id == order.id);
                                                              if (index != -1) {
                                                                _orders[index] = updatedOrder;
                                                                _sortOrdersList();
                                                              }
                                                            });
                                                            await _updateOrderInDb(updatedOrder);
                                                          },
                                                        );
                                                      } else if (newValue == OrderStatus.cancelledWithFee) {
                                                        _showAmountInputDialog(
                                                          title: 'أدخل قيمة رسوم التوصيل',
                                                          label: 'رسوم التوصيل (د.أ)',
                                                          onSubmit: (fee) async {
                                                            final updatedOrder = order.copyWith(
                                                              status: newValue,
                                                              actualCollectedAmount: order.actualCollectedAmount + fee,
                                                            );
                                                            setState(() {
                                                              final index = _orders.indexWhere((o) => o.id == order.id);
                                                              if (index != -1) {
                                                                _orders[index] = updatedOrder;
                                                                _sortOrdersList();
                                                              }
                                                            });
                                                            await _updateOrderInDb(updatedOrder);
                                                          },
                                                        );
                                                      } else {
                                                        final updatedOrder = order.copyWith(status: newValue);
                                                        setState(() {
                                                          final index = _orders.indexWhere((o) => o.id == order.id);
                                                          if (index != -1) {
                                                            _orders[index] = updatedOrder;
                                                            _sortOrdersList();
                                                          }
                                                        });
                                                        await _updateOrderInDb(updatedOrder);
                                                      }
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  void _showApplyDialog({required bool isStatus}) {
    String selectedValue = isStatus ? OrderStatus.all.first : PaymentMethod.all.first;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isStatus ? 'تحديد حالة الشحنة للكل' : 'تحديد طريقة الدفع للكل'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return DropdownButton<String>(
                isExpanded: true,
                value: selectedValue,
                items: (isStatus ? OrderStatus.all : PaymentMethod.all).map((val) {
                  return DropdownMenuItem(
                    value: val,
                    child: Text(val),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setStateDialog(() => selectedValue = val);
                  }
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (isStatus) {
                  if (selectedValue == OrderStatus.delivered) {
                    _showAmountInputDialog(
                      title: 'أدخل المبلغ المحصل للكل',
                      label: 'المبلغ المحصل (د.أ)',
                      onSubmit: (collected) async {
                        setState(() {
                          for (int i = 0; i < _orders.length; i++) {
                            final order = _orders[i];
                            // استخدام الـ id حصراً لربط التحديث بشكل قاطع ومأمون
                            if (order.id != null && _selectedOrderIds.contains(order.id)) {
                              _orders[i] = order.copyWith(
                                status: selectedValue,
                                actualCollectedAmount: collected,
                              );
                            }
                          }
                          _sortOrdersList();
                        });
                        for (int i = 0; i < _orders.length; i++) {
                          final order = _orders[i];
                          if (order.id != null && _selectedOrderIds.contains(order.id)) {
                            await _updateOrderInDb(order);
                          }
                        }
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم تطبيق التعديلات وحفظها بنجاح')),
                        );
                      },
                    );
                  } else {
                    setState(() {
                      for (int i = 0; i < _orders.length; i++) {
                        final order = _orders[i];
                        if (order.id != null && _selectedOrderIds.contains(order.id)) {
                          _orders[i] = order.copyWith(status: selectedValue);
                        }
                      }
                      _sortOrdersList();
                    });
                    _saveBulkUpdates();
                  }
                } else {
                  setState(() {
                    for (int i = 0; i < _orders.length; i++) {
                      final order = _orders[i];
                      if (order.id != null && _selectedOrderIds.contains(order.id)) {
                        _orders[i] = order.copyWith(paymentMethod: selectedValue);
                      }
                    }
                  });
                  _saveBulkUpdates();
                }
              },
              child: const Text('تطبيق'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveBulkUpdates() async {
    try {
      for (int i = 0; i < _orders.length; i++) {
        final order = _orders[i];
        if (order.id != null && _selectedOrderIds.contains(order.id)) {
          await DatabaseHelper.instance.updateDeliveryOrder(order);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تطبيق وتحديث الشحنات المحددة بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل حفظ التعديلات الجماعية: $e')),
        );
      }
    }
  }
}