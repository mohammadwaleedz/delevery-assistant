import 'package:flutter/material.dart';
import 'database_helper.dart';

class ManifestSheetScreen extends StatefulWidget {
  const ManifestSheetScreen({super.key});

  @override
  State<ManifestSheetScreen> createState() => _ManifestSheetScreenState();
}

class _ManifestSheetScreenState extends State<ManifestSheetScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadManifestData();
  }

  Future<void> _loadManifestData() async {
    setState(() => _isLoading = true);
    final orders = await DatabaseHelper.instance.getManifestItems();
    setState(() {
      _orders = orders;
      _isLoading = false;
    });
  }

  int get _totalCount => _orders.length;

  int get _deliveredCount =>
      _orders.where((o) => o['status'] == 'تم التوصيل').length;

  int get _pendingCount =>
      _orders.where((o) => o['status'] == 'قيد التوصيل' || o['status'] == 'لم يتم التوصيل').length;

  int get _delayedCount =>
      _orders.where((o) => o['status'] == 'مؤجلة').length;

  int get _cancelledCount =>
      _orders.where((o) => o['status'] == 'ملغاة').length;

  double get _totalExpectedAmount =>
      _orders.fold(0.0, (sum, item) => sum + (item['collectionAmount'] ?? 0.0));

  double get _totalCollectedAmount =>
      _orders.fold(0.0, (sum, item) => sum + (item['collectionAmount'] ?? 0.0));

  double get _totalDriverShare =>
      _orders.fold(0.0, (sum, item) => sum + 2.0);

  double get _totalShopShare =>
      _orders.fold(0.0, (sum, item) => sum + ((item['collectionAmount'] ?? 0.0) - 2.0));

  Map<String, Map<String, dynamic>> get _shopSummary {
    final Map<String, Map<String, dynamic>> summary = {};

    for (var order in _orders) {
      final shop = (order['pageName'] != null && order['pageName'].toString().isNotEmpty) 
          ? order['pageName'].toString() 
          : 'عام / غير محدد';
          
      if (!summary.containsKey(shop)) {
        summary[shop] = {
          'count': 0,
          'totalCollected': 0.0,
          'shopShare': 0.0,
          'deliveryFee': 0.0,
        };
      }
      double amount = (order['collectionAmount'] ?? 0.0) is int 
          ? (order['collectionAmount'] as int).toDouble() 
          : (order['collectionAmount'] ?? 0.0);

      summary[shop]!['count'] = (summary[shop]!['count'] as int) + 1;
      summary[shop]!['totalCollected'] = (summary[shop]!['totalCollected'] as double) + amount;
      summary[shop]!['shopShare'] = (summary[shop]!['shopShare'] as double) + amount;
      summary[shop]!['deliveryFee'] = (summary[shop]!['deliveryFee'] as double) + 2.0;
    }

    return summary;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('كشف المانفيست والتقارير'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث البيانات',
              onPressed: _loadManifestData,
            ),
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'طباعة الكشف',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('جاري تجهيز الكشف للطباعة...')),
                );
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _orders.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد شحنات مسجلة في الكشف الحالي',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFinancialSummaryCard(),
                        const SizedBox(height: 12),
                        _buildStatusSummaryCard(),
                        const SizedBox(height: 16),
                        const Text(
                          'ملخص المستحقات حسب المتجر',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildShopSummaryTable(),
                        const SizedBox(height: 16),
                        const Text(
                          'تفاصيل شحنات المانفيست',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildOrdersTable(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildFinancialSummaryCard() {
    return Card(
      elevation: 3,
      color: Colors.teal.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            const Text(
              'الإجمالي المالي المباشر (من قاعدة البيانات)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem('المبلغ المتوقع', '$_totalExpectedAmount د.أ', Colors.black),
                _statItem('المحصل فعلياً', '$_totalCollectedAmount د.أ', Colors.blue),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem('صافي للمتاجر', '$_totalShopShare د.أ', Colors.orange.shade800),
                _statItem('أجرة السائق', '$_totalDriverShare د.أ', Colors.green.shade800),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSummaryCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _badgeCount('الكل', _totalCount, Colors.grey.shade700),
            _badgeCount('مكتمل', _deliveredCount, Colors.green),
            _badgeCount('قيد التوصيل', _pendingCount, Colors.blue),
            _badgeCount('مؤجل', _delayedCount, Colors.orange),
            _badgeCount('ملغى', _cancelledCount, Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildShopSummaryTable() {
    final summary = _shopSummary;
    return Card(
      elevation: 2,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('المتجر / الصفحة')),
            DataColumn(label: Text('عدد الشحنات')),
            DataColumn(label: Text('المحصل')),
            DataColumn(label: Text('أجرة التوصيل')),
            DataColumn(label: Text('صافي المتجر')),
          ],
          rows: summary.entries.map((entry) {
            return DataRow(cells: [
              DataCell(Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text('${entry.value['count']}')),
              DataCell(Text('${entry.value['totalCollected']} د.أ')),
              DataCell(Text('${entry.value['deliveryFee']} د.أ')),
              DataCell(Text(
                '${entry.value['shopShare']} د.أ',
                style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOrdersTable() {
    return Card(
      elevation: 2,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('رقم الشحنة')),
            DataColumn(label: Text('الهاتف')),
            DataColumn(label: Text('العنوان')),
            DataColumn(label: Text('الحالة')),
            DataColumn(label: Text('المبلغ')),
          ],
          rows: List.generate(_orders.length, (index) {
            final item = _orders[index];
            final orderId = item['orderId']?.toString() ?? '-';
            final mobile = item['mobile']?.toString() ?? '-';
            final address = item['address']?.toString() ?? '-';
            final status = item['status']?.toString() ?? 'قيد التوصيل';
            final amount = item['collectionAmount']?.toString() ?? '0';

            return DataRow(cells: [
              DataCell(Text('${index + 1}')),
              DataCell(Text(orderId)),
              DataCell(Text(mobile)),
              DataCell(Text(address)),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              DataCell(Text('$amount د.أ')),
            ]);
          }),
        ),
      ),
    );
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
        return Colors.blue;
    }
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _badgeCount(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

// تصحيح الكلاس الأخير ليصبح Widget صحيحاً:
class RecycleBinScreen extends StatelessWidget {
  const RecycleBinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سلة المحذوفات'),
          backgroundColor: Colors.teal,
        ),
        body: const Center(
          child: Text('لا توجد عناصر محذوفة حالياً'),
        ),
      ),
    );
  }
}