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
  final Set<int> _selectedIds = {}; // لتخزين معرفات الشحنات المحددة
  bool _isLoading = true;

  final List<String> _statusOptions = [
    'قيد التوصيل',
    'تم التسليم',
    'مؤجل',
    'مرتجع / رفض الاستلام (تم دفع التوصيل)',
    'مرتجع / رفض الاستلام (رفض دفع التوصيل)',
  ];

  final List<String> _paymentMethods = [
    'كاش',
    'كليك',
  ];

  @override
  void initState() {
    super.initState();
    _loadManifestData();
  }

  // تحميل الشحنات مع إعادة الترتيب تلقائياً (قيد التوصيل أولاً ثم بقية الحالات)
  Future<void> _loadManifestData() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getManifestItems();
    if (!mounted) return;

    List<Map<String, dynamic>> sortedList = List<Map<String, dynamic>>.from(data);
    sortedList.sort((a, b) {
      bool aIsPending = (a['status']?.toString() ?? 'قيد التوصيل') == 'قيد التوصيل';
      bool bIsPending = (b['status']?.toString() ?? 'قيد التوصيل') == 'قيد التوصيل';

      if (aIsPending && !bIsPending) return -1;
      if (!aIsPending && bIsPending) return 1;
      return (b['id'] ?? 0).compareTo(a['id'] ?? 0);
    });

    setState(() {
      _manifestItems = sortedList;
      _isLoading = false;
    });
  }

  // إرسال الشحنات المحددة إلى سلة المحذوفات بعد التأكيد
  Future<void> _confirmAndMoveToRecycleBin() async {
    if (_selectedIds.isEmpty) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت تأكد من نقل ${_selectedIds.length} شحنة إلى سلة المحذوفات؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
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
      setState(() {
        _selectedIds.clear();
      });
      await _loadManifestData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم نقل الشحنات المحددة بنجاح')),
        );
      }
    }
  }

  String _formatPhoneNumber(String? phone) {
    if (phone == null || phone.trim().isEmpty) return 'غير متوفر';
    String cleaned = phone.trim().replaceAll(RegExp(r'\s+'), '');
    if (cleaned.length == 9 && !cleaned.startsWith('0')) {
      return '0$cleaned';
    }
    return cleaned;
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final formattedPhone = _formatPhoneNumber(phoneNumber);
    if (formattedPhone == 'غير متوفر') return;

    final Uri launchUri = Uri(
      scheme: 'tel',
      path: formattedPhone,
    );

    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri, mode: LaunchMode.platformDefault);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر التوجيه للاتصال بالرقم $formattedPhone')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الاتصال بالرقم $formattedPhone')),
      );
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  double _calculateCollectedAmount(Map<String, dynamic> item) {
    String status = item['status']?.toString() ?? 'قيد التوصيل';
    double collectionAmount = _parseDouble(item['collectionAmount']);
    double deliveryFee = _parseDouble(item['deliveryFee']);

    if (item['customCollectedAmount'] != null) {
      return _parseDouble(item['customCollectedAmount']);
    }

    if (status == 'تم التسليم') {
      return collectionAmount;
    } else if (status == 'مرتجع / رفض الاستلام (تم دفع التوصيل)') {
      return deliveryFee;
    } else if (status == 'مرتجع / رفض الاستلام (رفض دفع التوصيل)') {
      return 0.0;
    }
    return 0.0;
  }

  double _calculateTotalRequiredAmount() {
    return _manifestItems.fold(
      0.0,
      (sum, item) => sum + _parseDouble(item['collectionAmount']),
    );
  }

  int _calculateRemainingItemsCount() {
    return _manifestItems.where((item) {
      String status = item['status']?.toString() ?? 'قيد التوصيل';
      return status == 'قيد التوصيل';
    }).length;
  }

  Future<void> _showCustomAmountDialog(Map<String, dynamic> item, String newStatus) async {
    final double defaultVal = item['customCollectedAmount'] != null
        ? _parseDouble(item['customCollectedAmount'])
        : (newStatus.contains('تم دفع التوصيل') ? _parseDouble(item['deliveryFee']) : 0.0);

    final TextEditingController controller = TextEditingController(
      text: defaultVal.toStringAsFixed(2),
    );

    double? customAmount;
    try {
      customAmount = await showDialog<double>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('المبلغ المحصل من العميل'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الحالة: $newStatus', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'أدخل المبلغ المحصل فعلياً (د.أ)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, null),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    double? value = double.tryParse(controller.text);
                    Navigator.pop(dialogContext, value ?? 0.0);
                  },
                  child: const Text('حفظ'),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      controller.dispose();
    }

    if (customAmount != null) {
      int id = item['id'];
      await DatabaseHelper.instance.updateManifestItem(id, {
        'status': newStatus,
        'customCollectedAmount': customAmount,
      });
      await _loadManifestData();
    }
  }

  Future<void> _updateItemStatus(Map<String, dynamic> item, String newStatus) async {
    if (newStatus.contains('رفض الاستلام') || newStatus.contains('مرتجع')) {
      await _showCustomAmountDialog(item, newStatus);
    } else {
      int id = item['id'];
      await DatabaseHelper.instance.updateManifestItem(id, {
        'status': newStatus,
        'customCollectedAmount': null,
      });
      await _loadManifestData();
    }
  }

  Future<void> _updatePaymentMethod(Map<String, dynamic> item, String newMethod) async {
    int id = item['id'];
    await DatabaseHelper.instance.updateManifestItem(id, {'paymentMethod': newMethod});
    await _loadManifestData();
  }

  // تصدير PDF يدعم الصفحات المتعددة تلقائياً
  Future<void> _printOrSharePdf() async {
    try {
      final pdf = pw.Document();
      final arabicFont = await PdfGoogleFonts.cairoRegular();
      final arabicBoldFont = await PdfGoogleFonts.cairoBold();

      final totalRequired = _calculateTotalRequiredAmount();
      final totalCollected = _manifestItems.fold(
        0.0,
        (sum, item) => sum + _calculateCollectedAmount(item),
      );
      final remainingCount = _calculateRemainingItemsCount();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          header: (pw.Context context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'كشف التوصيل المالي (Manifest)',
                    style: pw.TextStyle(
                      font: arabicBoldFont,
                      fontSize: 16,
                    ),
                  ),
                  pw.Text(
                    'الإجمالي: ${_manifestItems.length} | المتبقي: $remainingCount',
                    style: pw.TextStyle(font: arabicFont, fontSize: 10),
                  ),
                ],
              ),
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(top: 10),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'المطلوب: ${totalRequired.toStringAsFixed(2)} د.أ | المحصل: ${totalCollected.toStringAsFixed(2)} د.أ',
                    style: pw.TextStyle(font: arabicBoldFont, fontSize: 10),
                  ),
                  pw.Text(
                    'صفحة ${context.pageNumber} من ${context.pagesCount}',
                    style: pw.TextStyle(font: arabicFont, fontSize: 9),
                  ),
                ],
              ),
            );
          },
          build: (pw.Context context) {
            return [
              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey400),
                headerStyle: pw.TextStyle(
                  font: arabicBoldFont,
                  color: PdfColors.white,
                  fontSize: 9,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellStyle: pw.TextStyle(font: arabicFont, fontSize: 8),
                cellAlignment: pw.Alignment.centerRight,
                columnWidths: {
                  0: const pw.FixedColumnWidth(20),
                  1: const pw.FixedColumnWidth(55),
                  2: const pw.FixedColumnWidth(65),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FixedColumnWidth(45),
                  5: const pw.FixedColumnWidth(55),
                  6: const pw.FlexColumnWidth(1.5),
                },
                headers: <String>['م', 'رقم الشحنة', 'الهاتف', 'العنوان', 'الدفع', 'المحصل', 'الحالة'],
                data: _manifestItems.asMap().entries.map((entry) {
                  int idx = entry.key + 1;
                  var item = entry.value;
                  double collected = _calculateCollectedAmount(item);
                  return [
                    '$idx',
                    item['orderId']?.toString() ?? '-',
                    _formatPhoneNumber(item['mobile']?.toString()),
                    item['address']?.toString() ?? '-',
                    item['paymentMethod']?.toString() ?? 'كاش',
                    '${collected.toStringAsFixed(2)} د.أ',
                    item['status']?.toString() ?? 'قيد التوصيل',
                  ];
                }).toList(),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحميل الخطوط أو طباعة الملف: $e')),
      );
    }
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.blue;
    if (status.contains('تم التسليم')) return Colors.green.shade700;
    if (status.contains('مؤجل')) return Colors.orange.shade800;
    if (status.contains('مرتجع') || status.contains('رفض')) return Colors.red.shade700;
    return Colors.blue.shade700;
  }

  @override
  Widget build(BuildContext context) {
    double totalRequiredAmount = _calculateTotalRequiredAmount();
    double totalCollectedAmount = _manifestItems.fold(
      0.0,
      (sum, item) => sum + _calculateCollectedAmount(item),
    );
    int remainingItemsCount = _calculateRemainingItemsCount();
    bool isSelectionMode = _selectedIds.isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isSelectionMode
              ? 'تم تحديد ${_selectedIds.length}'
              : 'كشف التوصيل المالي (Manifest)'),
          backgroundColor: Colors.blueGrey.shade800,
          foregroundColor: Colors.white,
          actions: [
            if (isSelectionMode)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: _confirmAndMoveToRecycleBin,
                tooltip: 'نقل إلى سلة المحذوفات',
              )
            else
              IconButton(
                icon: const Icon(Icons.print),
                onPressed: _manifestItems.isEmpty ? null : _printOrSharePdf,
                tooltip: 'طباعة / تصدير PDF',
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _manifestItems.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد شحنات مضافة حالياً.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          border: Border(
                            bottom: BorderSide(color: Colors.blueGrey.shade200),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 14, color: Colors.black),
                                    children: [
                                      TextSpan(
                                        text: 'الكلي: ${_manifestItems.length}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const TextSpan(text: '  |  '),
                                      TextSpan(
                                        text: 'المتبقي للتوصيل: $remainingItemsCount',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: remainingItemsCount > 0 ? Colors.orange.shade900 : Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'المطلوب: ${totalRequiredAmount.toStringAsFixed(2)} د.أ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.blueGrey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'إجمالي التحصيل:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  'المحصل فعلياً: ${totalCollectedAmount.toStringAsFixed(2)} د.أ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _manifestItems.length,
                          itemBuilder: (context, index) {
                            final item = _manifestItems[index];
                            final int itemId = item['id'];
                            final bool isSelected = _selectedIds.contains(itemId);
                            final currentStatus = item['status']?.toString() ?? 'قيد التوصيل';
                            final currentPayment = item['paymentMethod']?.toString() ?? 'كاش';
                            final collectedAmount = _calculateCollectedAmount(item);
                            final formattedPhone = _formatPhoneNumber(item['mobile']?.toString());
                            final bool isPending = currentStatus == 'قيد التوصيل';

                            return Card(
                              elevation: isPending ? 2 : 1,
                              color: isSelected
                                  ? Colors.blue.shade50
                                  : isPending
                                      ? Colors.white
                                      : Colors.grey.shade100,
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: isSelected
                                    ? const BorderSide(color: Colors.blue, width: 2)
                                    : BorderSide.none,
                              ),
                              child: InkWell(
                                onLongPress: () {
                                  setState(() {
                                    _selectedIds.add(itemId);
                                  });
                                },
                                onTap: () {
                                  if (isSelectionMode) {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedIds.remove(itemId);
                                      } else {
                                        _selectedIds.add(itemId);
                                      }
                                    });
                                  }
                                },
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
                                              if (isSelectionMode)
                                                Checkbox(
                                                  value: isSelected,
                                                  onChanged: (bool? val) {
                                                    setState(() {
                                                      if (val == true) {
                                                        _selectedIds.add(itemId);
                                                      } else {
                                                        _selectedIds.remove(itemId);
                                                      }
                                                    });
                                                  },
                                                )
                                              else
                                                CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor: Colors.blueGrey.shade700,
                                                  child: Text(
                                                    '${index + 1}',
                                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                                  ),
                                                ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'شحنة رقم: ${item['orderId'] ?? 'غير محدد'}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    'المحصل: ${collectedAmount.toStringAsFixed(2)} د.أ',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.green,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                  if (currentStatus.contains('مرتجع') || currentStatus.contains('رفض'))
                                                    IconButton(
                                                      icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                                                      onPressed: () => _showCustomAmountDialog(item, currentStatus),
                                                      tooltip: 'تعديل المبلغ المحصل',
                                                    ),
                                                ],
                                              ),
                                              Text(
                                                'المطلوب: ${_parseDouble(item['collectionAmount']).toStringAsFixed(2)} د.أ',
                                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 16),
                                      InkWell(
                                        onTap: () => _makePhoneCall(formattedPhone),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.phone, color: Colors.green, size: 20),
                                            const SizedBox(width: 6),
                                            Text(
                                              'الهاتف: $formattedPhone',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                                decoration: TextDecoration.underline,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text('📍 العنوان: ${item['address'] ?? 'غير محدد'}'),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Text('الدفع: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              DropdownButton<String>(
                                                value: _paymentMethods.contains(currentPayment) ? currentPayment : 'كاش',
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple, fontSize: 13),
                                                underline: Container(),
                                                items: _paymentMethods.map((String value) {
                                                  return DropdownMenuItem<String>(
                                                    value: value,
                                                    child: Text(value),
                                                  );
                                                }).toList(),
                                                onChanged: (String? newValue) {
                                                  if (newValue != null && item['id'] != null) {
                                                    _updatePaymentMethod(item, newValue);
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              const Text('الحالة: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              DropdownButton<String>(
                                                value: _statusOptions.contains(currentStatus) ? currentStatus : 'قيد التوصيل',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: _getStatusColor(currentStatus),
                                                  fontSize: 13,
                                                ),
                                                underline: Container(),
                                                items: _statusOptions.map((String value) {
                                                  return DropdownMenuItem<String>(
                                                    value: value,
                                                    child: Text(value, style: TextStyle(color: _getStatusColor(value))),
                                                  );
                                                }).toList(),
                                                onChanged: (String? newValue) {
                                                  if (newValue != null && item['id'] != null) {
                                                    _updateItemStatus(item, newValue);
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
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
}