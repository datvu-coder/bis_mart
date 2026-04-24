import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/data_panel.dart';
import '../../widgets/common/filter_dropdown.dart';
import '../../widgets/charts/revenue_bar_chart.dart';
import '../../widgets/charts/product_h_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboard();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;
    final isCompactMobile = screenWidth < 390;

    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.data == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final data = provider.data;
        if (data == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_rounded, size: 48, color: AppColors.textHint),
                const SizedBox(height: 12),
                Text('Không có dữ liệu', style: AppTextStyles.bodyText),
              ],
            ),
          );
        }

        final hPad = isWide ? 24.0 : 16.0;

        // Tab layout for all screen sizes
        return Column(
          children: [
            Container(
              color: AppColors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textHint,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
                tabs: [
                  isCompactMobile
                      ? const Tab(icon: Icon(Icons.dashboard_rounded, size: 18))
                      : const Tab(text: 'Tổng quan'),
                  isCompactMobile
                      ? const Tab(icon: Icon(Icons.bar_chart_rounded, size: 18))
                      : const Tab(text: 'Biểu đồ'),
                  isCompactMobile
                      ? const Tab(icon: Icon(Icons.emoji_events_rounded, size: 18))
                      : const Tab(text: 'Xếp hạng'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  SingleChildScrollView(
                    padding: EdgeInsets.all(hPad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(provider, data),
                        const SizedBox(height: 16),
                        _buildMetricCards(data, isWide),
                        const SizedBox(height: 16),
                        _buildAnnouncementBanner(data),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.all(hPad),
                    child: Column(
                      children: [
                        _buildChartCard(AppStrings.bieuDoDoanhSo, Icons.bar_chart_rounded, RevenueBarChart(data: data.revenueChart)),
                        const SizedBox(height: 16),
                        _buildChartCard(AppStrings.bieuDoSanPham, Icons.pie_chart_rounded, ProductHChart(data: data.productChart)),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.all(hPad),
                    child: Column(
                      children: [
                        if (data.featuredPrograms.isNotEmpty) _buildFeaturedPrograms(data),
                        _buildTopEmployees(data),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(DashboardProvider provider, dynamic data) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.dashboard,
                style: AppTextStyles.appTitle,
              ),
              const SizedBox(height: 4),
              Text(
                DateFormatter.formatDate(data.date),
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        FilterDropdown(
          value: provider.filterType,
          onChanged: provider.setFilter,
        ),
      ],
    );
  }

  Widget _buildMetricCards(dynamic data, bool isWide) {
    final cards = [
      _MetricData(
        label: AppStrings.doanhSoNhom1,
        value: CurrencyFormatter.formatVND(data.groupRevenue),
        icon: Icons.groups_rounded,
        color: AppColors.info,
        bgColor: AppColors.infoLight,
      ),
      _MetricData(
        label: AppStrings.tongDoanhThu,
        value: CurrencyFormatter.formatVND(data.totalRevenue),
        icon: Icons.account_balance_wallet_rounded,
        color: AppColors.success,
        bgColor: AppColors.successLight,
      ),
      _MetricData(
        label: 'Top nhân viên',
        value: data.top10.isNotEmpty ? data.top10.first.name : '--',
        icon: Icons.emoji_events_rounded,
        color: AppColors.warning,
        bgColor: AppColors.warningLight,
      ),
    ];

    if (isWide) {
      return Row(
        children: cards
            .map((c) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: c == cards.last ? 0 : 12,
                    ),
                    child: _buildMetricCard(c),
                  ),
                ))
            .toList(),
      );
    }

    return Column(
      children: cards.map((c) => _buildMetricCard(c)).toList(),
    );
  }

  Widget _buildMetricCard(_MetricData metric) {
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
              color: metric.bgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(metric.icon, color: metric.color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(metric.label, style: AppTextStyles.metricLabel),
                const SizedBox(height: 6),
                Text(
                  metric.value,
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

  Widget _buildAnnouncementBanner(dynamic data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.06),
            AppColors.accent.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.campaign_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.thongBaoHeThong,
                  style: AppTextStyles.captionMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(data.announcement, style: AppTextStyles.bodyText),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, IconData icon, Widget chart) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title, style: AppTextStyles.sectionHeader),
            ],
          ),
          const SizedBox(height: 18),
          chart,
        ],
      ),
    );
  }

  Widget _buildFeaturedPrograms(dynamic data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(22),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.star_rounded, color: AppColors.warning, size: 18),
              ),
              const SizedBox(width: 10),
              Text(AppStrings.chuongTrinhNoiBat, style: AppTextStyles.sectionHeader),
            ],
          ),
          const SizedBox(height: 16),
          ...data.featuredPrograms.map<Widget>((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(p, style: AppTextStyles.linkOrange),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTopEmployees(dynamic data) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emoji_events_rounded, color: AppColors.warning, size: 18),
              ),
              const SizedBox(width: 10),
              Text(AppStrings.top10NhanVien, style: AppTextStyles.sectionHeader),
            ],
          ),
          const SizedBox(height: 16),
          ...data.top10.map<Widget>((e) {
            final isTop3 = e.rank <= 3;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isTop3
                    ? AppColors.primaryLight
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isTop3 ? AppColors.primary : AppColors.textGrey,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${e.rank}',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      e.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isTop3 ? FontWeight.w600 : FontWeight.w400,
                        color: isTop3 ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MetricData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}
