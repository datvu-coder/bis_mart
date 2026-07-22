import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/sales_report.dart';
import '../../services/api_service.dart';

/// Aggregates existing sales reports into a VAT-declaration reference
/// summary (revenue, estimated output VAT, breakdown by store/product
/// group) for a chosen month or quarter.
///
/// This is a DATA-PREPARATION tool only. It does not file anything and
/// has no connection to the tax authority's systems — a genuine e-invoice
/// submission requires a licensed provider (MISA meInvoice, VNPT, Viettel...)
/// with a digital-signature contract, which is outside what an app can set
/// up on its own.
class TaxReportScreen extends StatefulWidget {
  const TaxReportScreen({super.key});

  @override
  State<TaxReportScreen> createState() => _TaxReportScreenState();
}

class _TaxReportScreenState extends State<TaxReportScreen> {
  static const _vatRates = [0.0, 0.05, 0.08, 0.10];

  bool _isQuarterly = false;
  late int _year;
  late int _month;
  late int _quarter;
  double _vatRate = 0.10;

  bool _loading = false;
  String? _error;
  List<SalesReport> _periodReports = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _quarter = ((now.month - 1) ~/ 3) + 1;
    _load();
  }

  ({DateTime start, DateTime end}) get _periodRange {
    if (_isQuarterly) {
      final startMonth = (_quarter - 1) * 3 + 1;
      final start = DateTime(_year, startMonth, 1);
      final end = DateTime(_year, startMonth + 3, 0, 23, 59, 59);
      return (start: start, end: end);
    }
    final start = DateTime(_year, _month, 1);
    final end = DateTime(_year, _month + 1, 0, 23, 59, 59);
    return (start: start, end: end);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService().getReports(filter: 'all');
      final all = data
          .map((r) => SalesReport.fromJson(r as Map<String, dynamic>))
          .toList();
      final range = _periodRange;
      _periodReports = all
          .where((r) =>
              !r.date.isBefore(range.start) && !r.date.isAfter(range.end))
          .toList();
    } catch (_) {
      _error = 'Không thể tải dữ liệu báo cáo';
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  double get _totalRevenue =>
      _periodReports.fold<double>(0, (sum, r) => sum + r.revenue);
  double get _revenueExVat => _totalRevenue / (1 + _vatRate);
  double get _outputVat => _totalRevenue - _revenueExVat;

  Map<String, double> get _revenueByStore {
    final map = <String, double>{};
    for (final r in _periodReports) {
      final key = (r.storeName?.trim().isNotEmpty ?? false)
          ? r.storeName!.trim()
          : (r.storeCode ?? 'Chưa rõ cửa hàng');
      map[key] = (map[key] ?? 0) + r.revenue;
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries);
  }

  Map<String, double> get _revenueByGroup {
    final map = <String, double>{};
    for (final r in _periodReports) {
      for (final item in r.products) {
        final key = (item.productGroup?.trim().isNotEmpty ?? false)
            ? item.productGroup!.trim()
            : 'Khác';
        map[key] = (map[key] ?? 0) + item.total;
      }
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries);
  }

  String get _periodLabel => _isQuarterly ? 'Quý $_quarter/$_year' : 'Tháng $_month/$_year';

  String _buildSummaryText() {
    final buffer = StringBuffer();
    buffer.writeln("BÁO CÁO THAM KHẢO KÊ KHAI THUẾ GTGT - Bi'S MART");
    buffer.writeln('Kỳ: $_periodLabel');
    buffer.writeln('Thuế suất áp dụng: ${(_vatRate * 100).toStringAsFixed(0)}%');
    buffer.writeln('Số báo cáo bán hàng: ${_periodReports.length}');
    buffer.writeln('---');
    buffer.writeln('Tổng doanh thu (đã gồm thuế): ${CurrencyFormatter.formatVND(_totalRevenue)}');
    buffer.writeln('Doanh thu chưa thuế (ước tính): ${CurrencyFormatter.formatVND(_revenueExVat)}');
    buffer.writeln('Thuế GTGT đầu ra (ước tính): ${CurrencyFormatter.formatVND(_outputVat)}');
    buffer.writeln('---');
    buffer.writeln('Doanh thu theo cửa hàng:');
    for (final e in _revenueByStore.entries) {
      buffer.writeln('  ${e.key}: ${CurrencyFormatter.formatVND(e.value)}');
    }
    buffer.writeln('---');
    buffer.writeln('Doanh thu theo nhóm sản phẩm:');
    for (final e in _revenueByGroup.entries) {
      buffer.writeln('  ${e.key}: ${CurrencyFormatter.formatVND(e.value)}');
    }
    buffer.writeln('---');
    buffer.writeln(
        'Lưu ý: số liệu trên chỉ tổng hợp doanh thu bán ra ghi nhận trong app, '
        'CHƯA đối chiếu hóa đơn đầu vào/đầu ra thực tế. Vui lòng kiểm tra lại '
        'trước khi lập tờ khai 01/GTGT qua HTKK/eTax hoặc phần mềm hóa đơn điện tử.');
    return buffer.toString();
  }

  void _copySummary() {
    Clipboard.setData(ClipboardData(text: _buildSummaryText()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép báo cáo — dán vào Excel, Zalo, email...'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 700;
    final pad = isWide ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Báo cáo thuế GTGT'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDisclaimer(),
            const SizedBox(height: 16),
            _buildPeriodSelector(),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.primary),
              ))
            else if (_error != null)
              _buildErrorState()
            else ...[
              _buildSummaryCards(isWide),
              const SizedBox(height: 16),
              _buildBreakdownCard('Doanh thu theo cửa hàng', _revenueByStore),
              const SizedBox(height: 16),
              _buildBreakdownCard('Doanh thu theo nhóm sản phẩm', _revenueByGroup),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _periodReports.isEmpty ? null : _copySummary,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Sao chép báo cáo'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
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
              'Đây là số liệu tổng hợp từ báo cáo bán hàng để tham khảo khi lập tờ khai '
              'thuế GTGT (mẫu 01/GTGT). App KHÔNG tự động nộp thuế và KHÔNG kết nối trực '
              'tiếp với hệ thống của Tổng cục Thuế — việc đó cần đăng ký hóa đơn điện tử '
              'qua một nhà cung cấp được cấp phép (MISA, VNPT, Viettel...) cùng chữ ký số. '
              'Vui lòng đối chiếu với hóa đơn thực tế trước khi kê khai qua HTKK/eTax.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Theo tháng'),
                  selected: !_isQuarterly,
                  selectedColor: AppColors.primaryLight,
                  onSelected: (_) {
                    setState(() => _isQuarterly = false);
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Theo quý'),
                  selected: _isQuarterly,
                  selectedColor: AppColors.primaryLight,
                  onSelected: (_) {
                    setState(() => _isQuarterly = true);
                    _load();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _isQuarterly
                    ? DropdownButtonFormField<int>(
                        value: _quarter,
                        decoration: const InputDecoration(labelText: 'Quý'),
                        items: [1, 2, 3, 4]
                            .map((q) => DropdownMenuItem(value: q, child: Text('Quý $q')))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _quarter = v);
                          _load();
                        },
                      )
                    : DropdownButtonFormField<int>(
                        value: _month,
                        decoration: const InputDecoration(labelText: 'Tháng'),
                        items: List.generate(12, (i) => i + 1)
                            .map((m) => DropdownMenuItem(value: m, child: Text('Tháng $m')))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _month = v);
                          _load();
                        },
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _year,
                  decoration: const InputDecoration(labelText: 'Năm'),
                  items: List.generate(4, (i) => DateTime.now().year - i)
                      .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _year = v);
                    _load();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<double>(
            value: _vatRate,
            decoration: const InputDecoration(labelText: 'Thuế suất GTGT áp dụng'),
            items: _vatRates
                .map((rate) => DropdownMenuItem(
                      value: rate,
                      child: Text('${(rate * 100).toStringAsFixed(0)}%'),
                    ))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _vatRate = v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppDecorations.card,
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, size: 32, color: AppColors.error),
            const SizedBox(height: 8),
            Text(_error!, style: AppTextStyles.caption),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(bool isWide) {
    final cards = [
      _SummaryCardData('Kỳ báo cáo', _periodLabel, Icons.event_rounded, AppColors.info),
      _SummaryCardData('Số báo cáo', '${_periodReports.length}', Icons.description_rounded, AppColors.primary),
      _SummaryCardData('Tổng doanh thu (đã gồm thuế)',
          CurrencyFormatter.formatVND(_totalRevenue), Icons.account_balance_wallet_rounded, AppColors.success),
      _SummaryCardData('Doanh thu chưa thuế (ước tính)',
          CurrencyFormatter.formatVND(_revenueExVat), Icons.receipt_long_rounded, AppColors.textSecondary),
      _SummaryCardData('Thuế GTGT đầu ra (ước tính)',
          CurrencyFormatter.formatVND(_outputVat), Icons.request_quote_rounded, AppColors.warning),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = isWide ? 3 : 2;
      final spacing = 12.0;
      final cardWidth = (constraints.maxWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: cards
            .map((c) => SizedBox(width: cardWidth, child: _summaryCard(c)))
            .toList(),
      );
    });
  }

  Widget _summaryCard(_SummaryCardData data) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.row,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, size: 18, color: data.color),
          const SizedBox(height: 8),
          Text(data.label, style: AppTextStyles.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(
            data.value,
            style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w700, color: data.color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard(String title, Map<String, double> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (data.isEmpty)
            Text('Không có dữ liệu trong kỳ này', style: AppTextStyles.caption)
          else
            ...data.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(e.key,
                            style: AppTextStyles.bodyText, overflow: TextOverflow.ellipsis),
                      ),
                      Text(
                        CurrencyFormatter.formatVND(e.value),
                        style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

class _SummaryCardData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _SummaryCardData(this.label, this.value, this.icon, this.color);
}
