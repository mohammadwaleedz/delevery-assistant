import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'database_helper.dart'; // استيراد مساعد قاعدة البيانات والنموذج

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'إدارة شحنات السائق',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      home: const DriverOrdersScreen(),
    );
  }
}

// =================== الصفحة الرئيسية للتوصيل ===================
class DriverOrdersScreen extends StatefulWidget {
  const DriverOrdersScreen({super.key});

  @override
  State<DriverOrdersScreen> createState() => _DriverOrdersScreenState();
}

class _DriverOrdersScreenState extends State<DriverOrdersScreen> {
  List<DeliveryOrder> _orders = [];
  bool _isLoading = true;

  final Set<int> _selectedOrderDbIds = {};
  String _searchQuery = '';
  String _filterStatus = 'الكل';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    final orders = await DatabaseHelper.instance.getDeliveryOrders();
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _isLoading = false;
    });
  }

  List<DeliveryOrder> get _filteredOrders {
    return _orders.where((order) {
      final matchesSearch = order.customerName.contains(_searchQuery) ||
          order.orderId.contains(_searchQuery) ||
          order.phone.contains(_searchQuery) ||
          order.region.contains(_searchQuery);

      final matchesStatus =
          _filterStatus == 'الكل' || order.status == _filterStatus;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  double get _totalCollected =>
      _orders.fold(0.0, (sum, item) => sum + item.actualCollectedAmount);

  double get _totalDriverFees =>
      _orders.fold(0.0, (sum, item) => sum + item.driverShare);

  double get _totalShopPayable =>
      _orders.fold(0.0, (sum, item) => sum + item.shopShare);

  Future<void> _openWhatsApp(String phone, String name) async {
    String formattedPhone = phone.replaceAll(' ', '');
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '+962${formattedPhone.substring(1)}';
    }
    final Uri url = Uri.parse(
        'https://wa.me/$formattedPhone?text=${Uri.encodeComponent('مرحباً $name، معكم كابتن التوصيل.')}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _makeCall(String phone) async {
    final Uri url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _showEditDialog(DeliveryOrder order) {
    showDialog(
      context: context,
      builder: (context) => _StatusEditDialog(
        order: order,
        onSave: (updatedOrder) async {
          if (updatedOrder.id != null) {
            await DatabaseHelper.instance.updateManifestItem(
              updatedOrder.id!,
              updatedOrder.toMap(),
            );
            await _loadOrders();
          }
        },
      ),
    );
  }

  void _deleteSelectedOrders() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text(
              'هل أنت متأكد من نقل (${_selectedOrderDbIds.length}) من الشحنات المحددة إلى سلة المهملات؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(ctx);
                for (int id in _selectedOrderDbIds) {
                  await DatabaseHelper.instance.deleteManifestItem(id);
                }
                setState(() => _selectedOrderDbIds.clear());
                await _loadOrders();
              },
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredOrders;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة توصيل الشحنات'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          actions: [
            if (_selectedOrderDbIds.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'حذف المحدد',
                onPressed: _deleteSelectedOrders,
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث البيانات',
              onPressed: _loadOrders,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _SummarySection(
                    totalCollected: _totalCollected,
                    totalDriverFees: _totalDriverFees,
                    totalShopPayable: _totalShopPayable,
                  ),
                  _FilterBarSection(
                    searchQuery: _searchQuery,
                    filterStatus: _filterStatus,
                    onSearchChanged: (val) => setState(() => _searchQuery = val),
                    onStatusChanged: (status) =>
                        setState(() => _filterStatus = status),
                  ),
                  Expanded(
                    child: filteredList.isEmpty
                        ? const Center(child: Text('لا توجد شحنات مطابقة'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              final order = filteredList[index];
                              final isSelected = order.id != null &&
                                  _selectedOrderDbIds.contains(order.id);

                              return _OrderCard(
                                order: order,
                                isSelected: isSelected,
                                onSelectChanged: (val) {
                                  if (order.id == null) return;
                                  setState(() {
                                    if (val == true) {
                                      _selectedOrderDbIds.add(order.id!);
                                    } else {
                                      _selectedOrderDbIds.remove(order.id);
                                    }
                                  });
                                },
                                onEdit: () => _showEditDialog(order),
                                onCall: () => _makeCall(order.phone),
                                onWhatsApp: () => _openWhatsApp(
                                    order.phone, order.customerName),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

// =================== قسم الملخص المالي ===================

class _SummarySection extends StatelessWidget {
  final double totalCollected;
  final double totalDriverFees;
  final double totalShopPayable;

  const _SummarySection({
    required this.totalCollected,
    required this.totalDriverFees,
    required this.totalShopPayable,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.teal.shade50,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          _buildCard('المحصل الكلي', '$totalCollected د.أ', Colors.blue),
          _buildCard('مستحق السائق', '$totalDriverFees د.أ', Colors.green),
          _buildCard('مستحق المتاجر', '$totalShopPayable د.أ', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// =================== قسم البحث والتصفية ===================

class _FilterBarSection extends StatelessWidget {
  final String searchQuery;
  final String filterStatus;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;

  const _FilterBarSection({
    required this.searchQuery,
    required this.filterStatus,
    required this.onSearchChanged,
    required this.onStatusChanged,
  });

  static const List<String> statuses = [
    'الكل',
    'قيد التوصيل',
    'تم التوصيل',
    'مؤجلة',
    'ملغاة'
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'بحث باسم العميل، الهاتف، المنطقة أو الرقم...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            ),
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: statuses.map((status) {
                final isSelected = filterStatus == status;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(status),
                    selected: isSelected,
                    selectedColor: Colors.teal,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                    onSelected: (selected) {
                      if (selected) onStatusChanged(status);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// =================== كارت عرض الشحنة ===================

class _OrderCard extends StatelessWidget {
  final DeliveryOrder order;
  final bool isSelected;
  final ValueChanged<bool?> onSelectChanged;
  final VoidCallback onEdit;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;

  const _OrderCard({
    required this.order,
    required this.isSelected,
    required this.onSelectChanged,
    required this.onEdit,
    required this.onCall,
    required this.onWhatsApp,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'تم التوصيل':
        return Colors.green;
      case 'مؤجلة':
        return Colors.orange;
      case 'ملغاة':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(order.status);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(value: isSelected, onChanged: onSelectChanged),
                Text(
                  order.orderId.isNotEmpty ? order.orderId : 'بدون رقم',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    order.status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            Text('العميل: ${order.customerName}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('المنطقة: ${order.region}'),
            if (order.address.isNotEmpty) Text('العنوان: ${order.address}'),
            if (order.pageName.isNotEmpty) Text('المتجر: ${order.pageName}'),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('المبلغ الكلي: ${order.totalAmount} د.أ'),
                Text('أجرة التوصيل: ${order.deliveryFee} د.أ'),
              ],
            ),
            if (order.status != 'قيد التوصيل' && order.status != 'لم يتم التوصيل') ...[
              const SizedBox(height: 4),
              Text(
                'المحصل فعلياً: ${order.actualCollectedAmount} د.أ (${order.paymentMethod})',
                style: const TextStyle(
                    color: Colors.teal, fontWeight: FontWeight.bold),
              ),
            ],
            if (order.notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('ملاحظات: ${order.notes}',
                  style: const TextStyle(color: Colors.grey)),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.phone, color: Colors.green),
                  onPressed: onCall,
                  tooltip: 'اتصال',
                ),
                IconButton(
                  icon: const Icon(Icons.chat, color: Colors.teal),
                  onPressed: onWhatsApp,
                  tooltip: 'واتساب',
                ),
                ElevatedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('تعديل الحالة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =================== نافذة تعديل حالة الشحنة ===================

class _StatusEditDialog extends StatefulWidget {
  final DeliveryOrder order;
  final ValueChanged<DeliveryOrder> onSave;

  const _StatusEditDialog({
    required this.order,
    required this.onSave,
  });

  @override
  State<_StatusEditDialog> createState() => _StatusEditDialogState();
}

class _StatusEditDialogState extends State<_StatusEditDialog> {
  late String _selectedStatus;
  late String _selectedPaymentMethod;
  late bool _isFeeCollectedOnCancel;
  late final TextEditingController _actualAmountController;
  late final TextEditingController _notesController;

  static const List<String> _statusOptions = [
    'قيد التوصيل',
    'تم التوصيل',
    'مؤجلة',
    'ملغاة',
  ];

  static const List<String> _paymentOptions = [
    'نقداً',
    'كليك CliQ',
  ];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.order.status;
    _selectedPaymentMethod = widget.order.paymentMethod;
    _isFeeCollectedOnCancel = widget.order.isFeeCollectedOnCancel;
    _actualAmountController = TextEditingController(
      text: widget.order.actualCollectedAmount.toString(),
    );
    _notesController = TextEditingController(text: widget.order.notes);
  }

  @override
  void dispose() {
    _actualAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _recalculateAmount() {
    if (_selectedStatus == 'تم التوصيل') {
      _actualAmountController.text = widget.order.totalAmount.toString();
    } else if (_selectedStatus == 'ملغاة') {
      _actualAmountController.text = _isFeeCollectedOnCancel
          ? widget.order.deliveryFee.toString()
          : '0.0';
    } else {
      _actualAmountController.text = '0.0';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(
            'تعديل حالة الشحنة (${widget.order.orderId.isNotEmpty ? widget.order.orderId : widget.order.customerName})'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _statusOptions.contains(_selectedStatus)
                    ? _selectedStatus
                    : _statusOptions.first,
                decoration: const InputDecoration(
                  labelText: 'حالة التوصيل',
                  border: OutlineInputBorder(),
                ),
                items: _statusOptions
                    .map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedStatus = val;
                      _recalculateAmount();
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _paymentOptions.contains(_selectedPaymentMethod)
                    ? _selectedPaymentMethod
                    : _paymentOptions.first,
                decoration: const InputDecoration(
                  labelText: 'طريقة الدفع',
                  border: OutlineInputBorder(),
                ),
                items: _paymentOptions
                    .map((method) => DropdownMenuItem(
                          value: method,
                          child: Text(method),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedPaymentMethod = val);
                  }
                },
              ),
              if (_selectedStatus == 'ملغاة') ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('تحصيل قيمة التوصيل فقط؟'),
                  subtitle:
                      Text('أجرة التوصيل: ${widget.order.deliveryFee} د.أ'),
                  value: _isFeeCollectedOnCancel,
                  onChanged: (bool value) {
                    setState(() {
                      _isFeeCollectedOnCancel = value;
                      _recalculateAmount();
                    });
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _actualAmountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'المبلغ المحصل فعلياً (د.أ)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              // الاستخدام النظيف والمختصر لـ copyWith بدلاً من التمرير اليدوي الخاطئ
              final updatedOrder = widget.order.copyWith(
                status: _selectedStatus,
                paymentMethod: _selectedPaymentMethod,
                isFeeCollectedOnCancel: _isFeeCollectedOnCancel,
                actualCollectedAmount:
                    double.tryParse(_actualAmountController.text) ?? 0.0,
                notes: _notesController.text.trim(),
              );

              widget.onSave(updatedOrder);
              Navigator.pop(context);
            },
            child: const Text('حفظ التعديلات'),
          ),
        ],
      ),
    );
  }
}