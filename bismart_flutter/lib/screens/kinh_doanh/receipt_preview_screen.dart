import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/sales_report.dart';
import '../../services/receipt_printer_service.dart';

/// Shows what the printed receipt will look like before actually sending it
/// to the WiFi printer — a plain-text, monospace, paper-like preview that
/// mirrors the real ESC/POS layout built in ReceiptPrinterService.
class ReceiptPreviewScreen extends StatefulWidget {
  final String storeName;
  final DateTime date;
  final String pgName;
  final List<SaleItem> items;
  final double subtotal;
  final String paymentMethod;

  const ReceiptPreviewScreen({
    super.key,
    required this.storeName,
    required this.date,
    required this.pgName,
    required this.items,
    required this.subtotal,
    required this.paymentMethod,
  });

  @override
  State<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends State<ReceiptPreviewScreen> {
  bool _printing = false;

  Future<void> _print() async {
    setState(() => _printing = true);
    try {
      await ReceiptPrinterService.printReceipt(
        storeName: widget.storeName,
        date: widget.date,
        pgName: widget.pgName,
        items: widget.items,
        subtotal: widget.subtotal,
        paymentMethod: widget.paymentMethod,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi lệnh in hoá đơn'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('In hoá đơn thất bại: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  String _padRow(String left, String right, int width) {
    final space = width - left.length - right.length;
    if (space <= 0) return '$left $right';
    return left + ' ' * space + right;
  }

  @override
  Widget build(BuildContext context) {
    const width = 32;
    final divider = '-' * width;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Xem trước hoá đơn')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Container(
                  width: 340,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    boxShadow: [
                      BoxShadow(color: AppColors.shadowMedium, blurRadius: 16, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      color: AppColors.textDark,
                      height: 1.5,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(widget.storeName, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        const Text('HOA DON BAN HANG', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(divider),
                        Text(
                          '${widget.date.day.toString().padLeft(2, '0')}/${widget.date.month.toString().padLeft(2, '0')}/${widget.date.year} '
                          '${widget.date.hour.toString().padLeft(2, '0')}:${widget.date.minute.toString().padLeft(2, '0')}',
                        ),
                        Text('NV: ${widget.pgName}'),
                        Text(divider),
                        ...widget.items.expand((item) => [
                              Text(item.productName),
                              Text(_padRow(
                                '${item.quantity} x ${item.unitPrice.toStringAsFixed(0)}',
                                item.total.toStringAsFixed(0),
                                width,
                              )),
                            ]),
                        Text(divider),
                        Text(
                          _padRow('TONG CONG', widget.subtotal.toStringAsFixed(0), width),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text('Thanh toan: ${widget.paymentMethod == 'transfer' ? 'Chuyen khoan' : 'Tien mat'}'),
                        Text(divider),
                        const Text('Cam on quy khach!', textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Đóng'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _printing ? null : _print,
                      icon: _printing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                            )
                          : const Icon(Icons.print_rounded, size: 18),
                      label: Text(_printing ? 'Đang in...' : 'In hoá đơn'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
