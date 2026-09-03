import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_constants.dart';
import 'app_theme.dart';
import 'app_utils.dart';
import 'database_helper.dart';
import 'delivery_map_screen.dart';

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
          _filterStatus == 'الكل' || StatusUtils.normalize(order.status) == _filterStatus;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  double get _totalCollected =>
      _orders.fold(0.0, (sum, item) => sum + item.actualCollectedAmount);

  double get _totalDriverFees =>
      _orders.fold(0.0, (sum, item) => sum + item.driverShare);

  double get _totalShopPayable =>
      _orders.fold(0.0, (sum, item) => sum + item.shopShare);

  String _getDisplayAddress(DeliveryOrder order) {
    return AddressUtils.getDisplayAddress(order.address);
  }

  Future<void> _openWhatsApp(String phone, String name) async {
    final uri = PhoneUtils.buildWhatsAppUri(
      phone,
      '${AppMessages.whatsappGreetingMessage} $name',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _makeCall(String phone) async {
    final uri = PhoneUtils.buildTelUri(phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
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
      builder: (ctx) => AlertDialog(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredOrders;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة توصيل الشحنات'),
        actions: [
          // زر الانتقال للخريطة التفاعلية في الأعلى
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'خريطة الشحنات',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DeliveryMapScreen()),
              );
            },
          ),
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
      
      // القائمة الجانبية (الـ 3 خطوط)
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.local_shipping, color: Colors.white, size: 40),
                  SizedBox(height: 10),
                  Text(
                    'إدارة شحنات السائق',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined, color: AppTheme.primaryColor),
              title: const Text('خريطة الشحنات التفاعلية', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context); // إغلاق القائمة أولاً
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DeliveryMapScreen()),
                );
              },
            ),
            const Divider(),
          ],
        ),
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
                            final displayAddress = _getDisplayAddress(order);
                            final hasValidAddr = displayAddress != DefaultAddresses.notRequested;

                            return _OrderCard(
                              order: order,
                              isSelected: isSelected,
                              displayAddress: displayAddress,
                              hasValidAddress: hasValidAddr,
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
    );
  }
}

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
      color: AppTheme.primaryLight,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          _buildCard('المحصل الكلي', MoneyUtils.formatWithCurrency(totalCollected), Colors.blue),
          _buildCard('مستحق السائق', MoneyUtils.formatWithCurrency(totalDriverFees), Colors.green),
          _buildCard('مستحق المتاجر', MoneyUtils.formatWithCurrency(totalShopPayable), Colors.orange),
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
    ...OrderStatus.all,
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
                    selectedColor: AppTheme.primaryColor,
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

class _OrderCard extends StatelessWidget {
  final DeliveryOrder order;
  final bool isSelected;
  final String displayAddress;
  final bool hasValidAddress;
  final ValueChanged<bool?> onSelectChanged;
  final VoidCallback onEdit;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;

  const _OrderCard({
    required this.order,
    required this.isSelected,
    required this.displayAddress,
    required this.hasValidAddress,
    required this.onSelectChanged,
    required this.onEdit,
    required this.onCall,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = OrderStatus.getStatusColor(StatusUtils.normalize(order.status));

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
                    StatusUtils.normalize(order.status),
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
            Text(
              'العنوان: $displayAddress',
              style: TextStyle(
                color: hasValidAddress ? Colors.black87 : Colors.orange.shade800,
                fontWeight: hasValidAddress ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            if (order.pageName.isNotEmpty) Text('المتجر: ${order.pageName}'),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('المبلغ الكلي: ${MoneyUtils.formatWithCurrency(order.totalAmount)}'),
                Text('أجرة التوصيل: ${MoneyUtils.formatWithCurrency(order.deliveryFee)}'),
              ],
            ),
            if (!StatusUtils.isActive(order.status)) ...[
              const SizedBox(height: 4),
              Text(
                'المحصل فعلياً: ${MoneyUtils.formatWithCurrency(order.actualCollectedAmount)} (${order.paymentMethod})',
                style: const TextStyle(
                    color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
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
                  icon: const Icon(Icons.chat, color: AppTheme.primaryColor),
                  onPressed: onWhatsApp,
                  tooltip: 'واتساب',
                ),
                ElevatedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('تعديل الحالة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
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

  @override
  void initState() {
    super.initState();
    _selectedStatus = StatusUtils.normalize(widget.order.status);
    _selectedPaymentMethod = PaymentMethod.normalize(widget.order.paymentMethod);
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
    if (_selectedStatus == OrderStatus.delivered) {
      _actualAmountController.text = widget.order.totalAmount.toString();
    } else if (_selectedStatus == OrderStatus.cancelledWithFee ||
        _selectedStatus == OrderStatus.cancelledWithoutFee) {
      _actualAmountController.text = _isFeeCollectedOnCancel
          ? widget.order.deliveryFee.toString()
          : '0.0';
    } else {
      _actualAmountController.text = '0.0';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          'تعديل حالة الشحنة (${widget.order.orderId.isNotEmpty ? widget.order.orderId : widget.order.customerName})'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: OrderStatus.all.contains(_selectedStatus)
                  ? _selectedStatus
                  : OrderStatus.all.first,
              decoration: const InputDecoration(
                labelText: 'حالة التوصيل',
                border: OutlineInputBorder(),
              ),
              items: OrderStatus.all
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
              initialValue: PaymentMethod.all.contains(_selectedPaymentMethod)
                  ? _selectedPaymentMethod
                  : PaymentMethod.all.first,
              decoration: const InputDecoration(
                labelText: 'طريقة الدفع',
                border: OutlineInputBorder(),
              ),
              items: PaymentMethod.all
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
            if (OrderStatus.cancelled.contains(_selectedStatus)) ...[
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('تحصيل قيمة التوصيل فقط؟'),
                subtitle:
                    Text('أجرة التوصيل: ${MoneyUtils.formatWithCurrency(widget.order.deliveryFee)}'),
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
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
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
    );
  }
}