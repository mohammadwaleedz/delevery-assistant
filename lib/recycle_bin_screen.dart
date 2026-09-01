// recycle_bin_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'database_helper.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  List<Map<String, dynamic>> _deletedItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecycleBinData();
  }

  Future<void> _loadRecycleBinData() async {
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseHelper.instance.getRecycleBinItems();

      if (!mounted) return;
      setState(() {
        _deletedItems = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('حدث خطأ أثناء تحميل سلة المحذوفات: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction({
    required Future<void> Function() action,
    required String successMessage,
    Color successColor = Colors.green,
  }) async {
    try {
      await action();
      _showSnackBar(successMessage, successColor);
      _loadRecycleBinData();
    } catch (e) {
      _showSnackBar('حدث خطأ: $e', Colors.red);
    }
  }

  Future<void> _restoreItem(int id) => _handleAction(
        action: () async {
          await DatabaseHelper.instance.restoreFromRecycleBin(id);
        },
        successMessage: 'تم استرجاع الشحنة بنجاح',
      );

  Future<void> _permanentlyDelete(int id) async {
    final confirm = await _showConfirmDialog(
      title: 'حذف نهائي',
      content: 'هل أنت متأكد من حذف هذه الشحنة نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
      confirmText: 'حذف نهائي',
      confirmColor: Colors.red,
    );

    if (confirm == true) {
      _handleAction(
        action: () async {
          await DatabaseHelper.instance.permanentlyDelete(id);
        },
        successMessage: 'تم حذف الشحنة نهائياً',
        successColor: Colors.grey,
      );
    }
  }

  Future<void> _emptyRecycleBin() async {
    if (_deletedItems.isEmpty) return;

    final confirm = await _showConfirmDialog(
      title: 'تفريغ سلة المحذوفات',
      content: 'هل أنت متأكد من رغبتك في حذف جميع العناصر المحذوفة نهائياً؟',
      confirmText: 'تفريغ الكل',
      confirmColor: Colors.red,
    );

    if (confirm == true) {
      _handleAction(
        action: () async {
          await DatabaseHelper.instance.clearRecycleBin();
        },
        successMessage: 'تم تفريغ سلة المحذوفات بنجاح',
        successColor: Colors.grey,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سلة المحذوفات'),
          backgroundColor: Colors.teal.shade800,
          foregroundColor: Colors.white,
          actions: [
            if (_deletedItems.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep, size: 28),
                tooltip: 'تفريغ السلة',
                onPressed: _emptyRecycleBin,
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _deletedItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_outline, size: 80, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'سلة المحذوفات فارغة',
                          style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _deletedItems.length,
                    itemBuilder: (context, index) {
                      final item = _deletedItems[index];
                      final id = item['id'] ?? 0;
                      final customerName = item['customer_name'] ?? 'بدون اسم';
                      final phone = item['phone'] ?? 'لا يوجد هاتف';
                      final storeName = item['store_name'] ?? 'متجر عام';
                      final price = item['price'] ?? 0.0;
                      final formattedPrice = intl.NumberFormat('#,##0.00').format(price);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.inventory_2_outlined, color: Colors.red.shade400),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customerName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'الهاتف: $phone | المتجر: $storeName',
                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'المبلغ: $formattedPrice د.أ',
                                      style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.restore, color: Colors.green),
                                    tooltip: 'استرجاع للكشف',
                                    onPressed: () => _restoreItem(id),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                                    tooltip: 'حذف نهائي',
                                    onPressed: () => _permanentlyDelete(id),
                                  ),
                                ],
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