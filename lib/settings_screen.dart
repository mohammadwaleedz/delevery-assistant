import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
  }

  Future<void> _checkPinStatus() async {
    bool isSet = await SecurityService.isPinSet();
    setState(() {
      _isPinSet = isSet;
      _isLoading = false;
    });
  }

  Future<void> _saveOrUpdatePin() async {
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

    // إذا كانت كلمة المرور معينة مسبقاً، يلزم التحقق من القديمة
    if (_isPinSet) {
      bool isOldValid = await SecurityService.verifyPin(oldPin);
      if (!isOldValid) {
        _showMessage('كلمة المرور القديمة غير صحيحة!');
        return;
      }
    }

    // حفظ كلمة المرور الجديدة
    await SecurityService.setPin(newPin);
    _showMessage('تم حفظ كلمة المرور بنجاح');

    _oldPinController.clear();
    _newPinController.clear();
    _confirmPinController.clear();

    _checkPinStatus();
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور القديمة',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_clock),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextField(
                    controller: _newPinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _confirmPinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'تأكيد كلمة المرور الجديدة',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_reset),
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
                ],
              ),
            ),
    );
  }
}