import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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

  final List<String> _paymentMethods = ['نقداً', 'كليك'];
  final List<String> _statuses = [
    'قيد التوصيل',
    'تم التوصيل',
    'مؤجل',
    'ملغي وتم تحصيل رسوم التوصيل',
    'ملغي و لم يتم تحصيل رسوم التوصيل'
  ];

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
      bool aIsPending = a.status == 'قيد التوصيل';
      bool bIsPending = b.status == 'قيد التوصيل';
      if (aIsPending && !bIsPending) return -1;
      if (!aIsPending && bIsPending) return 1;
      return 0;
    });
  }

  String _formatPhone(String phone) {
    if (phone.isEmpty) return '---';
    String trimmed = phone.trim();
    if (!trimmed.startsWith('0') && trimmed.isNotEmpty) {
      return '0$trimmed';
    }
    return trimmed;
  }

  String _getDisplayAddress(DeliveryOrder order) {
    final address = order.address.trim();
    if (address.isEmpty || address.contains('تحديد الموقع عبر الخريطة') || address.contains('تحديد الموقع')) {
      return 'لم تطلب الموقع من العميل';
    }
    return address;
  }

  Future<void> _launchWhatsApp(String phone) async {
    String formattedPhone = _formatPhone(phone);
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '962${formattedPhone.substring(1)}';
    }
    
    const String message = 'الله يعطيك العافية\nمعك مندوب شركة التوصيل\nإذا سمحت أرسل موقعك';
    
    final Uri whatsappUri = Uri.parse('https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
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
      for (var id in _selectedOrderIds) {
        await DatabaseHelper.instance.deleteDeliveryOrder(id);
      }
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('كشف التوصيل المالي'),
          backgroundColor: const Color(0xFF37474F),
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
                          'المطلوب: ${_totalRequired.toStringAsFixed(2)} د.أ | المحصل: ${_totalCollected.toStringAsFixed(2)} د.أ',
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
                              final displayAddress = _getDisplayAddress(order);
                              final hasValidAddr = displayAddress != 'لم تقم بالتواصل مع العميل الآن';

                              var text = Text(
                                            'العنوان: ${order.region.isNotEmpty ? order.region : ''} - $displayAddress',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: hasValidAddr ? Colors.grey.shade700 : Colors.orange.shade800,
                                              fontWeight: hasValidAddr ? FontWeight.normal : FontWeight.bold,
                                            ),
                                          );
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
                                            'المبلغ المطلوب: ${order.totalAmount.toStringAsFixed(2)} د.أ',
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
                                            'المبلغ المحصل: ${order.actualCollectedAmount.toStringAsFixed(2)} د.أ',
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
                                                'هاتف: ${_formatPhone(order.phone)}',
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
                                          child: text,
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
                                                    value: _paymentMethods.contains(order.paymentMethod) 
                                                        ? order.paymentMethod 
                                                        : _paymentMethods.first,
                                                    items: _paymentMethods.map((String method) {
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
                                                    value: _statuses.contains(order.status) 
                                                        ? order.status 
                                                        : _statuses.first,
                                                    items: _statuses.map((String status) {
                                                      return DropdownMenuItem<String>(
                                                        value: status,
                                                        child: Text(status, style: const TextStyle(fontSize: 12)),
                                                      );
                                                    }).toList(),
                                                    onChanged: (String? newValue) async {
                                                      if (newValue != null) {
                                                        if (newValue == 'تم التوصيل') {
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
                                                        } else if (newValue == 'ملغي وتم تحصيل رسوم التوصيل') {
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
      ),
    );
  }

  void _showApplyDialog({required bool isStatus}) {
    String selectedValue = isStatus ? _statuses.first : _paymentMethods.first;
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
                items: (isStatus ? _statuses : _paymentMethods).map((val) {
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
                  if (selectedValue == 'تم التوصيل') {
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