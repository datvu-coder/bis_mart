import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
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
  final double discountAmount;
  final String? customerName;
  final String? customerPhone;

  const ReceiptPreviewScreen({
    super.key,
    required this.storeName,
    required this.date,
    required this.pgName,
    required this.items,
    required this.subtotal,
    required this.paymentMethod,
    this.discountAmount = 0,
    this.customerName,
    this.customerPhone,
  });

  @override
  State<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends State<ReceiptPreviewScreen> {
  bool _printing = false;
  bool _sharing = false;

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
        discountAmount: widget.discountAmount,
        customerName: widget.customerName,
        customerPhone: widget.customerPhone,
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

  /// Plain-text version of the receipt — reused both as the content laid
  /// out in the shared PDF and previously for the clipboard fallback, so
  /// staff can send it via Zalo/SMS/email when no WiFi printer is
  /// configured, instead of being stuck with only "In hoá đơn".
  String _buildReceiptText() {
    const width = 32;
    final divider = '-' * width;
    final buffer = StringBuffer();
    buffer.writeln(widget.storeName);
    buffer.writeln('HOA DON BAN HANG');
    buffer.writeln(divider);
    buffer.writeln(
        '${widget.date.day.toString().padLeft(2, '0')}/${widget.date.month.toString().padLeft(2, '0')}/${widget.date.year} '
        '${widget.date.hour.toString().padLeft(2, '0')}:${widget.date.minute.toString().padLeft(2, '0')}');
    buffer.writeln('NV: ${widget.pgName}');
    if ((widget.customerName ?? '').isNotEmpty) buffer.writeln('KH: ${widget.customerName}');
    if ((widget.customerPhone ?? '').isNotEmpty) buffer.writeln('SDT: ${widget.customerPhone}');
    buffer.writeln(divider);
    for (final item in widget.items) {
      buffer.writeln(item.productName);
      buffer.writeln(_padRow(
        '${item.quantity} x ${item.unitPrice.toStringAsFixed(0)}',
        item.total.toStringAsFixed(0),
        width,
      ));
    }
    buffer.writeln(divider);
    if (widget.discountAmount > 0) {
      buffer.writeln(_padRow(
        'Tam tinh',
        widget.items.fold<double>(0, (s, i) => s + i.total).toStringAsFixed(0),
        width,
      ));
      buffer.writeln(_padRow('Giam gia', '-${widget.discountAmount.toStringAsFixed(0)}', width));
    }
    buffer.writeln(_padRow('TONG CONG', widget.subtotal.toStringAsFixed(0), width));
    buffer.writeln('Thanh toan: ${widget.paymentMethod == 'transfer' ? 'Chuyen khoan' : 'Tien mat'}');
    buffer.writeln(divider);
    buffer.write('Cam on quy khach!');
    return buffer.toString();
  }

  Future<void> _shareReceipt() async {
    setState(() => _sharing = true);
    try {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          build: (context) => pw.Text(
            _buildReceiptText(),
            style: pw.TextStyle(font: pw.Font.courier(), fontSize: 9),
          ),
        ),
      );
      final bytes = await doc.save();
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/hoa_don_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Hoá đơn bán hàng - ${widget.storeName}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chia sẻ hoá đơn thất bại: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
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
                        if ((widget.customerName ?? '').isNotEmpty) Text('KH: ${widget.customerName}'),
                        if ((widget.customerPhone ?? '').isNotEmpty) Text('SDT: ${widget.customerPhone}'),
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
                        if (widget.discountAmount > 0) ...[
                          Text(_padRow(
                            'Tam tinh',
                            widget.items.fold<double>(0, (s, i) => s + i.total).toStringAsFixed(0),
                            width,
                          )),
                          Text(_padRow('Giam gia', '-${widget.discountAmount.toStringAsFixed(0)}', width)),
                        ],
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Đóng'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _sharing ? null : _shareReceipt,
                          icon: _sharing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.share_rounded, size: 16),
                          label: const Text('Chia sẻ'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
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
