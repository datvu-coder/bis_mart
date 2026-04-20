import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final _dayFormat = DateFormat('dd/MM/yyyy');
  static final _dayTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final _timeFormat = DateFormat('HH:mm');
  static final _monthYearFormat = DateFormat('MM/yyyy');

  static String formatDate(DateTime date) => _dayFormat.format(date);

  static String formatDateTime(DateTime date) => _dayTimeFormat.format(date);

  static String formatTime(DateTime date) => _timeFormat.format(date);

  static String formatMonthYear(DateTime date) => _monthYearFormat.format(date);

  static String relativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return formatDate(date);
  }
}
