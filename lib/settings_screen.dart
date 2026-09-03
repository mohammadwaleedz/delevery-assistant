import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
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
    final isSet = await SecurityService.isPinSet();
    if (!mounted) return;
    setState(() {
      _isPinSet = isSet;
      _isLoading = false;
    });
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  void _clearControllers() {
    _oldPinController.clear();
    _newPinController.clear();
    _confirmPinController.clear();
  }

  Future<bool> _verifyOldPinIfSet() async {
    if (!_isPinSet) return true;
    final oldPin = _oldPinController.text.trim();
    if (oldPin.isEmpty) {
      _showMessage('يرجى إدخال كلمة المرور القديمة في حقلها المخصص أولاً');
      return false;
    }
    final isValid = await SecurityService.verifyPin(oldPin);
    if (!isValid) {
      _showMessage('كلمة المرور القديمة غير صحيحة!');
      return false;
    }
    return true;
  }

  Future<void> _saveOrUpdatePin() async {
    FocusScope.of(context).unfocus();

    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (newPin.isEmpty || newPin.length < 4) {
      _showMessage('كلمة المرور الجديدة يجب أن تكون 4 أرقام على الأقل');
      return;
    }

    if (newPin != confirmPin) {
      _showMessage('كلمة المرور الجديدة غير مطابقة للتأكيد');
      return;
    }

    if (!await _verifyOldPinIfSet()) return;

    await SecurityService.setPin(newPin);
    if (!mounted) return;

    _showMessage('تم حفظ كلمة المرور بنجاح');
    _clearControllers();
    _checkPinStatus();
  }

  Future<void> _removePin() async {
    FocusScope.of(context).unfocus();

    if (!await _verifyOldPinIfSet()) return;
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
    );

    if (confirm == true) {
      await SecurityService.clearPin();
      if (!mounted) return;

      _clearControllers();
      _showMessage('تمت إزالة كلمة المرور بنجاح');
      _checkPinStatus();
    }
  }

  // دالة مساعدة لإنشاء حقول الإدخال لمنع تكرار الأكواد (DRY Principle)
  Widget _buildPinTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(prefixIcon),
        suffixIcon: IconButton(
          icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggleVisibility,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الأمان'),
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
                    _buildPinTextField(
                      controller: _oldPinController,
                      labelText: 'كلمة المرور القديمة',
                      prefixIcon: Icons.lock_clock,
                      obscureText: _hideOldPin,
                      onToggleVisibility: () => setState(() => _hideOldPin = !_hideOldPin),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _buildPinTextField(
                    controller: _newPinController,
                    labelText: 'كلمة المرور الجديدة',
                    prefixIcon: Icons.lock_outline,
                    obscureText: _hideNewPin,
                    onToggleVisibility: () => setState(() => _hideNewPin = !_hideNewPin),
                  ),
                  const SizedBox(height: 12),
                  _buildPinTextField(
                    controller: _confirmPinController,
                    labelText: 'تأكيد كلمة المرور الجديدة',
                    prefixIcon: Icons.lock_reset,
                    obscureText: _hideConfirmPin,
                    onToggleVisibility: () => setState(() => _hideConfirmPin = !_hideConfirmPin),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _saveOrUpdatePin,
                    icon: const Icon(Icons.save),
                    label: Text(_isPinSet ? 'تحديث كلمة المرور' : 'حفظ كلمة المرور'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
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
    );
  }
}