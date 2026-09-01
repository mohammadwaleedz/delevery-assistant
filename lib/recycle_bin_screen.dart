import 'package:flutter/material.dart';
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

  // تحميل الشحنات من سلة المحذوفات
  Future<void> _loadRecycleBinData() async {
    setState(() => _isLoading = true);
    // نفترض أن دالة جلب المحذوفات في DatabaseHelper اسمها getRecycleBinItems
    final data = await DatabaseHelper.instance.getRecycleBinItems();
    if (!mounted) return;

    setState(() {
      _deletedItems = data;
      _isLoading = false;
    });
  }

  // استعادة شحنة واحدة إلى الكشف الرئيسي
  Future<void> _restoreItem(int id) async {
    await DatabaseHelper.instance.restoreManifestItem(id);
    await _loadRecycleBinData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت استعادة الشحنة بنجاح إلى كشف التوصيل')),
    );
  }

  // حذف شحنة واحدة نهائياً
  Future<void> _permanentlyDeleteItem(int id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف نهائي'),
          content: const Text('هل أنت تأكد من حذف هذه الشحنة نهائياً؟ لا يمكنك استرجاعها بعد ذلك.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('حذف نهائي', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.permanentlyDeleteManifestItem(id);
      await _loadRecycleBinData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الشحنة نهائياً')),
      );
    }
  }

  // تفريغ سلة المحذوفات بالكامل
  Future<void> _clearAllRecycleBin() async {
    if (_deletedItems.isEmpty) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تفرّيغ سلة المحذوفات'),
          content: const Text('هل أنت تأكد من مسح جميع الشحنات المحذوفة نهائياً؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('مسح الكل', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.clearRecycleBin();
      await _loadRecycleBinData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تفريغ سلة المحذوفات بالكامل')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('سلة المحذوفات (${_deletedItems.length})'),
          backgroundColor: Colors.red.shade800,
          foregroundColor: Colors.white,
          actions: [
            if (_deletedItems.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_forever),
                onPressed: _clearAllRecycleBin,
                tooltip: 'تفريغ السلة بالكامل',
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _deletedItems.isEmpty
                ? const Center(
                    child: Text(
                      'سلة المحذوفات فارغة حالياً.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _deletedItems.length,
                    itemBuilder: (context, index) {
                      final item = _deletedItems[index];
                      final int itemId = item['id'];

                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        color: Colors.red.shade50,
                        child: ListTile(
                          title: Text(
                            'شحنة رقم: ${item['orderId'] ?? 'غير محدد'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('📍 العنوان: ${item['address'] ?? 'غير محدد'}'),
                              Text('📞 الهاتف: ${item['mobile'] ?? 'غير متوفر'}'),
                              Text('💰 المبلغ المطلوب: ${item['collectionAmount'] ?? 0} د.أ'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // زر الاستعادة
                              IconButton(
                                icon: const Icon(Icons.restore_from_trash, color: Colors.green),
                                onPressed: () => _restoreItem(itemId),
                                tooltip: 'استعادة للشاشة الرئيسية',
                              ),
                              // زر الحذف النهائي
                              IconButton(
                                icon: const Icon(Icons.delete_forever, color: Colors.red),
                                onPressed: () => _permanentlyDeleteItem(itemId),
                                tooltip: 'حذف نهائي',
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
