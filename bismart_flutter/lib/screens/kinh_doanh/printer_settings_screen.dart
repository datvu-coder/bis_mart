import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/receipt_printer_service.dart';

/// Configure the WiFi (network) receipt printer used by the Bán hàng POS.
/// Any ESC/POS thermal printer that listens on the standard raw-TCP
/// port (9100 by default) works — no proprietary SDK/plugin required.
class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '9100');
  int _width = 32;
  bool _loading = true;
  bool _testing = false;
  bool _printingTest = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await ReceiptPrinterService.loadSettings();
    if (!mounted) return;
    setState(() {
      _ipCtrl.text = s['ip'] as String;
      _portCtrl.text = (s['port'] as int).toString();
      _width = s['width'] as int;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ip = _ipCtrl.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập địa chỉ IP máy in'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9100;
    await ReceiptPrinterService.saveSettings(ip: ip, port: port, width: _width);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Đã lưu cấu hình máy in'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _testConnection() async {
    final ip = _ipCtrl.text.trim();
    if (ip.isEmpty) return;
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9100;
    setState(() => _testing = true);
    try {
      await ReceiptPrinterService.testConnection(ip: ip, port: port);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Kết nối máy in thành công'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể kết nối: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _printTest() async {
    final ip = _ipCtrl.text.trim();
    if (ip.isEmpty) return;
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9100;
    setState(() => _printingTest = true);
    try {
      await ReceiptPrinterService.printTestPage(ip: ip, port: port, width: _width);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi lệnh in thử'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('In thử thất bại: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _printingTest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Cài đặt máy in')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(AppRadius.row),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.info, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Kết nối máy in hoá đơn qua WiFi cùng mạng với điện thoại. '
                          'Nhập địa chỉ IP của máy in (xem trong menu/tự in trên máy in) và cổng '
                          '(mặc định 9100 với hầu hết máy in nhiệt).',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _ipCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ IP máy in',
                    hintText: 'Ví dụ: 192.168.1.100',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _portCtrl,
                  decoration: const InputDecoration(labelText: 'Cổng (port)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Text('Khổ giấy', style: AppTextStyles.metricLabel),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('58mm'),
                        selected: _width == 32,
                        selectedColor: AppColors.primaryLight,
                        side: BorderSide(color: _width == 32 ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border),
                        onSelected: (_) => setState(() => _width = 32),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('80mm'),
                        selected: _width == 48,
                        selectedColor: AppColors.primaryLight,
                        side: BorderSide(color: _width == 48 ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border),
                        onSelected: (_) => setState(() => _width = 48),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _testing ? null : _testConnection,
                        child: _testing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              )
                            : const Text('Kiểm tra kết nối'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _save,
                        child: const Text('Lưu'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _printingTest ? null : _printTest,
                    icon: _printingTest
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          )
                        : const Icon(Icons.print_rounded, size: 18),
                    label: Text(_printingTest ? 'Đang in...' : 'In thử'),
                  ),
                ),
              ],
            ),
    );
  }
}
