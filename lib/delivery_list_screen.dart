import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'database_helper.dart';

String _formatPhoneNumber(String phone) {
  if (phone.isEmpty) return phone;
  String cleaned = phone.trim().replaceAll(RegExp(r'[^\d+]'), '');
  if (cleaned.startsWith('+')) return cleaned;
  if (!cleaned.startsWith('0') && cleaned.length >= 8 && cleaned.length <= 9) {
    return '0$cleaned';
  }
  return cleaned;
}

class DeliveryOrder {
  final int? id;
  final String orderId;
  final String customerName;
  final String phone;
  final String address;
  final double goodsValue;
  final double deliveryFee;
  String paymentMethod;
  String status;
  bool isFeeCollectedOnCancel;
  double actualCollectedAmount;
  String notes;
  final double lat;
  final double lng;
  final String itemsSummary;
  bool isDeleted;

  DeliveryOrder({
    this.id,
    required this.orderId,
    required this.customerName,
    required String phone,
    required this.address,
    required this.goodsValue,
    required this.deliveryFee,
    this.paymentMethod = 'نقداً',
    this.status = 'لم يتم التوصيل',
    this.isFeeCollectedOnCancel = false,
    double? actualCollectedAmount,
    this.notes = '',
    required this.lat,
    required this.lng,
    required this.itemsSummary,
    this.isDeleted = false,
  })  : phone = _formatPhoneNumber(phone),
        actualCollectedAmount =
            actualCollectedAmount ?? (goodsValue + deliveryFee);

  double get totalAmount => goodsValue + deliveryFee;

  factory DeliveryOrder.fromMap(Map<String, dynamic> map) {
    double gVal = (map['goodsValue'] != null)
        ? (map['goodsValue'] as num).toDouble()
        : (map['collectionAmount'] != null
            ? (map['collectionAmount'] as num).toDouble()
            : 0.0);
    double dFee = (map['deliveryFee'] != null)
        ? (map['deliveryFee'] as num).toDouble()
        : 2.0;

    return DeliveryOrder(
      id: map['id'],
      orderId: map['orderId'] ?? '',
      customerName: map['customerName'] ?? 'عميل',
      phone: map['mobile'] ?? '',
      address: map['address'] ?? '',
      goodsValue: gVal,
      deliveryFee: dFee,
      paymentMethod: map['paymentMethod'] ?? 'نقداً',
      status: map['status'] ?? 'لم يتم التوصيل',
      isFeeCollectedOnCancel: (map['isFeeCollectedOnCancel'] == 1 ||
          map['isFeeCollectedOnCancel'] == true),
      actualCollectedAmount: (map['actualCollectedAmount'] != null)
          ? (map['actualCollectedAmount'] as num).toDouble()
          : (gVal + dFee),
      notes: map['notes'] ?? '',
      lat: (map['lat'] != null) ? (map['lat'] as num).toDouble() : 31.9539,
      lng: (map['lng'] != null) ? (map['lng'] as num).toDouble() : 35.9106,
      itemsSummary: map['itemDescription'] ?? '',
      isDeleted: (map['isDeleted'] == 1 || map['isDeleted'] == true),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'customerName': customerName,
      'mobile': phone,
      'address': address,
      'goodsValue': goodsValue,
      'deliveryFee': deliveryFee,
      'paymentMethod': paymentMethod,
      'status': status,
      'isFeeCollectedOnCancel': isFeeCollectedOnCancel ? 1 : 0,
      'actualCollectedAmount': actualCollectedAmount,
      'notes': notes,
      'lat': lat,
      'lng': lng,
      'itemDescription': itemsSummary,
      'collectionAmount': totalAmount,
      'isDeleted': isDeleted ? 1 : 0,
    };
  }
}

class DeliveryListScreen extends StatefulWidget {
  const DeliveryListScreen({super.key});

  @override
  State<DeliveryListScreen> createState() => _DeliveryListScreenState();
}

class _DeliveryListScreenState extends State<DeliveryListScreen> {
  List<DeliveryOrder> _orders = [];
  bool _isLoading = true;

  // وضع التحديد والمتعدد للحذف
  bool _isSelectionMode = false;
  final Set<int> _selectedOrderIds = {};

  @override
  void initState() {
    super.initState();
    _loadOrdersFromDatabase();
  }

  Future<void> _loadOrdersFromDatabase() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getManifestItems();

    List<DeliveryOrder> loadedOrders = [];
    if (data.isEmpty) {
      await _insertInitialData();
      final freshData = await DatabaseHelper.instance.getManifestItems();
      loadedOrders = freshData.map((e) => DeliveryOrder.fromMap(e)).toList();
    } else {
      loadedOrders = data.map((e) => DeliveryOrder.fromMap(e)).toList();
    }

    // تصفية الشحنات الغير محذوفة فقط
    loadedOrders = loadedOrders.where((o) => !o.isDeleted).toList();

    // ترتيب الشحنات: نقل الشحنات التي تم توصيلها إلى نهاية القائمة
    loadedOrders.sort((a, b) {
      if (a.status == 'تم التوصيل' && b.status != 'تم التوصيل') return 1;
      if (a.status != 'تم التوصيل' && b.status == 'تم التوصيل') return -1;
      return 0;
    });

    if (!mounted) return;
    setState(() {
      _orders = loadedOrders;
      _isLoading = false;
      _selectedOrderIds.clear();
    });
  }

  Future<void> _insertInitialData() async {
    List<Map<String, dynamic>> initialOrders = [
      {
        'orderId': '#1001',
        'customerName': 'أحمد علي العبادي',
        'mobile': '791234567',
        'address': 'عمان - خلدا - شارع وصفي التل',
        'goodsValue': 23.0,
        'deliveryFee': 2.0,
        'paymentMethod': 'نقداً',
        'status': 'تم التوصيل',
        'actualCollectedAmount': 25.0,
        'notes': 'تم الاستلام بنجاح',
        'lat': 31.9875,
        'lng': 35.8456,
        'itemDescription': 'طرد ملابس',
        'isDeleted': 0,
      },
      {
        'orderId': '#1002',
        'customerName': 'محمد عمر الزعبي',
        'mobile': '788765432',
        'address': 'عمان - الجبيهة',
        'goodsValue': 42.5,
        'deliveryFee': 3.0,
        'paymentMethod': 'كليك CliQ',
        'status': 'لم يتم التوصيل',
        'actualCollectedAmount': 45.5,
        'notes': '',
        'lat': 32.0258,
        'lng': 35.8824,
        'itemDescription': 'أجهزة إلكترونية',
        'isDeleted': 0,
      },
    ];

    for (var order in initialOrders) {
      await DatabaseHelper.instance.insertManifestItem(order);
    }
  }

  Future<void> _updateOrder(DeliveryOrder order) async {
    if (order.id != null) {
      await DatabaseHelper.instance.updateManifestItemData(
        order.id!,
        order.toMap(),
      );
      await _loadOrdersFromDatabase();
    }
  }

  // حذف (أرشفة) الشحنات المحددة
  Future<void> _deleteSelectedOrders() async {
    if (_selectedOrderIds.isEmpty) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text(
              'هل أنت تأكد من نقل (${_selectedOrderIds.length}) شحنة إلى صفحة المحذوفات؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('نقل للمحذوفات',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      for (int id in _selectedOrderIds) {
        final order = _orders.firstWhere((o) => o.id == id);
        order.isDeleted = true;
        await DatabaseHelper.instance.updateManifestItemData(id, order.toMap());
      }
      setState(() {
        _isSelectionMode = false;
        _selectedOrderIds.clear();
      });
      await _loadOrdersFromDatabase();
    }
  }

  void _showEditDialog(DeliveryOrder order) {
    showDialog(
      context: context,
      builder: (context) {
        return _StatusEditDialog(
          order: order,
          onSave: (updatedOrder) {
            _updateOrder(updatedOrder);
          },
        );
      },
    );
  }

  Future<void> _openWhatsApp(String phone) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.startsWith('07')) {
      cleanPhone = '+962${cleanPhone.substring(1)}';
    }
    final uri = Uri.parse("https://wa.me/$cleanPhone");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri.parse("tel:$phone");
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final Uri googleMapsUri = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng");
    if (await canLaunchUrl(googleMapsUri)) {
      await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'تم التوصيل':
        return Colors.green;
      case 'مؤجلة':
        return Colors.orange;
      case 'ملغاة':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalDeliveredCount =
        _orders.where((o) => o.status == 'تم التوصيل').length;
    int totalCanceledCount = _orders.where((o) => o.status == 'ملغاة').length;
    int totalPostponedCount = _orders.where((o) => o.status == 'مؤجلة').length;

    double totalCollected =
        _orders.fold(0.0, (sum, item) => sum + item.actualCollectedAmount);

    double totalCash = _orders
        .where((o) => o.paymentMethod == 'نقداً')
        .fold(0.0, (sum, item) => sum + item.actualCollectedAmount);

    double totalCliq = _orders
        .where((o) => o.paymentMethod == 'كليك CliQ')
        .fold(0.0, (sum, item) => sum + item.actualCollectedAmount);

    double totalDeliveryFees = _orders
        .where((o) =>
            o.status == 'تم التوصيل' ||
            (o.status == 'ملغاة' && o.isFeeCollectedOnCancel))
        .fold(0.0, (sum, item) => sum + item.deliveryFee);

    double netToCompany = totalCollected - totalDeliveryFees;
    if (netToCompany < 0) netToCompany = 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode
            ? 'تحديد الشحنات (${_selectedOrderIds.length})'
            : 'جدول الحركة والتصفية اليومية'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteSelectedOrders,
              tooltip: 'حذف المحدد',
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSelectionMode = false;
                  _selectedOrderIds.clear();
                });
              },
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'تحديد متعدد للحذف',
              onPressed: () {
                setState(() {
                  _isSelectionMode = true;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'الشحنات المحذوفة',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DeletedOrdersScreen(),
                  ),
                );
                _loadOrdersFromDatabase();
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadOrdersFromDatabase,
            )
          ]
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(child: Text('لا توجد طلبات في جدول اليوم'))
              : Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _orders.length,
                          itemBuilder: (context, index) {
                            final order = _orders[index];
                            Color statusColor = _getStatusColor(order.status);
                            final bool isDelivered =
                                order.status == 'تم التوصيل';
                            final bool isSelected =
                                _selectedOrderIds.contains(order.id);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 3,
                              color: isDelivered ? Colors.green.shade50 : null,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: isSelected
                                    ? const BorderSide(
                                        color: Colors.red, width: 2)
                                    : BorderSide.none,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            if (_isSelectionMode &&
                                                order.id != null)
                                              Checkbox(
                                                value: isSelected,
                                                onChanged: (bool? checked) {
                                                  setState(() {
                                                    if (checked == true) {
                                                      _selectedOrderIds
                                                          .add(order.id!);
                                                    } else {
                                                      _selectedOrderIds
                                                          .remove(order.id!);
                                                    }
                                                  });
                                                },
                                              ),
                                            Text(
                                              'رقم الشحنة: ${order.orderId}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15),
                                            ),
                                            if (isDelivered) ...[
                                              const SizedBox(width: 6),
                                              const Icon(Icons.check_circle,
                                                  color: Colors.green,
                                                  size: 20),
                                            ]
                                          ],
                                        ),
                                        InkWell(
                                          onTap: () => _showEditDialog(order),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(
                                                  alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: statusColor),
                                            ),
                                            child: Text(
                                              order.status,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: statusColor),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    Text(
                                        'العميل: ${order.customerName} (${order.phone})',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    Text('العنوان: ${order.address}',
                                        style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontSize: 13)),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          Text('البضاعة: ${order.goodsValue} د.أ',
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                          Text('التوصيل: ${order.deliveryFee} د.أ',
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                          Text(
                                              'الإجمالي: ${order.totalAmount} د.أ',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal)),
                                          Text(
                                              'الدفع: ${order.paymentMethod}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                            'المحصل فعلياً: ${order.actualCollectedAmount} د.أ',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green)),
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              size: 20, color: Colors.grey),
                                          onPressed: () =>
                                              _showEditDialog(order),
                                        ),
                                      ],
                                    ),
                                    if (order.status == 'ملغاة')
                                      Text(
                                        order.isFeeCollectedOnCancel
                                            ? '• تم إلغاء الطلب مع تحصيل أجرة التوصيل'
                                            : '• تم إلغاء الطلب بدون تحصيل',
                                        style: const TextStyle(
                                            color: Colors.red,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    if (order.notes.isNotEmpty)
                                      Text('ملاحظات: ${order.notes}',
                                          style: const TextStyle(
                                              color: Colors.deepOrange,
                                              fontSize: 12)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () =>
                                                _openWhatsApp(order.phone),
                                            icon:
                                                const Icon(Icons.chat, size: 16),
                                            label: const Text('واتساب'),
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton.filledTonal(
                                          onPressed: () =>
                                              _makePhoneCall(order.phone),
                                          icon: const Icon(Icons.phone,
                                              color: Colors.blue),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () => _openGoogleMaps(
                                                order.lat, order.lng),
                                            icon: const Icon(Icons.navigation,
                                                size: 16),
                                            label: const Text('خرائط'),
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue,
                                                foregroundColor: Colors.white),
                                          ),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade900,
                          borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('📋 تصفية نهاية اليوم المالية',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    'مسلمة: $totalDeliveredCount | ملغاة: $totalCanceledCount | مؤجلة: $totalPostponedCount',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                                Text(
                                    'أجرتك: ${totalDeliveryFees.toStringAsFixed(2)} د.أ',
                                    style: const TextStyle(
                                        color: Colors.amber,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    'إجمالي المحصل: ${totalCollected.toStringAsFixed(2)} د.أ',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13)),
                                Text(
                                    '(كاش: ${totalCash.toStringAsFixed(2)} | كليك: ${totalCliq.toStringAsFixed(2)})',
                                    style: const TextStyle(
                                        color: Colors.white60, fontSize: 12)),
                              ],
                            ),
                            const Divider(color: Colors.white30, height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('الصافي الواجب تسليمه للشركة:',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                Text('${netToCompany.toStringAsFixed(2)} د.أ',
                                    style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// =================== شاشة الشحنات المحذوفة ===================

class DeletedOrdersScreen extends StatefulWidget {
  const DeletedOrdersScreen({super.key});

  @override
  State<DeletedOrdersScreen> createState() => _DeletedOrdersScreenState();
}

class _DeletedOrdersScreenState extends State<DeletedOrdersScreen> {
  List<DeliveryOrder> _deletedOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeletedOrders();
  }

  Future<void> _loadDeletedOrders() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getManifestItems();
    final allOrders = data.map((e) => DeliveryOrder.fromMap(e)).toList();

    setState(() {
      _deletedOrders = allOrders.where((o) => o.isDeleted).toList();
      _isLoading = false;
    });
  }

  // استعادة شحنة من المحذوفات إلى القائمة الرئيسية
  Future<void> _restoreOrder(DeliveryOrder order) async {
    if (order.id != null) {
      order.isDeleted = false;
      await DatabaseHelper.instance.updateManifestItemData(order.id!, order.toMap());
      await _loadDeletedOrders();
    }
  }

  // حذف نهائي للشحنة
  Future<void> _permanentlyDeleteOrder(DeliveryOrder order) async {
    if (order.id != null) {
      await DatabaseHelper.instance.deleteManifestItem(order.id!);
      await _loadDeletedOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أرشيف الشحنات المحذوفة'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _deletedOrders.isEmpty
              ? const Center(child: Text('لا توجد شحنات محذوفة'))
              : Directionality(
                  textDirection: TextDirection.rtl,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _deletedOrders.length,
                    itemBuilder: (context, index) {
                      final order = _deletedOrders[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Colors.red.shade50,
                        child: ListTile(
                          title: Text('رقم الشحنة: ${order.orderId}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('العميل: ${order.customerName}\nالعنوان: ${order.address}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.restore_from_trash, color: Colors.green),
                                tooltip: 'إعادة إلى القائمة',
                                onPressed: () => _restoreOrder(order),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_forever, color: Colors.red),
                                tooltip: 'حذف نهائي',
                                onPressed: () => _permanentlyDeleteOrder(order),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// =================== نافذة التعديل ===================

class _StatusEditDialog extends StatefulWidget {
  final DeliveryOrder order;
  final Function(DeliveryOrder) onSave;

  const _StatusEditDialog({required this.order, required this.onSave});

  @override
  State<_StatusEditDialog> createState() => _StatusEditDialogState();
}

class _StatusEditDialogState extends State<_StatusEditDialog> {
  late TextEditingController _notesController;
  late TextEditingController _amountController;
  late String _selectedStatus;
  late String _selectedPayment;
  late bool _isFeeCollected;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.order.notes);
    _amountController = TextEditingController(
        text: widget.order.actualCollectedAmount.toString());
    _selectedStatus = widget.order.status;
    _selectedPayment = widget.order.paymentMethod;
    _isFeeCollected = widget.order.isFeeCollectedOnCancel;
  }

  @override
  void dispose() {
    _notesController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text('تعديل حالة الشحنة (${widget.order.orderId})'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                decoration: const InputDecoration(labelText: 'حالة التوصيل'),
                items: ['تم التوصيل', 'لم يتم التوصيل', 'مؤجلة', 'ملغاة']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    _selectedStatus = val;
                    if (_selectedStatus == 'تم التوصيل') {
                      _amountController.text =
                          (widget.order.goodsValue + widget.order.deliveryFee)
                              .toString();
                    } else if (_selectedStatus == 'ملغاة') {
                      _amountController.text = _isFeeCollected
                          ? widget.order.deliveryFee.toString()
                          : '0.0';
                    } else if (_selectedStatus == 'مؤجلة' ||
                        _selectedStatus == 'لم يتم التوصيل') {
                      _amountController.text = '0.0';
                    }
                  });
                },
              ),
              const SizedBox(height: 10),
              if (_selectedStatus == 'ملغاة') ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'خيارات إلغاء الطلب:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.red,
                        ),
                      ),
                      RadioGroup<bool>(
                        groupValue: _isFeeCollected,
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() {
                            _isFeeCollected = val;
                            _amountController.text = _isFeeCollected
                                ? widget.order.deliveryFee.toString()
                                : '0.0';
                          });
                        },
                        child: const Column(
                          children: [
                            RadioListTile<bool>(
                              value: true,
                              title: Text(
                                'تم تحصيل مبلغ التوصيل فقط',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                            RadioListTile<bool>(
                              value: false,
                              title: Text(
                                'لم يتم تحصيل أي مبلغ (إلغاء كامل)',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              DropdownButtonFormField<String>(
                initialValue: _selectedPayment,
                decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                items: ['نقداً', 'كليك CliQ', 'مدفوع مسبقاً']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    _selectedPayment = val;
                  });
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'المبلغ المحصل فعلياً (د.أ)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                    labelText: 'ملاحظات (مثل: سبب الإلغاء/التأجيل)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              widget.order.status = _selectedStatus;
              widget.order.paymentMethod = _selectedPayment;
              widget.order.isFeeCollectedOnCancel = _isFeeCollected;
              widget.order.actualCollectedAmount =
                  double.tryParse(_amountController.text) ?? 0.0;
              widget.order.notes = _notesController.text;

              widget.onSave(widget.order);
              Navigator.pop(context);
            },
            child: const Text('حفظ التعديل'),
          )
        ],
      ),
    );
  }
}