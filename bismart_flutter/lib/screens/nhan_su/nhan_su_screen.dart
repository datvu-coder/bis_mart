import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/employee_provider.dart';
import '../../providers/store_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/attendance.dart';
import '../../models/employee.dart';
import '../../models/work_schedule.dart';
import '../../models/work_shift.dart';
import '../../providers/permission_provider.dart';
import '../../services/location_service.dart';
import '../../widgets/common/data_panel.dart';
import '../../widgets/common/desktop_layout.dart';
import '../../widgets/common/weighted_tab_selector.dart';
import '../../widgets/cards/rank_list_tile.dart';

class NhanSuScreen extends StatefulWidget {
  const NhanSuScreen({super.key});

  @override
  State<NhanSuScreen> createState() => _NhanSuScreenState();
}

class _NhanSuScreenState extends State<NhanSuScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  bool _isCheckingIn = false;
  String? _locationError;
  double? _lastDistance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<EmployeeProvider>();
      final currentUser = context.read<AuthProvider>().currentUser;
      provider.loadEmployees();
      provider.loadAttendances();
      // Load monthly summary for current user only
      provider.loadMonthlySummary(employeeId: currentUser?.id);
      provider.loadSchedules();
      context.read<StoreProvider>().loadStores().then((_) {
        // Auto-filter shifts to current user's store
        if (currentUser?.storeCode != null && mounted) {
          final store = context
              .read<StoreProvider>()
              .getStoreByCode(currentUser!.storeCode!);
          if (store != null) {
            provider.loadShifts(storeId: store.id);
          } else {
            provider.loadShifts();
          }
        } else {
          provider.loadShifts();
        }
      });
      // Load permissions for current user's position
      if (currentUser != null) {
        context.read<PermissionProvider>().resolveForUser(currentUser);
      }
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
    final canManage = context.watch<PermissionProvider>().canManageAttendance;

    return Consumer<EmployeeProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.employees.isEmpty) {
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
                child: _buildScreenHeader(provider, canManage, isWide),
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
                      labels: const ['Chấm công', 'Ca làm', 'Xếp hạng', 'Lịch'],
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
                      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      tabs: const [
                        Tab(text: 'Chấm công'),
                        Tab(text: 'Ca làm'),
                        Tab(text: 'Xếp hạng'),
                        Tab(text: 'Lịch'),
                      ],
                    ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(contentPad, 12, contentPad, 12),
                    child: _buildAttendancePanel(provider, canManage),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(contentPad, 12, contentPad, 12),
                    child: _buildShiftPanel(provider),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(contentPad, 12, contentPad, 12),
                    child: _buildRankPanel(provider),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(contentPad, 12, contentPad, 12),
                    child: _buildSchedulePanel(provider, canManage),
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

  Widget _buildScreenHeader(EmployeeProvider provider, bool canManage, bool emphasize) {
    final checkedInCount = provider.attendances.where((a) => a.isCheckedIn).length;
    final activeShiftCount = provider.shifts.length;
    final memberCount = provider.employees.length;
    final isCompactMobile = !emphasize && MediaQuery.of(context).size.width < 430;

    return Container(
      width: double.infinity,
      padding: isCompactMobile
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
          : EdgeInsets.all(emphasize ? 20 : 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF2EB), Color(0xFFFFFFFF)],
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
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.groups_2_rounded,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.nhanSu, style: AppTextStyles.appTitle),
                      const SizedBox(height: 2),
                      Text(
                        'Điều phối chấm công, ca làm và hiệu suất đội ngũ',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                if (canManage)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.infoLight,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      'Quản lý',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.info,
                        fontWeight: FontWeight.w700,
                      ),
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
                  child: _buildHeaderKpiChip(
                    icon: Icons.badge_rounded,
                    label: 'Nhân viên',
                    value: '$memberCount',
                    color: AppColors.primary,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildHeaderKpiChip(
                    icon: Icons.login_rounded,
                    label: 'Đã vào ca',
                    value: '$checkedInCount',
                    color: AppColors.success,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildHeaderKpiChip(
                    icon: Icons.schedule_rounded,
                    label: 'Ca làm',
                    value: '$activeShiftCount',
                    color: AppColors.info,
                    compact: true,
                  ),
                ),
              ],
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildHeaderKpiChip(
                  icon: Icons.badge_rounded,
                  label: 'Nhân viên',
                  value: '$memberCount',
                  color: AppColors.primary,
                ),
                _buildHeaderKpiChip(
                  icon: Icons.login_rounded,
                  label: 'Đã vào ca',
                  value: '$checkedInCount',
                  color: AppColors.success,
                ),
                _buildHeaderKpiChip(
                  icon: Icons.schedule_rounded,
                  label: 'Ca làm',
                  value: '$activeShiftCount',
                  color: AppColors.info,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderKpiChip({
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
                Text(
                  '$label: ',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: AppTextStyles.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAttendancePanel(EmployeeProvider provider, bool canManage) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    return DataPanel(
      title: AppStrings.chamCong,
      padding: isMobile ? const EdgeInsets.all(10) : const EdgeInsets.all(22),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _showAttendanceHistory(provider, canManage: canManage),
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Lịch sử chấm công',
          ),
        ],
      ),
      child: Column(
        children: [
          // --- GPS Check-in/out Section ---
          _buildGpsCheckInSection(provider, canManage),
          SizedBox(height: isMobile ? 10 : 16),
          // --- Monthly Summary ---
          _buildMonthlySummary(provider),
          SizedBox(height: isMobile ? 10 : 16),
          // --- Today's Attendance List (managers only) ---
          if (canManage) _buildTodayAttendanceList(provider),
        ],
      ),
    );
  }

  Widget _buildGpsCheckInSection(EmployeeProvider provider, bool canManage) {
    final currentUser = context.read<AuthProvider>().currentUser;
    final stores = context.watch<StoreProvider>().stores;
    final myStore = (currentUser?.storeCode != null && stores.isNotEmpty)
        ? stores.cast<dynamic>().firstWhere(
            (s) => s.storeCode == currentUser!.storeCode,
            orElse: () => null,
          )
        : null;

    // Check if current user already checked in today
    final todayAtt = provider.attendances.where((a) =>
        a.employeeId == currentUser?.id &&
        a.date.year == DateTime.now().year &&
        a.date.month == DateTime.now().month &&
        a.date.day == DateTime.now().day).toList();
    final hasCheckedIn = todayAtt.isNotEmpty && todayAtt.first.isCheckedIn;
    final hasCheckedOut = todayAtt.isNotEmpty && todayAtt.first.checkOutTime != null;
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasCheckedOut
              ? [AppColors.surfaceVariant, AppColors.surfaceVariant]
              : hasCheckedIn
                  ? [AppColors.successLight, const Color(0xFFD1FAE5)]
                  : [AppColors.primaryLight, const Color(0xFFFFE4D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Store info
          if (myStore != null) ...[
            Row(
              children: [
                Icon(Icons.store_rounded, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${myStore.name}',
                    style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (myStore.latitude != null && myStore.longitude != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.infoLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'GPS ✓',
                      style: AppTextStyles.caption.copyWith(color: AppColors.info, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Check-in/out times
          if (hasCheckedIn && todayAtt.isNotEmpty) ...[
            isMobile
                ? Column(
                    children: [
                      Row(
                        children: [
                          _buildTimeChip(
                            'Giờ vào',
                            todayAtt.first.checkInTime,
                            AppColors.success,
                            Icons.login_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildTimeChip(
                            'Giờ ra',
                            todayAtt.first.checkOutTime,
                            hasCheckedOut ? AppColors.primary : AppColors.textHint,
                            Icons.logout_rounded,
                          ),
                        ],
                      ),
                      if (hasCheckedIn && hasCheckedOut) ...[
                        const SizedBox(height: 8),
                        Row(children: [_buildWorkingHoursChip(todayAtt.first)]),
                      ],
                    ],
                  )
                : Row(
                    children: [
                      _buildTimeChip(
                        'Giờ vào',
                        todayAtt.first.checkInTime,
                        AppColors.success,
                        Icons.login_rounded,
                      ),
                      const SizedBox(width: 12),
                      _buildTimeChip(
                        'Giờ ra',
                        todayAtt.first.checkOutTime,
                        hasCheckedOut ? AppColors.primary : AppColors.textHint,
                        Icons.logout_rounded,
                      ),
                      if (hasCheckedIn && hasCheckedOut) ...[
                        const SizedBox(width: 12),
                        _buildWorkingHoursChip(todayAtt.first),
                      ],
                    ],
                  ),
            if (todayAtt.first.distanceIn != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_rounded, size: 14, color: AppColors.textGrey),
                      const SizedBox(width: 4),
                      Text(
                        'Vào: ${_formatDistance(todayAtt.first.distanceIn!)}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                  if (todayAtt.first.distanceOut != null)
                    Text(
                      'Ra: ${_formatDistance(todayAtt.first.distanceOut!)}',
                      style: AppTextStyles.caption,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
          ],

          // Location error
          if (_locationError != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded, size: 16, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_locationError!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                  ),
                ],
              ),
            ),
          ],

          // Distance info
          if (_lastDistance != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: _lastDistance! <= 50 ? AppColors.successLight : AppColors.errorLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _lastDistance! <= 50 ? Icons.check_circle_rounded : Icons.block_rounded,
                    size: 16,
                    color: _lastDistance! <= 50 ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Khoảng cách: ${_formatDistance(_lastDistance!)}${_lastDistance! > 50 ? ' — vượt giới hạn 50m' : ''}',
                    style: AppTextStyles.caption.copyWith(
                      color: _lastDistance! <= 50 ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action buttons
          Row(
            children: [
              if (!hasCheckedIn)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isCheckingIn ? null : () => _handleGpsCheckIn(provider),
                    icon: _isCheckingIn
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                        : const Icon(Icons.fingerprint_rounded, size: 20),
                    label: Text(
                      _isCheckingIn ? 'Đang xác định...' : 'Chấm công vào',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              if (hasCheckedIn && !hasCheckedOut)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isCheckingIn ? null : () => _handleGpsCheckOut(provider),
                    icon: _isCheckingIn
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.logout_rounded, size: 20),
                    label: Text(
                      _isCheckingIn ? 'Đang xác định...' : 'Chấm công ra',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              if (hasCheckedOut)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.success, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            isMobile
                                ? 'Đã hoàn thành'
                                : 'Đã hoàn thành chấm công hôm nay',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyText.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String label, DateTime? time, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(fontSize: 10)),
                  Text(
                    time != null
                        ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                        : '--:--',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkingHoursChip(Attendance att) {
    final duration = att.checkOutTime!.difference(att.checkInTime!);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_rounded, size: 16, color: AppColors.info),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Làm việc', style: AppTextStyles.caption.copyWith(fontSize: 10)),
              Text('${hours}h${minutes.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.info)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySummary(EmployeeProvider provider) {
    final summary = provider.monthlySummary;
    final now = DateTime.now();
    final monthLabel = 'Tháng ${now.month}/${now.year}';
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Tổng kết $monthLabel',
                style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryCard(
                'Ngày công',
                '${summary['daysWorked'] ?? 0}',
                Icons.work_rounded,
                AppColors.primary,
              ),
              const SizedBox(width: 10),
              _buildSummaryCard(
                'Tổng giờ',
                '${summary['totalHours'] ?? 0}h',
                Icons.schedule_rounded,
                AppColors.info,
              ),
              const SizedBox(width: 10),
              _buildSummaryCard(
                'Tổng bản ghi',
                '${summary['totalRecords'] ?? 0}',
                Icons.assignment_rounded,
                AppColors.success,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayAttendanceList(EmployeeProvider provider) {
    if (provider.attendances.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Chưa có ai chấm công hôm nay', style: AppTextStyles.caption),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chấm công hôm nay (${provider.attendances.length})',
          style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...provider.attendances.map((att) {
          Employee? employee;
          try {
            employee = provider.employees.firstWhere((e) => e.id == att.employeeId);
          } catch (_) {}
          if (employee == null) return const SizedBox.shrink();
          final hasCheckOut = att.checkOutTime != null;
          String? workingTime;
          if (hasCheckOut && att.checkInTime != null) {
            final diff = att.checkOutTime!.difference(att.checkInTime!);
            workingTime = '${diff.inHours}h${(diff.inMinutes % 60).toString().padLeft(2, '0')}';
          }
          final isMobile = MediaQuery.of(context).size.width < 600;
          final statusIcon = Icon(
            hasCheckOut
                ? Icons.check_circle_outline_rounded
                : att.isCheckedIn
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
            color: hasCheckOut
                ? AppColors.textGrey
                : att.isCheckedIn
                    ? AppColors.success
                    : AppColors.textHint,
            size: 20,
          );
          final nameBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(employee.fullName, style: AppTextStyles.bodyText),
              if (_isLateArrival(att, provider.shifts))
                Text('Đi muộn', style: AppTextStyles.caption.copyWith(color: AppColors.error)),
              if (att.distanceIn != null)
                Text('📍 ${_formatDistance(att.distanceIn!)}',
                  style: AppTextStyles.caption.copyWith(fontSize: 11)),
            ],
          );
          final chips = <Widget>[
            if (att.checkInTime != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Vào ${att.checkInTime!.hour.toString().padLeft(2, '0')}:${att.checkInTime!.minute.toString().padLeft(2, '0')}',
                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            if (hasCheckOut)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Ra ${att.checkOutTime!.hour.toString().padLeft(2, '0')}:${att.checkOutTime!.minute.toString().padLeft(2, '0')}',
                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            if (workingTime != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.infoLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  workingTime,
                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.info),
                ),
              ),
          ];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: isMobile ? 10 : 12),
            decoration: BoxDecoration(
              color: hasCheckOut
                  ? AppColors.surfaceVariant
                  : att.isCheckedIn
                      ? AppColors.successLight
                      : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          statusIcon,
                          const SizedBox(width: 10),
                          Expanded(child: nameBlock),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: chips,
                            ),
                          ),
                          _buildAttendanceActions(att, provider),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      statusIcon,
                      const SizedBox(width: 10),
                      Expanded(child: nameBlock),
                      ...chips.map((c) => Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: c,
                          )),
                      const SizedBox(width: 4),
                      _buildAttendanceActions(att, provider),
                    ],
                  ),
          );
        }),
      ],
    );
  }

  Widget _buildAttendanceActions(Attendance att, EmployeeProvider provider, {DateTime? historyDate}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _showEditAttendanceDialog(att, provider, historyDate: historyDate),
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.edit_outlined, size: 18, color: AppColors.info),
          ),
        ),
        InkWell(
          onTap: () => _confirmDeleteAttendance(att, provider, historyDate: historyDate),
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
          ),
        ),
      ],
    );
  }

  Future<void> _showEditAttendanceDialog(
    Attendance att,
    EmployeeProvider provider, {
    DateTime? historyDate,
  }) async {
    TimeOfDay? checkIn = att.checkInTime != null
        ? TimeOfDay(hour: att.checkInTime!.hour, minute: att.checkInTime!.minute)
        : null;
    TimeOfDay? checkOut = att.checkOutTime != null
        ? TimeOfDay(hour: att.checkOutTime!.hour, minute: att.checkOutTime!.minute)
        : null;
    String fmt(TimeOfDay? t) => t == null
        ? '--:--'
        : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Sửa chấm công'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.login_rounded, color: AppColors.success),
                title: const Text('Giờ vào'),
                subtitle: Text(fmt(checkIn)),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    if (checkIn != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: 'Xoá giờ vào',
                        onPressed: () => setSt(() => checkIn = null),
                      ),
                    IconButton(
                      icon: const Icon(Icons.access_time_rounded),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: checkIn ?? TimeOfDay.now(),
                        );
                        if (picked != null) setSt(() => checkIn = picked);
                      },
                    ),
                  ],
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout_rounded, color: AppColors.info),
                title: const Text('Giờ ra'),
                subtitle: Text(fmt(checkOut)),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    if (checkOut != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: 'Xoá giờ ra',
                        onPressed: () => setSt(() => checkOut = null),
                      ),
                    IconButton(
                      icon: const Icon(Icons.access_time_rounded),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: checkOut ?? TimeOfDay.now(),
                        );
                        if (picked != null) setSt(() => checkOut = picked);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu')),
          ],
        ),
      ),
    );

    if (saved != true) return;

    final origIn = att.checkInTime;
    final origOut = att.checkOutTime;
    final newIn = checkIn == null
        ? null
        : DateTime(att.date.year, att.date.month, att.date.day,
            checkIn!.hour, checkIn!.minute);
    final newOut = checkOut == null
        ? null
        : DateTime(att.date.year, att.date.month, att.date.day,
            checkOut!.hour, checkOut!.minute);

    final inChanged = (origIn?.hour != newIn?.hour) ||
        (origIn?.minute != newIn?.minute) ||
        ((origIn == null) != (newIn == null));
    final outChanged = (origOut?.hour != newOut?.hour) ||
        (origOut?.minute != newOut?.minute) ||
        ((origOut == null) != (newOut == null));

    if (!inChanged && !outChanged) return;

    final ok = await provider.updateAttendance(
      att.id,
      checkInTime: inChanged ? newIn : null,
      checkOutTime: outChanged ? newOut : null,
      clearCheckIn: inChanged && newIn == null,
      clearCheckOut: outChanged && newOut == null,
      historyDate: historyDate,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Đã cập nhật chấm công' : 'Cập nhật thất bại')),
    );
  }

  Future<void> _confirmDeleteAttendance(
    Attendance att,
    EmployeeProvider provider, {
    DateTime? historyDate,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá chấm công'),
        content: Text('Bạn có chắc muốn xoá bản ghi chấm công của ${att.employeeName ?? "nhân viên này"}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await provider.deleteAttendance(att.id, historyDate: historyDate);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Đã xoá bản ghi' : 'Xoá thất bại')),
    );
  }

  Future<void> _handleGpsCheckIn(EmployeeProvider provider) async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    setState(() { _isCheckingIn = true; _locationError = null; _lastDistance = null; });
    try {
      final pos = await LocationService.getCurrentPosition();
      // Calculate distance to store
      final stores = context.read<StoreProvider>().stores;
      final myStore = (currentUser.storeCode != null && stores.isNotEmpty)
          ? stores.cast<dynamic>().firstWhere((s) => s.storeCode == currentUser.storeCode, orElse: () => null)
          : null;
      if (myStore != null && myStore.latitude != null && myStore.longitude != null) {
        _lastDistance = LocationService.distanceMeters(
          pos.latitude, pos.longitude,
          myStore.latitude!, myStore.longitude!,
        );
      }
      // Block check-in if more than 50m from store
      if (_lastDistance != null && _lastDistance! > 50) {
        setState(() {
          _locationError = 'Quá xa cửa hàng! Khoảng cách: ${_formatDistance(_lastDistance!)} (giới hạn 50m).';
        });
        return;
      }
      await provider.checkIn(currentUser.id, latitude: pos.latitude, longitude: pos.longitude);
      await provider.loadMonthlySummary(employeeId: currentUser.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chấm công vào thành công!${_lastDistance != null ? ' (${_formatDistance(_lastDistance!)})' : ''}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      setState(() => _locationError = e.toString());
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }

  Future<void> _handleGpsCheckOut(EmployeeProvider provider) async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    setState(() { _isCheckingIn = true; _locationError = null; _lastDistance = null; });
    try {
      final pos = await LocationService.getCurrentPosition();
      final stores = context.read<StoreProvider>().stores;
      final myStore = (currentUser.storeCode != null && stores.isNotEmpty)
          ? stores.cast<dynamic>().firstWhere((s) => s.storeCode == currentUser.storeCode, orElse: () => null)
          : null;
      if (myStore != null && myStore.latitude != null && myStore.longitude != null) {
        _lastDistance = LocationService.distanceMeters(
          pos.latitude, pos.longitude,
          myStore.latitude!, myStore.longitude!,
        );
      }
      // Block check-out if more than 50m from store
      if (_lastDistance != null && _lastDistance! > 50) {
        setState(() {
          _locationError = 'Quá xa cửa hàng! Khoảng cách: ${_formatDistance(_lastDistance!)} (giới hạn 50m).';
        });
        return;
      }
      await provider.checkOut(currentUser.id, latitude: pos.latitude, longitude: pos.longitude);
      await provider.loadMonthlySummary(employeeId: currentUser.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chấm công ra thành công!${_lastDistance != null ? ' (${_formatDistance(_lastDistance!)})' : ''}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      setState(() => _locationError = e.toString());
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  bool _isLateArrival(Attendance att, List<WorkShift> shifts) {
    if (att.checkInTime == null || shifts.isEmpty) return false;
    final firstShift = shifts.first;
    final shiftStart = firstShift.startTime;
    final checkIn = TimeOfDay(hour: att.checkInTime!.hour, minute: att.checkInTime!.minute);
    return checkIn.hour > shiftStart.hour ||
        (checkIn.hour == shiftStart.hour && checkIn.minute > shiftStart.minute);
  }

  Widget _buildShiftPanel(EmployeeProvider provider) {
    final permProv = context.read<PermissionProvider>();
    final managedIds = permProv.managedStoreIds.toSet();
    final stores = context
        .read<StoreProvider>()
        .stores
        .where((s) => managedIds.contains(s.id))
        .toList();
    final selectedStoreId = provider.selectedShiftStoreId;
    final canManage = permProv.canManageAttendance;

    return DataPanel(
      title: AppStrings.caLamViec,
      trailing: TextButton(
        onPressed: () => _showAddShiftDialog(provider),
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        child: const Text(AppStrings.themCa),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store selector (visible to managers)
          if (canManage && stores.isNotEmpty) ...[  
            DropdownButtonFormField<String?>(
              value: selectedStoreId,
              decoration: InputDecoration(
                labelText: 'Cửa hàng',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Tất cả cửa hàng')),
                ...stores.map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(s.name),
                    )),
              ],
              onChanged: (v) => provider.loadShifts(storeId: v),
            ),
            const SizedBox(height: 12),
          ],
          ...provider.shifts.map((shift) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.schedule_rounded,
                        size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shift.name,
                            style: AppTextStyles.bodyText
                                .copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(shift.timeRange,
                                style: AppTextStyles.caption),
                            if (shift.storeName != null &&
                                selectedStoreId == null) ...[  
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.infoLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  shift.storeName!,
                                  style: AppTextStyles.caption.copyWith(
                                      color: AppColors.info,
                                      fontSize: 10),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (canManage)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 18, color: AppColors.error),
                      tooltip: 'Xóa ca',
                      onPressed: () async {
                        try {
                          await provider.removeShift(shift.id);
                        } catch (e) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text('Xóa ca thất bại: $e'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                ],
              ),
            );
          }).toList(),
          if (provider.shifts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  selectedStoreId != null
                      ? 'Chưa có ca nào cho cửa hàng này'
                      : 'Chưa có ca làm việc nào',
                  style: AppTextStyles.caption,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRankPanel(EmployeeProvider provider) {
    final ranked = provider.rankedEmployees;

    return DataPanel(
      title: '${AppStrings.bangXepHang} 🔥',
      child: Column(
        children: ranked.take(20).map((emp) {
          return RankListTile(
            rank: emp.rank,
            name: emp.fullName,
            score: emp.score,
            onTap: () {
              Navigator.pushNamed(
                context,
                AppRoutes.employeeDetail,
                arguments: emp,
              );
            },
          );
        }).toList(),
      ),
    );
  }

  void _showAttendanceHistory(EmployeeProvider provider, {bool canManage = false}) {
    DateTime selectedDate = DateTime.now();
    // Load immediately so the dialog shows data on first open instead of
    // waiting for the user to change the date.
    provider.loadAttendancesByDate(selectedDate);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final mq = MediaQuery.of(context);
          final isMobile = mq.size.width < 600;
          final dialogWidth = isMobile ? mq.size.width - 4 : 500.0;
          final dialogHeight = isMobile ? mq.size.height * 0.75 : 400.0;
          return AlertDialog(
            insetPadding: const EdgeInsets.all(2),
            contentPadding: EdgeInsets.fromLTRB(
                isMobile ? 8 : 24, 12, isMobile ? 8 : 24, 8),
            titlePadding: EdgeInsets.fromLTRB(
                isMobile ? 12 : 24, 14, isMobile ? 12 : 24, 0),
            title: const Text('Lịch sử chấm công'),
            content: SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () {
                        setDialogState(() {
                          selectedDate = selectedDate.subtract(const Duration(days: 1));
                        });
                        provider.loadAttendancesByDate(selectedDate);
                      },
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2024),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                            provider.loadAttendancesByDate(picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.center,
                          child: Text(
                            DateFormat('dd/MM/yyyy').format(selectedDate),
                            style: AppTextStyles.sectionHeader,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: selectedDate.isBefore(DateTime.now().subtract(const Duration(days: 1)))
                          ? () {
                              setDialogState(() {
                                selectedDate = selectedDate.add(const Duration(days: 1));
                              });
                              provider.loadAttendancesByDate(selectedDate);
                            }
                          : null,
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: Consumer<EmployeeProvider>(
                    builder: (context, prov, _) {
                      final historyAtts = prov.historyAttendances;
                      if (historyAtts.isEmpty) {
                        return const Center(child: Text('Không có dữ liệu chấm công'));
                      }
                      return ListView.builder(
                        itemCount: historyAtts.length,
                        itemBuilder: (context, index) {
                          final att = historyAtts[index];
                          final emp = prov.employees.firstWhere(
                            (e) => e.id == att.employeeId,
                            orElse: () => prov.employees.first,
                          );
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 4 : 16),
                            leading: Icon(
                              att.checkOutTime != null
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.circle_rounded,
                              color: att.checkOutTime != null ? AppColors.textGrey : AppColors.success,
                              size: 20,
                            ),
                            title: Text(emp.fullName),
                            subtitle: Text(
                              'Vào: ${att.checkInTime != null ? '${att.checkInTime!.hour.toString().padLeft(2, '0')}:${att.checkInTime!.minute.toString().padLeft(2, '0')}' : '--'}'
                              ' | Ra: ${att.checkOutTime != null ? '${att.checkOutTime!.hour.toString().padLeft(2, '0')}:${att.checkOutTime!.minute.toString().padLeft(2, '0')}' : '--'}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isLateArrival(att, prov.shifts))
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.errorLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('Muộn', style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                                  ),
                                if (canManage)
                                  _buildAttendanceActions(att, prov, historyDate: selectedDate),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
          ],
        );
        },
      ),
    );
  }

  void _showAddShiftDialog(EmployeeProvider provider) {
    final nameCtrl = TextEditingController();
    TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);
    final managedIds = context.read<PermissionProvider>().managedStoreIds.toSet();
    final stores = context
        .read<StoreProvider>()
        .stores
        .where((s) => managedIds.contains(s.id))
        .toList();
    String? selectedStoreId = provider.selectedShiftStoreId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm ca làm việc'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên ca',
                  hintText: 'VD: Ca tối',
                ),
              ),
              const SizedBox(height: 12),
              if (stores.isNotEmpty)
                DropdownButtonFormField<String?>(
                  decoration: const InputDecoration(labelText: 'Cửa hàng'),
                  value: selectedStoreId,
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Không chọn')),
                    ...stores.map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name),
                        )),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => selectedStoreId = v),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: startTime,
                        );
                        if (picked != null) {
                          setDialogState(() => startTime = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Giờ bắt đầu'),
                        child: Text('${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: endTime,
                        );
                        if (picked != null) {
                          setDialogState(() => endTime = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Giờ kết thúc'),
                        child: Text('${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty) {
                  try {
                    await provider.addShift(WorkShift(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameCtrl.text,
                      startTime: startTime,
                      endTime: endTime,
                      storeId: selectedStoreId,
                    ));
                    if (ctx.mounted) Navigator.pop(ctx);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('Đã thêm ca "${nameCtrl.text}"'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.success,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  } catch (e) {
                    if (ctx.mounted) Navigator.pop(ctx);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('Thêm ca thất bại: $e'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                }
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- WORK SCHEDULE WIDGETS (extension) ----
extension _NhanSuScheduleWidgets on _NhanSuScreenState {
  String _weekLabel(DateTime weekStart) {
    final end = weekStart.add(const Duration(days: 6));
    return '${weekStart.day}/${weekStart.month} - ${end.day}/${end.month}/${end.year}';
  }

  Widget _buildSchedulePanel(EmployeeProvider provider, bool canManage) {
    return DataPanel(
      title: 'Lịch làm việc',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            tooltip: 'Tuần trước',
            onPressed: () {
              final prev = provider.scheduleWeekStart.subtract(const Duration(days: 7));
              provider.loadSchedules(weekStart: prev);
            },
          ),
          Text(
            _weekLabel(provider.scheduleWeekStart),
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            tooltip: 'Tuần sau',
            onPressed: () {
              final next = provider.scheduleWeekStart.add(const Duration(days: 7));
              provider.loadSchedules(weekStart: next);
            },
          ),
        ],
      ),
      child: _buildWeekGrid(provider, canManage),
    );
  }

  Widget _buildWeekGrid(EmployeeProvider provider, bool canManage) {
    final weekStart = provider.scheduleWeekStart;
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    const dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final now = DateTime.now();

    return Column(
      children: List.generate(7, (i) {
        final day = days[i];
        final isToday =
            day.year == now.year && day.month == now.month && day.day == now.day;
        final daySchedules = provider.schedules
            .where((s) =>
                s.workDate.year == day.year &&
                s.workDate.month == day.month &&
                s.workDate.day == day.day)
            .toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isToday ? AppColors.primaryLight : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: isToday
                ? Border.all(color: AppColors.primary.withValues(alpha: 0.35))
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    Text(
                      dayLabels[i],
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isToday ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${day.day}/${day.month}',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: AppColors.border,
                margin: const EdgeInsets.symmetric(horizontal: 10),
              ),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ...daySchedules.map(
                        (s) => _buildScheduleChip(s, canManage, provider)),
                    if (canManage)
                      InkWell(
                        onTap: () => _showAssignShiftDialog(provider, day),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.borderLight),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded,
                                  size: 13, color: AppColors.textHint),
                              const SizedBox(width: 3),
                              Text(
                                'Thêm',
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textHint, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (daySchedules.isEmpty && !canManage)
                      Text(
                        'Chưa có lịch',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textHint),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildScheduleChip(
      WorkSchedule schedule, bool canManage, EmployeeProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${schedule.employeeName ?? '?'} · ${schedule.shiftName ?? ''}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.info,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          if (schedule.startHour != null) ...[
            const SizedBox(width: 4),
            Text(
              schedule.timeRange,
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.info, fontSize: 10),
            ),
          ],
          if (canManage) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: () async {
                try {
                  await provider.removeSchedule(schedule.id);
                } catch (e) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Xóa lịch thất bại: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Icon(Icons.close_rounded, size: 13, color: AppColors.info),
            ),
          ],
        ],
      ),
    );
  }

  void _showAssignShiftDialog(EmployeeProvider provider, DateTime day) {
    String? selectedEmployeeId;
    String? selectedShiftId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Phân ca ${day.day}/${day.month}/${day.year}'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration:
                      const InputDecoration(labelText: 'Nhân viên'),
                  value: selectedEmployeeId,
                  isExpanded: true,
                  items: provider.employees
                      .map((e) =>
                          DropdownMenuItem(value: e.id, child: Text(e.fullName)))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedEmployeeId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration:
                      const InputDecoration(labelText: 'Ca làm việc'),
                  value: selectedShiftId,
                  isExpanded: true,
                  items: provider.shifts
                      .map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text('${s.name} (${s.timeRange})'),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedShiftId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: (selectedEmployeeId != null && selectedShiftId != null)
                  ? () async {
                      try {
                        await provider.addSchedule(
                          employeeId: selectedEmployeeId!,
                          shiftId: selectedShiftId!,
                          workDate: day,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: const Text('Đã phân ca thành công!'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.success,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      } catch (e) {
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text('Phân ca thất bại: $e'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    }
                  : null,
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
