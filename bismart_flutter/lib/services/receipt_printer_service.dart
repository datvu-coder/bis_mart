import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sales_report.dart';

/// Sends a formatted receipt to a WiFi ESC/POS thermal printer over a raw
/// TCP socket (the standard "port 9100 raw" protocol nearly all network
/// receipt printers support — no vendor SDK/plugin needed).
class ReceiptPrinterService {
  ReceiptPrinterService._();

  static const _prefsIpKey = 'printer_ip';
  static const _prefsPortKey = 'printer_port';
  static const _prefsWidthKey = 'printer_width';

  static const List<int> _init = [0x1B, 0x40]; // ESC @  (initialize)
  static const List<int> _alignCenter = [0x1B, 0x61, 0x01];
  static const List<int> _alignLeft = [0x1B, 0x61, 0x00];
  static const List<int> _boldOn = [0x1B, 0x45, 0x01];
  static const List<int> _boldOff = [0x1B, 0x45, 0x00];
  static const List<int> _doubleOn = [0x1D, 0x21, 0x11]; // double width+height
  static const List<int> _doubleOff = [0x1D, 0x21, 0x00];
  static const List<int> _cut = [0x1D, 0x56, 0x42, 0x00]; // partial cut + feed

  static Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'ip': prefs.getString(_prefsIpKey) ?? '',
      'port': prefs.getInt(_prefsPortKey) ?? 9100,
      'width': prefs.getInt(_prefsWidthKey) ?? 32,
    };
  }

  static Future<void> saveSettings({required String ip, required int port, required int width}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsIpKey, ip);
    await prefs.setInt(_prefsPortKey, port);
    await prefs.setInt(_prefsWidthKey, width);
  }

  static Future<bool> get isConfigured async {
    final s = await loadSettings();
    return (s['ip'] as String).isNotEmpty;
  }

  static Future<void> testConnection({required String ip, required int port}) async {
    final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
    await socket.close();
  }

  static String _padRow(String left, String right, int width) {
    final space = width - left.length - right.length;
    if (space <= 0) return '$left $right';
    return left + ' ' * space + right;
  }

  static List<int> _buildReceiptBytes({
    required String storeName,
    required DateTime date,
    required String pgName,
    required List<SaleItem> items,
    required double subtotal,
    required String paymentMethod,
    int width = 32,
  }) {
    final bytes = <int>[];
    bytes.addAll(_init);
    bytes.addAll(_alignCenter);
    bytes.addAll(_doubleOn);
    bytes.addAll(utf8.encode("$storeName\n"));
    bytes.addAll(_doubleOff);
    bytes.addAll(utf8.encode("HOA DON BAN HANG\n"));
    bytes.addAll(_alignLeft);
    bytes.addAll(utf8.encode('-' * width + '\n'));
    bytes.addAll(utf8.encode(
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}\n'));
    bytes.addAll(utf8.encode('NV: $pgName\n'));
    bytes.addAll(utf8.encode('-' * width + '\n'));
    for (final item in items) {
      bytes.addAll(utf8.encode('${item.productName}\n'));
      final qtyPrice = '${item.quantity} x ${item.unitPrice.toStringAsFixed(0)}';
      final total = item.total.toStringAsFixed(0);
      bytes.addAll(utf8.encode('${_padRow(qtyPrice, total, width)}\n'));
    }
    bytes.addAll(utf8.encode('-' * width + '\n'));
    bytes.addAll(_boldOn);
    bytes.addAll(utf8.encode('${_padRow('TONG CONG', subtotal.toStringAsFixed(0), width)}\n'));
    bytes.addAll(_boldOff);
    bytes.addAll(utf8.encode(
        'Thanh toan: ${paymentMethod == 'transfer' ? 'Chuyen khoan' : 'Tien mat'}\n'));
    bytes.addAll(utf8.encode('-' * width + '\n'));
    bytes.addAll(_alignCenter);
    bytes.addAll(utf8.encode("Cam on quy khach!\n\n\n"));
    bytes.addAll(_cut);
    return bytes;
  }

  /// Prints using the printer configured via [saveSettings]. Throws if no
  /// printer is configured or the connection fails.
  static Future<void> printReceipt({
    required String storeName,
    required DateTime date,
    required String pgName,
    required List<SaleItem> items,
    required double subtotal,
    required String paymentMethod,
  }) async {
    final settings = await loadSettings();
    final ip = settings['ip'] as String;
    if (ip.isEmpty) {
      throw StateError('Chưa cấu hình máy in. Vào Cài đặt máy in để kết nối.');
    }
    final port = settings['port'] as int;
    final width = settings['width'] as int;
    final bytes = _buildReceiptBytes(
      storeName: storeName,
      date: date,
      pgName: pgName,
      items: items,
      subtotal: subtotal,
      paymentMethod: paymentMethod,
      width: width,
    );
    final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
    try {
      socket.add(bytes);
      await socket.flush();
    } finally {
      await socket.close();
    }
  }
}
