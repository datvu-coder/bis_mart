import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../models/sales_report.dart';
import '../core/utils/currency_formatter.dart';

class ExportService {
  ExportService._();

  static void exportToCsv(List<SalesReport> reports) {
    final buffer = StringBuffer();
    buffer.writeln('Ngày,PG,NU,Doanh số N1,Doanh thu,Sản phẩm');

    for (final r in reports) {
      final productNames = r.products.map((p) => p.productName).join('; ');
      buffer.writeln(
        '${r.date.day}/${r.date.month}/${r.date.year},'
        '${r.pgName},'
        '${r.nu},'
        '${r.revenueN1},'
        '${r.revenue},'
        '"$productNames"',
      );
    }

    final bytes = utf8.encode(buffer.toString());
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'bao_cao_ban_hang.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  static void exportToHtmlTable(List<SalesReport> reports) {
    final buffer = StringBuffer();
    buffer.writeln('''
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<title>Báo cáo bán hàng - Bi'S MART</title>
<style>
body { font-family: Arial, sans-serif; padding: 20px; }
h1 { color: #E05C27; }
table { border-collapse: collapse; width: 100%; margin-top: 16px; }
th, td { border: 1px solid #ddd; padding: 10px; text-align: left; }
th { background: #E05C27; color: white; }
tr:nth-child(even) { background: #f9f9f9; }
</style></head><body>
<h1>Báo cáo bán hàng - Bi'S MART</h1>
<table>
<tr><th>Ngày</th><th>PG</th><th>NU</th><th>Doanh số N1</th><th>Doanh thu</th><th>Sản phẩm</th></tr>
''');

    for (final r in reports) {
      final productNames = r.products.map((p) => '${p.productName} (x${p.quantity})').join(', ');
      buffer.writeln(
        '<tr>'
        '<td>${r.date.day}/${r.date.month}/${r.date.year}</td>'
        '<td>${r.pgName}</td>'
        '<td>${r.nu}</td>'
        '<td>${CurrencyFormatter.formatVND(r.revenueN1)}</td>'
        '<td>${CurrencyFormatter.formatVND(r.revenue)}</td>'
        '<td>$productNames</td>'
        '</tr>',
      );
    }

    buffer.writeln('</table></body></html>');

    final bytes = utf8.encode(buffer.toString());
    final blob = html.Blob([bytes], 'text/html;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'bao_cao_ban_hang.html')
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
