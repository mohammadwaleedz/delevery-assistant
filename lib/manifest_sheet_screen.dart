import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

class ManifestSheetScreen extends StatefulWidget {
  const ManifestSheetScreen({super.key});

  @override
  State<ManifestSheetScreen> createState() => _ManifestSheetScreenState();
}

class _ManifestSheetScreenState extends State<ManifestSheetScreen> {
  List<Map<String, dynamic>> _manifestItems = [];
  final Set<int> _selectedIds = {};
  bool _isLoading = true;

  final List<String> _statusOptions = [
    'قيد التوصيل',
    'تم التسليم',
    'مؤجل',
    'مرتجع / رفض الاستلام (تم دفع التوصيل)',
    'مرتجع / رفض الاستلام (رفض دفع التوصيل)',
  ];

  final List<String> _paymentMethods = ['كاش', 'كليك'];

  @override
  void initState() {
    super.initState();
    _loadManifestData();
  }

  Future<void> _loadManifestData() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getManifestItems();
    if (!mounted) return;

    List<Map<String, dynamic>> sortedList = List<Map<String, dynamic>>.from(data);
    sortedList.sort((a, b) {
      bool aPending = (a['status'] ?? 'قيد التوصيل') == 'قيد التوصيل';
      bool bPending = (b['status'] ?? 'قيد التوصيل') == 'قيد التوصيل';
      if (aPending && !bPending) return -1;
      if (!aPending && bPending) return 1;
      return (b['id'] ?? 0).compareTo(a['id'] ?? 0);
    });

    setState(() {
      _manifestItems = sortedList;
      _isLoading = false;
      _selectedIds.removeWhere((id) => !_manifestItems.any((e) => e['id'] == id));
    });
  }

  double _parseDouble(dynamic val) => val is num ? val.toDouble() : double.tryParse(val?.toString() ?? '') ?? 0.0;

  double _calculateCollected(Map<String, dynamic> item) {
    if (item['customCollectedAmount'] != null) return _parseDouble(item['customCollectedAmount']);
    String status = item['status'] ?? 'قيد التوصيل';
    if (status == 'تم التسليم') return _parseDouble(item['collectionAmount']);
    if (status.contains('تم دفع التوصيل')) return _parseDouble(item['deliveryFee']);
    return 0.0;
  }

  String _formatPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return 'غير متوفر';
    String cleaned = phone.trim().replaceAll(RegExp(r'\s+'), '');
    return (cleaned.length == 9 && !cleaned.startsWith('0')) ? '0$cleaned' : cleaned;
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: _formatPhone(phone));
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _confirmDelete() async {
    if (_selectedIds.isEmpty) return;
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من نقل ${_selectedIds.length} شحنة إلى سلة المحذوفات؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('نقل', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      for (int id in _selectedIds) {
        await DatabaseHelper.instance.deleteManifestItem(id);
      }
      setState(() => _selectedIds.clear());
      _loadManifestData();
    }
  }

  Future<void> _batchStatusDialog() async {
    if (_selectedIds.isEmpty) return;
    String statusChoice = _statusOptions.first;

    String? res = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تعديل حالة ${_selectedIds.length} شحنات'),
          content: DropdownButtonFormField<String>(
            initialValue: statusChoice,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (val) => statusChoice = val ?? statusChoice,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, statusChoice), child: const Text('تطبيق')),
          ],
        ),
      ),
    );

    if (res != null) {
      for (int id in _selectedIds) {
        var item = _manifestItems.firstWhere((e) => e['id'] == id, orElse: () => {});
        double? customAmt;
        if (res.contains('مرتجع') || res.contains('رفض')) {
          customAmt = res.contains('تم دفع التوصيل') ? _parseDouble(item['deliveryFee']) : 0.0;
        }
        await DatabaseHelper.instance.updateManifestItem(id, {
          'status': res,
          'customCollectedAmount': customAmt,
        });
      }
      setState(() => _selectedIds.clear());
      _loadManifestData();
    }
  }

  Future<void> _updateItem(Map<String, dynamic> item, String newStatus) async {
    int id = item['id'];
    if (newStatus.contains('مرتجع') || newStatus.contains('رفض')) {
      TextEditingController ctrl = TextEditingController(
        text: (newStatus.contains('تم دفع التوصيل') ? _parseDouble(item['deliveryFee']) : 0.0).toStringAsFixed(2),
      );
      double? amt = await showDialog<double>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('المبلغ المحصل'),
            content: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder())),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text) ?? 0.0), child: const Text('حفظ')),
            ],
          ),
        ),
      );
      if (amt == null) return;
      await DatabaseHelper.instance.updateManifestItem(id, {'status': newStatus, 'customCollectedAmount': amt});
    } else {
      await DatabaseHelper.instance.updateManifestItem(id, {'status': newStatus, 'customCollectedAmount': null});
    }
    _loadManifestData();
  }

  Future<void> _printPdf() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (ctx) => [
          pw.TableHelper.fromTextArray(
            context: ctx,
            headers: ['م', 'رقم الشحنة', 'الهاتف', 'العنوان', 'الدفع', 'المحصل', 'الحالة'],
            headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellStyle: pw.TextStyle(font: font, fontSize: 8),
            data: _manifestItems.asMap().entries.map((e) {
              var item = e.value;
              return [
                '${e.key + 1}',
                item['orderId'] ?? '-',
                _formatPhone(item['mobile']),
                item['address'] ?? '-',
                item['paymentMethod'] ?? 'كاش',
                '${_calculateCollected(item).toStringAsFixed(2)} د.أ',
                item['status'] ?? 'قيد التوصيل',
              ];
            }).toList(),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    double totalReq = _manifestItems.fold(0, (s, i) => s + _parseDouble(i['collectionAmount']));
    double totalColl = _manifestItems.fold(0, (s, i) => s + _calculateCollected(i));
    bool isSelMode = _selectedIds.isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isSelMode ? 'تم تحديد ${_selectedIds.length}' : 'كشف التوصيل المالي'),
          backgroundColor: Colors.blueGrey.shade800,
          foregroundColor: Colors.white,
          actions: [
            if (isSelMode) ...[
              IconButton(icon: const Icon(Icons.edit_note, color: Colors.amber), onPressed: _batchStatusDialog),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: _confirmDelete),
            ] else
              IconButton(icon: const Icon(Icons.print), onPressed: _manifestItems.isEmpty ? null : _printPdf),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _manifestItems.isEmpty
                ? const Center(child: Text('لا توجد شحنات مضافة حالياً.', style: TextStyle(color: Colors.grey)))
                : Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        color: Colors.blueGrey.shade50,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _manifestItems.isNotEmpty && _selectedIds.length == _manifestItems.length,
                                  onChanged: (val) => setState(() {
                                    _selectedIds.clear();
                                    if (val == true) {
                                      _selectedIds.addAll(_manifestItems.map((e) => e['id'] as int));
                                    }
                                  }),
                                ),
                                const Text('تحديد الكل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            Text(
                              'المطلوب: ${totalReq.toStringAsFixed(2)} | المحصل: ${totalColl.toStringAsFixed(2)} د.أ',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _manifestItems.length,
                          itemBuilder: (context, index) {
                            var item = _manifestItems[index];
                            int id = item['id'];
                            bool selected = _selectedIds.contains(id);
                            String status = item['status'] ?? 'قيد التوصيل';
                            String phone = _formatPhone(item['mobile']);

                            return Card(
                              color: selected ? Colors.blue.shade50 : Colors.white,
                              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              child: ListTile(
                                leading: Checkbox(
                                  value: selected,
                                  onChanged: (val) => setState(() => val == true ? _selectedIds.add(id) : _selectedIds.remove(id)),
                                ),
                                title: Text(
                                  'شحنة: ${item['orderId'] ?? '-'} | المحصل: ${_calculateCollected(item).toStringAsFixed(2)} د.أ',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: () => _callPhone(phone),
                                      child: Text('هاتف: $phone', style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                                    ),
                                    Text('العنوان: ${item['address'] ?? '-'}', style: const TextStyle(fontSize: 12)),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        DropdownButton<String>(
                                          value: _paymentMethods.contains(item['paymentMethod']) ? item['paymentMethod'] : 'كاش',
                                          items: _paymentMethods.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                                          onChanged: (val) async {
                                            if (val != null) {
                                              await DatabaseHelper.instance.updateManifestItem(id, {'paymentMethod': val});
                                              _loadManifestData();
                                            }
                                          },
                                        ),
                                        DropdownButton<String>(
                                          value: _statusOptions.contains(status) ? status : 'قيد التوصيل',
                                          items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                          onChanged: (val) => val != null ? _updateItem(item, val) : null,
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
                    ],
                  ),
      ),
    );
  }
}