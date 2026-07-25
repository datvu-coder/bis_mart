import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/permission_provider.dart';
import '../../services/api_service.dart';

/// Admin-only screen to configure connection details for a licensed
/// e-invoice provider (MISA meInvoice, VNPT, Viettel, BKAV...).
///
/// This app does not and cannot connect directly to the tax authority —
/// only a licensed provider with a digital-signature contract has that
/// certified relationship with Tổng cục Thuế. This screen just stores the
/// provider's connection details and offers a basic reachability check.
class EinvoiceSettingsScreen extends StatefulWidget {
  const EinvoiceSettingsScreen({super.key});

  @override
  State<EinvoiceSettingsScreen> createState() => _EinvoiceSettingsScreenState();
}

class _EinvoiceSettingsScreenState extends State<EinvoiceSettingsScreen> {
  static const _providers = {
    'misa': 'MISA meInvoice',
    'vnpt': 'VNPT Invoice',
    'viettel': 'Viettel S-Invoice',
    'bkav': 'BKAV eHoadon',
    'other': 'Khác',
  };

  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  String? _error;

  String _provider = 'misa';
  final _taxCodeCtrl = TextEditingController();
  final _apiBaseUrlCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  String? _apiKeyMasked;
  bool _isActive = false;
  bool _configured = false;

  @override
  void initState() {
    super.initState();
    if (context.read<PermissionProvider>().isAdmin) {
      _load();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _taxCodeCtrl.dispose();
    _apiBaseUrlCtrl.dispose();
    _usernameCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService().getEinvoiceSettings();
      _provider = (data['provider'] as String?) ?? 'misa';
      _taxCodeCtrl.text = (data['taxCode'] as String?) ?? '';
      _apiBaseUrlCtrl.text = (data['apiBaseUrl'] as String?) ?? '';
      _usernameCtrl.text = (data['username'] as String?) ?? '';
      _apiKeyMasked = data['apiKeyMasked'] as String?;
      _isActive = data['isActive'] as bool? ?? false;
      _configured = data['configured'] as bool? ?? false;
    } catch (_) {
      _error = 'Không thể tải cấu hình';
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService().updateEinvoiceSettings({
        'provider': _provider,
        'taxCode': _taxCodeCtrl.text.trim(),
        'apiBaseUrl': _apiBaseUrlCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'apiKey': _apiKeyCtrl.text.trim(),
        'isActive': _isActive,
      });
      if (!mounted) return;
      _apiKeyCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu cấu hình'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lưu thất bại: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    try {
      final result = await ApiService().testEinvoiceConnection();
      if (!mounted) return;
      final ok = result['ok'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Kết nối thành công (mã trạng thái ${result['statusCode']})'
              : 'Kết nối thất bại: ${result['error']}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ok ? AppColors.success : AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kiểm tra thất bại: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
    if (!mounted) return;
    setState(() => _testing = false);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<PermissionProvider>().isAdmin;
    if (!isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Cài đặt hóa đơn điện tử')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 48, color: AppColors.textHint),
              const SizedBox(height: 12),
              Text('Bạn không có quyền truy cập trang này.', style: AppTextStyles.bodyText),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Cài đặt hóa đơn điện tử')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDisclaimer(),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppDecorations.card,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _provider,
                          decoration:
                              const InputDecoration(labelText: 'Nhà cung cấp hóa đơn điện tử'),
                          items: _providers.entries
                              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                              .toList(),
                          onChanged: (v) => setState(() => _provider = v ?? 'misa'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _taxCodeCtrl,
                          decoration: const InputDecoration(labelText: 'Mã số thuế công ty'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _apiBaseUrlCtrl,
                          decoration: const InputDecoration(labelText: 'Địa chỉ API (endpoint)'),
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _usernameCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Tên đăng nhập / tài khoản API'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _apiKeyCtrl,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'API Key / Mật khẩu',
                            hintText: _apiKeyMasked != null
                                ? 'Đã lưu: $_apiKeyMasked (để trống nếu không đổi)'
                                : 'Nhập API key',
                          ),
                        ),
                        const SizedBox(height: 4),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Kích hoạt kết nối'),
                          value: _isActive,
                          activeColor: AppColors.primary,
                          onChanged: (v) => setState(() => _isActive = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: (_configured && !_testing) ? _testConnection : null,
                          icon: _testing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.wifi_tethering_rounded, size: 18),
                          label: const Text('Kiểm tra kết nối'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppColors.white))
                              : const Icon(Icons.save_rounded, size: 18),
                          label: const Text('Lưu'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppRadius.row),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'App không kết nối trực tiếp với hệ thống của Tổng cục Thuế. Để xuất hóa đơn '
              'điện tử tự động, công ty cần có hợp đồng với một nhà cung cấp được cấp phép '
              '(MISA, VNPT, Viettel...) và chữ ký số riêng. Nhập thông tin API do nhà cung cấp '
              'đó cấp bên dưới — "Kiểm tra kết nối" chỉ xác minh địa chỉ API có phản hồi, '
              'chưa đảm bảo tương thích đầy đủ với chuẩn dữ liệu của nhà cung cấp.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
