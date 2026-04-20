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
import '../../widgets/common/filter_dropdown.dart';

class KinhDoanhScreen extends StatefulWidget {
  const KinhDoanhScreen({super.key});

  @override
  State<KinhDoanhScreen> createState() => _KinhDoanhScreenState();
}

class _KinhDoanhScreenState extends State<KinhDoanhScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesProvider>().loadReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Consumer<SalesProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.reports.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(isWide ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.kinhDoanh, style: AppTextStyles.appTitle),
                        const SizedBox(height: 4),
                        Text(
                          'Báo cáo bán hàng & thống kê doanh thu',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.createReport);
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(AppStrings.taoPhieuBaoCao),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Stat cards
              _buildStatCards(provider, isWide),
              const SizedBox(height: 20),

              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildReportList(provider),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: _buildFilterPanel(provider),
                    ),
                  ],
                )
              else ...[
                _buildReportList(provider),
                _buildFilterPanel(provider),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCards(SalesProvider provider, bool isWide) {
    final items = [
      _StatItem(
        label: AppStrings.baoCaoBanHang,
        value: '${provider.salesReportCount}',
        icon: Icons.description_rounded,
        color: AppColors.info,
        bgColor: AppColors.infoLight,
      ),
      _StatItem(
        label: AppStrings.tongDoanhThu,
        value: CurrencyFormatter.formatVND(provider.totalRevenue),
        icon: Icons.account_balance_wallet_rounded,
        color: AppColors.success,
        bgColor: AppColors.successLight,
      ),
    ];

    if (isWide) {
      return Row(
        children: items
            .map((item) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: item == items.last ? 0 : 12),
                    child: _buildStatCard(item),
                  ),
                ))
            .toList(),
      );
    }
    return Column(children: items.map(_buildStatCard).toList());
  }

  Widget _buildStatCard(_StatItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.card,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: item.bgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(item.icon, color: item.color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: AppTextStyles.metricLabel),
                const SizedBox(height: 4),
                Text(
                  item.value,
                  style: AppTextStyles.sectionHeader,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportList(SalesProvider provider) {
    final reports = provider.filteredReports;

    return DataPanel(
      title: '${AppStrings.baoCaoNgay} (${reports.length})',
      child: reports.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_rounded, size: 40, color: AppColors.textHint),
                    const SizedBox(height: 8),
                    Text('Chưa có báo cáo trong khoảng thời gian này', style: AppTextStyles.caption),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
              ),
              title: Text(
                'Báo cáo ${DateFormatter.formatDate(report.date)}',
                style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${report.pgName} • ${CurrencyFormatter.formatVND(report.revenue)}',
                style: AppTextStyles.caption,
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textGrey),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterPanel(SalesProvider provider) {
    return Column(
      children: [
        DataPanel(
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Đang xuất PDF...'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Đang xuất Excel...'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                      icon: const Icon(Icons.table_chart_rounded, size: 18),
                      label: const Text(AppStrings.exportExcel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showReportDetail(SalesReport report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
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
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Báo cáo ${DateFormatter.formatDate(report.date)}',
                                style: AppTextStyles.sectionHeader),
                            const SizedBox(height: 2),
                            Text('PG: ${report.pgName}', style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pushNamed(
                            context,
                            AppRoutes.createReport,
                            arguments: report,
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
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
                  _detailRow('Doanh số N1', CurrencyFormatter.formatVND(report.revenueN1)),
                  _detailRow('Doanh thu', CurrencyFormatter.formatVND(report.revenue)),
                  if (report.products.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Sản phẩm (${report.products.length})', style: AppTextStyles.sectionHeader),
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
                                Text(p.productName, style: AppTextStyles.bodyTextMedium),
                                Text('SL: ${p.quantity} × ${CurrencyFormatter.formatVND(p.unitPrice)}',
                                    style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                          Text(CurrencyFormatter.formatVND(p.total),
                              style: AppTextStyles.bodyTextMedium.copyWith(color: AppColors.primary)),
                        ],
                      ),
                    )),
                  ],
                ],
              ),
            );
          },
        );
      },
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
        content: Text('Bạn có chắc muốn xóa báo cáo ngày ${DateFormatter.formatDate(report.date)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<SalesProvider>().deleteReport(report.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Đã xóa báo cáo!'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}
