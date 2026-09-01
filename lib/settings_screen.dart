import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // تمت الإضافة لدعم تقييد الأرقام
import 'security_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _isPinSet = false;
  bool _isLoading = true;

  bool _hideOldPin = true;
  bool _hideNewPin = true;
  bool _hideConfirmPin = true;

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
  }

  @override
  void dispose() {
    _oldPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _checkPinStatus() async {
    bool isSet = await SecurityService.isPinSet();
    if (!mounted) return;
    setState(() {
      _isPinSet = isSet;
      _isLoading = false;
    });
  }

  Future<void> _saveOrUpdatePin() async {
    FocusScope.of(context).unfocus();

    String oldPin = _oldPinController.text.trim();
    String newPin = _newPinController.text.trim();
    String confirmPin = _confirmPinController.text.trim();

    if (newPin.isEmpty || newPin.length < 4) {
      _showMessage('كلمة المرور الجديدة يجب أن تكون 4 أرقام على الأقل');
      return;
    }

    if (newPin != confirmPin) {
      _showMessage('كلمة المرور الجديدة غير مطابقة للتأكيد');
      return;
    }

    if (_isPinSet) {
      bool isOldValid = await SecurityService.verifyPin(oldPin);
      if (!isOldValid) {
        _showMessage('كلمة المرور القديمة غير صحيحة!');
        return;
      }
    }

    await SecurityService.setPin(newPin);
    if (!mounted) return;

    _showMessage('تم حفظ كلمة المرور بنجاح');

    _oldPinController.clear();
    _newPinController.clear();
    _confirmPinController.clear();

    _checkPinStatus();
  }

  Future<void> _removePin() async {
    FocusScope.of(context).unfocus();
    String oldPin = _oldPinController.text.trim();
    
    if (_isPinSet && oldPin.isEmpty) {
      _showMessage('يرجى إدخال كلمة المرور القديمة في حقلها المخصص أولاً');
      return;
    }

    if (_isPinSet) {
      bool isOldValid = await SecurityService.verifyPin(oldPin);
      if (!isOldValid) {
        _showMessage('كلمة المرور القديمة غير صحيحة!');
        return;
      }
    }

    if (!mounted) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إلغاء كلمة المرور'),
          content: const Text('هل أنت متأكد من رغبتك في إلغاء رمز الأمان؟ سيتمكن أي شخص من فتح التطبيق.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('إزالة رمز الأمان', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await SecurityService.clearPin();
      if (!mounted) return;

      _oldPinController.clear();
      _newPinController.clear();
      _confirmPinController.clear();

      _showMessage('تمت إزالة كلمة المرور بنجاح');
      _checkPinStatus();
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إعدادات الأمان'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView(
                  children: [
                    Text(
                      _isPinSet ? 'تغيير كلمة المرور' : 'إنشاء كلمة مرور جديدة',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    if (_isPinSet) ...[
                      TextField(
                        controller: _oldPinController,
                        obscureText: _hideOldPin,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور القديمة',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_clock),
                          suffixIcon: IconButton(
                            icon: Icon(_hideOldPin ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _hideOldPin = !_hideOldPin),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    TextField(
                      controller: _newPinController,
                      obscureText: _hideNewPin,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الجديدة',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_hideNewPin ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _hideNewPin = !_hideNewPin),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _confirmPinController,
                      obscureText: _hideConfirmPin,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'تأكيد كلمة المرور الجديدة',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_reset),
                        suffixIcon: IconButton(
                          icon: Icon(_hideConfirmPin ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _hideConfirmPin = !_hideConfirmPin),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: _saveOrUpdatePin,
                      icon: const Icon(Icons.save),
                      label: Text(_isPinSet ? 'تحديث كلمة المرور' : 'حفظ كلمة المرور'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),

                    if (_isPinSet) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _removePin,
                        icon: const Icon(Icons.no_encryption, color: Colors.red),
                        label: const Text('إلغاء حماية كلمة المرور', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}