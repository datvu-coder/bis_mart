import 'dart:convert';
import '../models/sales_report.dart';
import '../core/utils/currency_formatter.dart';
import 'export_service_stub.dart'
    if (dart.library.html) 'export_service_web.dart';

class ExportService {
  ExportService._();

  // UTF-8 BOM so Excel/Numbers correctly detects Vietnamese diacritics.
  static const _bom = [0xEF, 0xBB, 0xBF];

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _csvCell(String s) {
    final needsQuote = s.contains(';') || s.contains('"') || s.contains('\n');
    final v = s.replaceAll('"', '""');
    return needsQuote ? '"$v"' : v;
  }

  static String _suffixForRange(String filterType, DateTime? from, DateTime? to) {
    switch (filterType) {
      case 'today':
        return '_hom_nay';
      case 'week':
        return '_tuan_nay';
      case 'month':
        return '_thang_nay';
      case 'custom':
        if (from != null && to != null) {
          return '_${_fmtDate(from).replaceAll('/', '-')}_den_${_fmtDate(to).replaceAll('/', '-')}';
        }
        return '_tuy_chinh';
      default:
        return '';
    }
  }

  static void exportToCsv(
    List<SalesReport> reports, {
    String filterType = 'all',
    DateTime? from,
    DateTime? to,
  }) {
    final buffer = StringBuffer();
    // Use semicolon as separator — preferred in Vietnamese locales where
    // comma is the decimal mark. Excel auto-detects when BOM + ";" is present.
    buffer.writeln('sep=;');
    buffer.writeln([
      'Ngày',
      'Cửa hàng',
      'PG',
      'Mã NV',
      'NU',
      'Sale Out (VNĐ)',
      'Doanh thu (VNĐ)',
      'Sản phẩm',
    ].map(_csvCell).join(';'));

    double totalSaleOut = 0;
    double totalRevenue = 0;
    for (final r in reports) {
      totalSaleOut += r.saleOut;
      totalRevenue += r.revenue;
      final productNames =
          r.products.map((p) => '${p.productName} x${p.quantity}').join(' | ');
      buffer.writeln([
        _fmtDate(r.date),
        r.storeName ?? '',
        r.pgName,
        r.employeeCode ?? '',
        r.nu.toString(),
        r.saleOut.toStringAsFixed(0),
        r.revenue.toStringAsFixed(0),
        productNames,
      ].map((c) => _csvCell(c)).join(';'));
    }

    // Tổng kết
    buffer.writeln([
      'TỔNG CỘNG',
      '',
      '',
      '',
      reports.length.toString(),
      totalSaleOut.toStringAsFixed(0),
      totalRevenue.toStringAsFixed(0),
      '',
    ].map(_csvCell).join(';'));

    final body = buffer.toString();
    final bytes = <int>[..._bom, ...utf8.encode(body)];
    final fileName = 'bao_cao_ban_hang${_suffixForRange(filterType, from, to)}.csv';
    downloadFile(bytes, fileName, 'text/csv;charset=utf-8');
  }

  static void exportToHtmlTable(
    List<SalesReport> reports, {
    String filterType = 'all',
    DateTime? from,
    DateTime? to,
  }) {
    String rangeLabel;
    switch (filterType) {
      case 'today':
        rangeLabel = 'Hôm nay (${_fmtDate(DateTime.now())})';
        break;
      case 'week':
        rangeLabel = 'Tuần này';
        break;
      case 'month':
        final n = DateTime.now();
        rangeLabel = 'Tháng ${n.month}/${n.year}';
        break;
      case 'custom':
        rangeLabel = (from != null && to != null)
            ? 'Từ ${_fmtDate(from)} đến ${_fmtDate(to)}'
            : 'Tuỳ chỉnh';
        break;
      default:
        rangeLabel = 'Tất cả';
    }

    final buffer = StringBuffer();
    buffer.writeln('''
<!DOCTYPE html>
<html lang="vi"><head><meta charset="utf-8">
<title>Báo cáo bán hàng - Bi'S MART</title>
<style>
body { font-family: "Segoe UI", Arial, sans-serif; padding: 24px; color: #222; }
h1 { color: #E05C27; margin-bottom: 4px; }
.meta { color: #666; font-size: 13px; margin-bottom: 16px; }
table { border-collapse: collapse; width: 100%; margin-top: 12px; font-size: 13px; }
th, td { border: 1px solid #e0e0e0; padding: 8px 10px; text-align: left; vertical-align: top; }
th { background: #E05C27; color: white; font-weight: 600; }
tr:nth-child(even) td { background: #fafafa; }
td.num { text-align: right; font-variant-numeric: tabular-nums; }
tfoot td { background: #fff3ec; font-weight: 700; }
.summary { margin-top: 18px; display: flex; gap: 16px; flex-wrap: wrap; }
.summary .card { background: #fff7f1; border: 1px solid #f5d2bd; border-radius: 10px; padding: 10px 14px; min-width: 160px; }
.summary .label { font-size: 12px; color: #666; }
.summary .value { font-size: 16px; font-weight: 700; color: #E05C27; }
@media print { body { padding: 0; } }
</style></head><body>
<h1>Báo cáo bán hàng - Bi'S MART</h1>
<div class="meta">Khoảng thời gian: <b>$rangeLabel</b> · Số báo cáo: <b>${reports.length}</b> · Xuất lúc: ${_fmtDate(DateTime.now())}</div>
<table>
<thead><tr>
<th>STT</th><th>Ngày</th><th>Cửa hàng</th><th>PG</th><th>Mã NV</th><th>NU</th><th>Sale Out</th><th>Doanh thu</th><th>Sản phẩm</th>
</tr></thead>
<tbody>
''');

    double totalSaleOut = 0;
    double totalRevenue = 0;
    int totalNu = 0;
    int idx = 0;
    for (final r in reports) {
      idx += 1;
      totalSaleOut += r.saleOut;
      totalRevenue += r.revenue;
      totalNu += r.nu;
      final productNames = r.products
          .map((p) => '${p.productName} (×${p.quantity})')
          .join(', ');
      buffer.writeln(
        '<tr>'
        '<td class="num">$idx</td>'
        '<td>${_fmtDate(r.date)}</td>'
        '<td>${_escapeHtml(r.storeName ?? '')}</td>'
        '<td>${_escapeHtml(r.pgName)}</td>'
        '<td>${_escapeHtml(r.employeeCode ?? '')}</td>'
        '<td class="num">${r.nu}</td>'
        '<td class="num">${CurrencyFormatter.formatVND(r.saleOut)}</td>'
        '<td class="num">${CurrencyFormatter.formatVND(r.revenue)}</td>'
        '<td>${_escapeHtml(productNames)}</td>'
        '</tr>',
      );
    }

    buffer.writeln('''</tbody>
<tfoot><tr>
<td colspan="5">TỔNG CỘNG</td>
<td class="num">$totalNu</td>
<td class="num">${CurrencyFormatter.formatVND(totalSaleOut)}</td>
<td class="num">${CurrencyFormatter.formatVND(totalRevenue)}</td>
<td></td>
</tr></tfoot>
</table>
<div class="summary">
  <div class="card"><div class="label">Số báo cáo</div><div class="value">${reports.length}</div></div>
  <div class="card"><div class="label">Tổng NU</div><div class="value">$totalNu</div></div>
  <div class="card"><div class="label">Tổng Sale Out</div><div class="value">${CurrencyFormatter.formatVND(totalSaleOut)}</div></div>
  <div class="card"><div class="label">Tổng doanh thu</div><div class="value">${CurrencyFormatter.formatVND(totalRevenue)}</div></div>
</div>
</body></html>''');

    final bytes = utf8.encode(buffer.toString());
    final fileName = 'bao_cao_ban_hang${_suffixForRange(filterType, from, to)}.html';
    downloadFile(bytes, fileName, 'text/html;charset=utf-8');
  }

  static String _escapeHtml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
