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
import '../../providers/permission_provider.dart';
import '../../providers/store_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/export_service.dart';
import '../../widgets/common/data_panel.dart';
import '../../widgets/common/desktop_layout.dart';
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
      final storeProv = context.read<StoreProvider>();
      if (storeProv.stores.isEmpty) storeProv.loadStores();
      // Đảm bảo quyền đã được giải quyết để bộ lọc cửa hàng theo quản lý
      // hoạt động ngay cả khi người dùng vào thẳng tab Kinh doanh.
      final permProv = context.read<PermissionProvider>();
      final user = context.read<AuthProvider>().currentUser;
      if (user != null && permProv.systemRole == null) {
        permProv.resolveForUser(user);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Tập mã cửa hàng người dùng được phân quyền truy cập — đồng bộ với
  /// logic ở tab Cá nhân (`store_list_screen.dart`):
  /// - Admin: trả về set rỗng (= không giới hạn).
  /// - Người dùng khác: hợp của
  ///     • những cửa hàng được phân làm quản lý (managedStoreIds), VÀ
  ///     • cửa hàng được gán trực tiếp qua `employee.storeCode`
  ///       (`PermissionProvider.ownStoreCode`).
  Set<String> _resolveAllowedStoreCodes(BuildContext context) {
    final perm = context.watch<PermissionProvider>();
    final storeProv = context.watch<StoreProvider>();
    if (perm.isAdmin) return const <String>{};
    final codes = <String>{};
    // (1) Cửa hàng được phân làm quản lý (Tier-2).
    for (final id in perm.managedStoreIds) {
      final s = storeProv.getStoreById(id);
      if (s != null && s.storeCode.trim().isNotEmpty) {
        codes.add(s.storeCode.trim().toUpperCase());
      }
    }
    // (2) Cửa hàng được gán trực tiếp cho tài khoản (employee.storeCode).
    final own = (perm.ownStoreCode ?? '').trim();
    if (own.isNotEmpty) codes.add(own.toUpperCase());
    return codes;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1280;
    final isTablet = screenWidth >= 900 && screenWidth < 1280;
    final isCompactMobile = screenWidth < 430;
    final isWide = isDesktop || isTablet;

    // Đồng bộ phạm vi cửa hàng theo phân quyền (đợi tới sau frame để tránh
    // setState-during-build). Setter trong SalesProvider tự nhận biết
    // không thay đổi để bỏ qua notify.
    final allowedCodes = _resolveAllowedStoreCodes(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SalesProvider>().setAllowedStoreCodes(allowedCodes);
    });

    return Consumer<SalesProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.reports.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final hPad = isWide ? (isDesktop ? 32.0 : 24.0) : 2.0;
        final contentPad = isWide ? hPad : 10.0;

        // Tab layout for all screen sizes
        final body = Column(
          children: [
            if (!isCompactMobile)
              Padding(
                padding: EdgeInsets.fromLTRB(contentPad, isWide ? 20 : 14, contentPad, 10),
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
                    padding: EdgeInsets.fromLTRB(contentPad, 12, contentPad, 12),
                    child: _buildReportList(provider),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(contentPad, 12, contentPad, 12),
                    child: Column(
                      children: [
                        _buildTopPgPanel(provider),
                        const SizedBox(height: 12),
                        _buildStoreRevenuePanel(provider),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(contentPad, 12, contentPad, 12),
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
    final stores = provider.availableStores;
    final activeStoreCode = provider.storeFilter;
    final activeStoreName = activeStoreCode == null
        ? null
        : stores
            .firstWhere(
              (e) => e.key == activeStoreCode,
              orElse: () => MapEntry(activeStoreCode, activeStoreCode),
            )
            .value;

    String rangeLabel;
    switch (provider.filterType) {
      case 'today':
        rangeLabel = AppStrings.homNay;
        break;
      case 'week':
        rangeLabel = AppStrings.tuanNay;
        break;
      case 'month':
        rangeLabel = AppStrings.thangNay;
        break;
      case 'custom':
        rangeLabel = (provider.customStart != null && provider.customEnd != null)
            ? '${DateFormatter.formatDate(provider.customStart!)} → ${DateFormatter.formatDate(provider.customEnd!)}'
            : 'Tuỳ chỉnh';
        break;
      default:
        rangeLabel = 'Tất cả';
    }

    final filteredReports = provider.filteredReports;
    final totalRev =
        filteredReports.fold<double>(0, (s, r) => s + r.revenue);
    final totalSaleOut =
        filteredReports.fold<double>(0, (s, r) => s + r.saleOut);
    final totalNu = filteredReports.fold<int>(0, (s, r) => s + r.nu);

    return DataPanel(
      title: AppStrings.boLoc,
      trailing: IconButton(
        tooltip: 'Mở bộ lọc',
        onPressed: () => _openFilterSheet(provider),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        icon: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.tune_rounded,
              size: 18, color: AppColors.white),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Active filter chips — bấm để mở bộ lọc.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _activeFilterChip(
                icon: Icons.event_rounded,
                label: 'Thời gian: $rangeLabel',
                color: AppColors.primary,
                onClear: provider.filterType == 'today'
                    ? null
                    : () => provider.setFilter('today'),
              ),
              _activeFilterChip(
                icon: Icons.store_rounded,
                label: activeStoreCode == null
                    ? 'Cửa hàng: Tất cả'
                    : 'Cửa hàng: $activeStoreCode · $activeStoreName',
                color: AppColors.info,
                onClear: activeStoreCode == null
                    ? null
                    : () => provider.setStoreFilter(null),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Summary of filtered content
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header strip with subtle gradient
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryLight, AppColors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                    border: const Border(
                        bottom:
                            BorderSide(color: AppColors.borderLight)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.fact_check_rounded,
                            size: 18, color: AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nội dung đang lọc',
                                style: AppTextStyles.bodyText.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary)),
                            Text(
                              activeStoreCode == null
                                  ? '$rangeLabel · Tất cả cửa hàng'
                                  : '$rangeLabel · $activeStoreCode',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(builder: (ctx, c) {
                        final twoCol = c.maxWidth < 460;
                        final cardWidth = twoCol
                            ? (c.maxWidth - 10) / 2
                            : (c.maxWidth - 30) / 4;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _summaryStat('Số báo cáo',
                                '${filteredReports.length}',
                                AppColors.info, cardWidth),
                            _summaryStat('Tổng NU', '$totalNu',
                                AppColors.primary, cardWidth),
                            _summaryStat(
                                'Sale Out',
                                CurrencyFormatter.formatVND(totalSaleOut),
                                AppColors.warning,
                                cardWidth),
                            _summaryStat(
                                'Doanh thu',
                                CurrencyFormatter.formatVND(totalRev),
                                AppColors.success,
                                cardWidth),
                          ],
                        );
                      }),
                      if (filteredReports.isEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.inbox_rounded,
                                  size: 18, color: AppColors.textHint),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Không có báo cáo phù hợp với bộ lọc.',
                                  style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textGrey,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 14),
                        ...filteredReports.take(8).map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${DateFormatter.formatDate(r.date)} · ${r.pgName}'
                                      '${r.storeCode != null ? " · ${r.storeCode}" : ""}',
                                      style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.formatVND(r.revenue),
                                    style: AppTextStyles.caption.copyWith(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            )),
                        if (filteredReports.length > 8)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '... và ${filteredReports.length - 8} báo cáo khác',
                              style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textGrey,
                                  fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeFilterChip({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onClear,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: color, fontWeight: FontWeight.w800)),
          if (onClear != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close_rounded, size: 12, color: color),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryStat(
      String label, String value, Color color, double? width) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            top: const BorderSide(color: AppColors.borderLight),
            right: const BorderSide(color: AppColors.borderLight),
            bottom: const BorderSide(color: AppColors.borderLight),
            left: BorderSide(color: color, width: 3),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.textGrey,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 15)),
          ],
        ),
      ),
    );
  }

  /// Trường chọn cửa hàng hiển thị thường trực (dropdown thật) — chỉ liệt
  /// kê những cửa hàng tài khoản hiện tại được phân quyền quản lý
  /// (đã lọc qua [SalesProvider.availableStores] dựa trên
  /// `_allowedStoreCodes`).
  Widget _buildStoreDropdownField(
    SalesProvider provider,
    List<MapEntry<String, String>> stores,
    String? activeStoreCode,
  ) {
    final isEmpty = stores.isEmpty;
    final perm = context.watch<PermissionProvider>();
    final scopeLabel = perm.isAdmin
        ? 'Tất cả cửa hàng (Admin)'
        : 'Cửa hàng được phân quyền quản lý';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.storefront_rounded,
                size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  scopeLabel,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                if (isEmpty)
                  Text(
                    'Không có cửa hàng được phân quyền',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textHint,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: activeStoreCode,
                      isExpanded: true,
                      isDense: true,
                      icon: const Icon(Icons.expand_more_rounded,
                          color: AppColors.textGrey),
                      borderRadius: BorderRadius.circular(12),
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      hint: Text(
                        'Tất cả cửa hàng (${stores.length})',
                        style: AppTextStyles.bodyText.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Row(
                            children: [
                              const Icon(Icons.store_mall_directory_rounded,
                                  size: 16, color: AppColors.info),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Tất cả cửa hàng (${stores.length})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...stores.map(
                          (s) => DropdownMenuItem<String?>(
                            value: s.key,
                            child: Row(
                              children: [
                                const Icon(Icons.storefront_rounded,
                                    size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '${s.key} · ${s.value}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) => provider.setStoreFilter(val),
                    ),
                  ),
              ],
            ),
          ),
          if (activeStoreCode != null)
            IconButton(
              tooltip: 'Bỏ lọc cửa hàng',
              icon: const Icon(Icons.close_rounded,
                  size: 18, color: AppColors.textGrey),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                  minWidth: 32, minHeight: 32),
              onPressed: () => provider.setStoreFilter(null),
            ),
        ],
      ),
    );
  }

  Future<void> _pickCustomRange(SalesProvider provider) async {
    final now = DateTime.now();
    final initial = DateTimeRange(
      start: provider.customStart ?? now.subtract(const Duration(days: 7)),
      end: provider.customEnd ?? now,
    );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initial,
      helpText: 'Chọn khoảng thời gian',
      cancelText: 'Huỷ',
      confirmText: 'Áp dụng',
      saveText: 'Lưu',
    );
    if (picked != null) {
      provider.setCustomRange(picked.start, picked.end);
    }
  }

  /// Mở bộ lọc dạng bottom-sheet — gom toàn bộ tuỳ chọn (Khoảng thời gian,
  /// Cửa hàng, Xuất dữ liệu) vào trong một khung lọc duy nhất.
  Future<void> _openFilterSheet(SalesProvider provider) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        // Lắng nghe SalesProvider để dropdown / chip cập nhật theo thời gian thực.
        return Consumer<SalesProvider>(
          builder: (ctx, prov, _) {
            final stores = prov.availableStores;
            final activeStore = prov.storeFilter;
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom:
                      MediaQuery.of(ctx).viewInsets.bottom + 12,
                  left: 16,
                  right: 16,
                  top: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.tune_rounded,
                              size: 18, color: AppColors.primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Bộ lọc',
                              style: AppTextStyles.sectionHeader),
                        ),
                        IconButton(
                          tooltip: 'Đóng',
                          onPressed: () => Navigator.pop(sheetCtx),
                          icon: const Icon(Icons.close_rounded,
                              color: AppColors.textGrey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // ── Khoảng thời gian ─────────────────────────
                    _sheetSectionTitle(
                        'Khoảng thời gian', Icons.event_available_rounded),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _rangeChoiceChip('today', AppStrings.homNay,
                            Icons.today_rounded, prov),
                        _rangeChoiceChip('week', AppStrings.tuanNay,
                            Icons.calendar_view_week_rounded, prov),
                        _rangeChoiceChip('month', AppStrings.thangNay,
                            Icons.calendar_month_rounded, prov),
                        _rangeChoiceChip('custom', 'Tuỳ chỉnh',
                            Icons.date_range_rounded, prov),
                      ],
                    ),
                    if (prov.filterType == 'custom' &&
                        prov.customStart != null &&
                        prov.customEnd != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${DateFormatter.formatDate(prov.customStart!)} → ${DateFormatter.formatDate(prov.customEnd!)}',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                    const SizedBox(height: 18),
                    // ── Cửa hàng (dropdown) ──────────────────────
                    _sheetSectionTitle(
                        'Cửa hàng', Icons.storefront_rounded),
                    const SizedBox(height: 8),
                    _buildStoreDropdownField(prov, stores, activeStore),
                    const SizedBox(height: 18),
                    // ── Xuất dữ liệu ─────────────────────────────
                    _sheetSectionTitle(
                        'Xuất dữ liệu', Icons.ios_share_rounded),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ExportService.exportToHtmlTable(
                                prov.filteredReports,
                                filterType: prov.filterType,
                                from: prov.customStart,
                                to: prov.customEnd,
                              );
                              Navigator.pop(sheetCtx);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content:
                                    const Text('Đang xuất PDF...'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                              ));
                            },
                            icon: const Icon(
                                Icons.picture_as_pdf_rounded,
                                size: 18,
                                color: AppColors.error),
                            label: const Text('PDF / HTML'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                              side: const BorderSide(
                                  color: AppColors.borderLight),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ExportService.exportToCsv(
                                prov.filteredReports,
                                filterType: prov.filterType,
                                from: prov.customStart,
                                to: prov.customEnd,
                              );
                              Navigator.pop(sheetCtx);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: const Text(
                                    'Đang xuất Excel...'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                              ));
                            },
                            icon: const Icon(
                                Icons.table_chart_rounded,
                                size: 18,
                                color: AppColors.success),
                            label: const Text('Excel (CSV)'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                              side: const BorderSide(
                                  color: AppColors.borderLight),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.w800),
                        ),
                        child: const Text('Xong'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _sheetSectionTitle(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _rangeChoiceChip(
      String value, String label, IconData icon, SalesProvider prov) {
    final selected = prov.filterType == value;
    return ChoiceChip(
      avatar: Icon(icon,
          size: 16,
          color: selected ? AppColors.white : AppColors.textGrey),
      label: Text(label),
      selected: selected,
      labelStyle: TextStyle(
        color: selected ? AppColors.white : AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
      ),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceVariant,
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.borderLight,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      onSelected: (_) async {
        if (value == 'custom') {
          await _pickCustomRange(prov);
        } else {
          prov.setFilter(value);
        }
      },
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
