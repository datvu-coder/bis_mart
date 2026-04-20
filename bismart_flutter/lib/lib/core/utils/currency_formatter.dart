import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final _vndFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  static final _compactFormat = NumberFormat.compactCurrency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  static String formatVND(double amount) => _vndFormat.format(amount);

  static String formatCompact(double amount) => _compactFormat.format(amount);

  static String formatNumber(int number) =>
      NumberFormat('#,###', 'vi_VN').format(number);
}
