import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/sales_report.dart';
import '../../providers/sales_provider.dart';
import '../../services/export_service.dart';
import '../../widgets/common/data_panel.dart';
import '../../widgets/common/desktop_layout.dart';
import '../../widgets/common/filter_dropdown.dart';
import '../../widgets/common/weighted_tab_selector.dart';

class KinhDoanhScreen extends StatefulWidget {
  const KinhDoanhScreen({super.key});

  @override
  State<KinhDoanhScreen> createState() => _KinhDoanhScreenState();
}

class _KinhDoanhScreenState extends State<KinhDoanhScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesProvider>().loadReports();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1280;
    final isTablet = screenWidth >= 900 && screenWidth < 1280;
    final isCompactMobile = screenWidth < 430;
    final isWide = isDesktop || isTablet;

    return Consumer<SalesProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.reports.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final hPad = isWide ? (isDesktop ? 32.0 : 24.0) : 1.5;

        // Tab layout for all screen sizes
        final body = Column(
          children: [
            if (!isCompactMobile)
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, isWide ? 20 : 14, hPad, 10),
                child: _buildScreenHeader(provider, isWide),
              ),
            if (isCompactMobile)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.createReport),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text(AppStrings.taoPhieuBaoCao),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            Container(
              margin: EdgeInsets.fromLTRB(hPad, isCompactMobile ? 10 : 0, hPad, 0),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
              ),
              child: isDesktop
                  ? WeightedTabSelector(
                      controller: _tabController,
                      labels: const ['Báo cáo', 'Thống kê', 'Bộ lọc'],
                    )
                  : TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textGrey,
                      indicator: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                      labelStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                      unselectedLabelStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                      tabs: const [
                        Tab(text: 'Báo cáo'),
                        Tab(text: 'Thống kê'),
                        Tab(text: 'Bộ lọc'),
                      ],
                    ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 12),
                    child: _buildReportList(provider),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 12),
                    child: Column(
                      children: [
                        _buildTopPgPanel(provider),
                        const SizedBox(height: 12),
                        _buildStoreRevenuePanel(provider),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 12),
                    child: _buildFilterPanel(provider),
                  ),
                ],
              ),
            ),
          ],
        );
        return isDesktop ? DesktopMaxWidth(child: body) : body;
      },
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildScreenHeader(SalesProvider provider, bool emphasize) {
    final totalRev = provider.totalRevenue;
    final reportCount = provider.salesReportCount;
    final pgCount = provider.filteredReports.map((r) => r.pgName).toSet().length;
    final isCompactMobile = !emphasize && MediaQuery.of(context).size.width < 430;

    return Container(
      width: double.infinity,
      padding: isCompactMobile
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
          : EdgeInsets.all(emphasize ? 20 : 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEBF8F0), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCompactMobile) ...[
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bar_chart_rounded,
                      color: AppColors.success, size: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.kinhDoanh, style: AppTextStyles.appTitle),
                      const SizedBox(height: 2),
                      Text('Báo cáo bán hàng & thống kê doanh thu',
                          style: AppTextStyles.caption),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.createReport),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(AppStrings.taoPhieuBaoCao),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    textStyle:
                        const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (isCompactMobile)
            Row(
              children: [
                Expanded(
                  child: _buildKpiChip(
                    icon: Icons.description_rounded,
                    label: 'Báo cáo',
                    value: '$reportCount',
                    color: AppColors.info,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildKpiChip(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Doanh thu',
                    value: CurrencyFormatter.formatVND(totalRev),
                    color: AppColors.success,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildKpiChip(
                    icon: Icons.person_rounded,
                    label: 'PG',
                    value: '$pgCount',
                    color: AppColors.primary,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton.filled(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.createReport),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    tooltip: AppStrings.taoPhieuBaoCao,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildKpiChip(
                  icon: Icons.description_rounded,
                  label: 'Báo cáo',
                  value: '$reportCount',
                  color: AppColors.info,
                ),
                _buildKpiChip(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Doanh thu',
                  value: CurrencyFormatter.formatVND(totalRev),
                  color: AppColors.success,
                ),
                _buildKpiChip(
                  icon: Icons.person_rounded,
                  label: 'PG',
                  value: '$pgCount',
                  color: AppColors.primary,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildKpiChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: compact
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption
                      .copyWith(color: color, fontWeight: FontWeight.w800),
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text('$label: ',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                Text(value,
                    style: AppTextStyles.caption
                        .copyWith(color: color, fontWeight: FontWeight.w800)),
              ],
            ),
    );
  }

  // ── Panels ────────────────────────────────────────────────────────────────

  Widget _buildReportList(SalesProvider provider) {
    final reports = provider.filteredReports;
    return DataPanel(
      title: 'Báo cáo (${reports.length})',
      child: reports.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_rounded, size: 40, color: AppColors.textHint),
                    const SizedBox(height: 8),
                    Text('Chưa có báo cáo trong khoảng thời gian này',
                        style: AppTextStyles.caption),
                  ],
                ),
              ),
            )
          : Column(
              children: reports.map((report) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    onTap: () => _showReportDetail(report),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.receipt_long_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    title: Text(
                      'Báo cáo ${DateFormatter.formatDate(report.date)}',
                      style: AppTextStyles.bodyText
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${report.pgName} · ${CurrencyFormatter.formatVND(report.revenue)}',
                      style: AppTextStyles.caption,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textGrey),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildFilterPanel(SalesProvider provider) {
    return DataPanel(
      title: AppStrings.boLoc,
      child: Column(
        children: [
          FilterDropdown(
            value: provider.filterType,
            onChanged: provider.setFilter,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ExportService.exportToHtmlTable(provider.reports);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('Đang xuất PDF...'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ));
                  },
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text(AppStrings.exportPDF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ExportService.exportToCsv(provider.reports);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('Đang xuất Excel...'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ));
                  },
                  icon: const Icon(Icons.table_chart_rounded, size: 18),
                  label: const Text(AppStrings.exportExcel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopPgPanel(SalesProvider provider) {
    final Map<String, double> pgRevenue = {};
    for (final r in provider.filteredReports) {
      pgRevenue[r.pgName] = (pgRevenue[r.pgName] ?? 0) + r.revenue;
    }
    final sorted = pgRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(8).toList();

    return DataPanel(
      title: 'Top PG',
      child: top.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child:
                      Text('Chưa có dữ liệu', style: AppTextStyles.caption)),
            )
          : Column(
              children: List.generate(top.length, (i) {
                final entry = top[i];
                final maxRev = top.first.value;
                final fraction = maxRev > 0 ? entry.value / maxRev : 0.0;
                final rankColors = [
                  AppColors.warning,
                  AppColors.textGrey,
                  AppColors.primary,
                ];
                final rankColor =
                    i < 3 ? rankColors[i] : AppColors.textHint;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${i + 1}',
                          style: AppTextStyles.caption.copyWith(
                            color: rankColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(entry.key,
                                      style: AppTextStyles.bodyText.copyWith(
                                          fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                Text(
                                  CurrencyFormatter.formatVND(entry.value),
                                  style: AppTextStyles.caption.copyWith(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: fraction,
                                backgroundColor: AppColors.surfaceVariant,
                                color: i == 0
                                    ? AppColors.warning
                                    : AppColors.success,
                                minHeight: 5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
    );
  }

  Widget _buildStoreRevenuePanel(SalesProvider provider) {
    final Map<String, double> storeRevenue = {};
    for (final r in provider.filteredReports) {
      final key = r.storeName ?? 'Không xác định';
      storeRevenue[key] = (storeRevenue[key] ?? 0) + r.revenue;
    }
    final sorted = storeRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return DataPanel(
      title: 'Doanh thu theo cửa hàng',
      child: sorted.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child:
                      Text('Chưa có dữ liệu', style: AppTextStyles.caption)),
            )
          : Column(
              children: sorted.map((entry) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.store_rounded,
                            size: 16, color: AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(entry.key,
                            style: AppTextStyles.bodyText
                                .copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(
                        CurrencyFormatter.formatVND(entry.value),
                        style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ── Detail / dialogs ──────────────────────────────────────────────────────

  void _showReportDetail(SalesReport report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Báo cáo ${DateFormatter.formatDate(report.date)}',
                            style: AppTextStyles.sectionHeader),
                        const SizedBox(height: 2),
                        Text('PG: ${report.pgName}',
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(context, AppRoutes.createReport,
                          arguments: report);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.error),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmDeleteReport(report);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _detailRow('Ngày', DateFormatter.formatDate(report.date)),
              _detailRow('PG', report.pgName),
              _detailRow('NU', '${report.nu}'),
              _detailRow('Sale Out', CurrencyFormatter.formatVND(report.saleOut)),
              _detailRow('Doanh thu', CurrencyFormatter.formatVND(report.revenue)),
              if (report.products.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Sản phẩm (${report.products.length})',
                    style: AppTextStyles.sectionHeader),
                const SizedBox(height: 8),
                ...report.products.map((p) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.productName,
                                    style: AppTextStyles.bodyTextMedium),
                                Text(
                                    'SL: ${p.quantity} × ${CurrencyFormatter.formatVND(p.unitPrice)}',
                                    style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                          Text(CurrencyFormatter.formatVND(p.total),
                              style: AppTextStyles.bodyTextMedium
                                  .copyWith(color: AppColors.primary)),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(label, style: AppTextStyles.caption),
          const Spacer(),
          Text(value, style: AppTextStyles.bodyTextMedium),
        ],
      ),
    );
  }

  void _confirmDeleteReport(SalesReport report) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa báo cáo'),
        content: Text(
            'Bạn có chắc muốn xóa báo cáo ngày ${DateFormatter.formatDate(report.date)}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              context.read<SalesProvider>().deleteReport(report.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Đã xóa báo cáo!'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}
