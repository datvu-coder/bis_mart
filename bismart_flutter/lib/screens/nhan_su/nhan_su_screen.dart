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
import '../../providers/lms_provider.dart';
import '../../models/attendance.dart';
import '../../models/work_shift.dart';
import '../../models/permission.dart';
import '../../services/location_service.dart';
import '../../widgets/common/data_panel.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/cards/rank_list_tile.dart';

class NhanSuScreen extends StatefulWidget {
  const NhanSuScreen({super.key});

  @override
  State<NhanSuScreen> createState() => _NhanSuScreenState();
}

class _NhanSuScreenState extends State<NhanSuScreen> {
  bool _isCheckingIn = false;
  String? _locationError;
  double? _lastDistance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<EmployeeProvider>();
      final currentUser = context.read<AuthProvider>().currentUser;
      provider.loadEmployees();
      provider.loadAttendances();
      // Load monthly summary for current user only
      provider.loadMonthlySummary(employeeId: currentUser?.id);
      context.read<StoreProvider>().loadStores();
      // Load permissions for current user's position
      if (currentUser != null) {
        context.read<LmsProvider>().loadPermissionForPosition(currentUser.position);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    final perm = context.watch<LmsProvider>().currentPermission;
    final canManage = perm?.canManageAttendance ?? false;

    return Consumer<EmployeeProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.employees.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(isWide ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(AppStrings.nhanSu, style: AppTextStyles.appTitle),
              const SizedBox(height: 4),
              Text(
                'Quản lý nhân viên, chấm công & xếp hạng',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 20),

              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildAttendancePanel(provider, canManage)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildShiftPanel(provider)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildRankPanel(provider)),
                  ],
                )
              else ...[
                _buildAttendancePanel(provider, canManage),
                _buildShiftPanel(provider),
                _buildRankPanel(provider),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttendancePanel(EmployeeProvider provider, bool canManage) {
    return DataPanel(
      title: AppStrings.chamCong,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _showAttendanceHistory(provider),
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Lịch sử chấm công',
          ),
        ],
      ),
      child: Column(
        children: [
          // --- GPS Check-in/out Section ---
          _buildGpsCheckInSection(provider, canManage),
          const SizedBox(height: 16),
          // --- Monthly Summary ---
          _buildMonthlySummary(provider),
          const SizedBox(height: 16),
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

    return Container(
      padding: const EdgeInsets.all(16),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasCheckedOut
              ? AppColors.border
              : hasCheckedIn
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.primary.withValues(alpha: 0.3),
        ),
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
            Row(
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
              Row(
                children: [
                  Icon(Icons.location_on_rounded, size: 14, color: AppColors.textGrey),
                  const SizedBox(width: 4),
                  Text(
                    'Khoảng cách vào: ${_formatDistance(todayAtt.first.distanceIn!)}',
                    style: AppTextStyles.caption,
                  ),
                  if (todayAtt.first.distanceOut != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      'Ra: ${_formatDistance(todayAtt.first.distanceOut!)}',
                      style: AppTextStyles.caption,
                    ),
                  ],
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
                color: _lastDistance! <= 500 ? AppColors.successLight : AppColors.warningLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _lastDistance! <= 500 ? Icons.check_circle_rounded : Icons.warning_rounded,
                    size: 16,
                    color: _lastDistance! <= 500 ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Khoảng cách: ${_formatDistance(_lastDistance!)}',
                    style: AppTextStyles.caption.copyWith(
                      color: _lastDistance! <= 500 ? AppColors.success : AppColors.warning,
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
                    label: Text(_isCheckingIn ? 'Đang xác định vị trí...' : 'Chấm công vào'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                    label: Text(_isCheckingIn ? 'Đang xác định vị trí...' : 'Chấm công ra'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              if (hasCheckedOut)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                        const SizedBox(width: 8),
                        Text('Đã hoàn thành chấm công hôm nay',
                          style: AppTextStyles.bodyText.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              // Admin quick check-in button (only for managers)
              if (canManage)
                PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'Chấm công nhân viên',
                onSelected: (value) {
                  if (value == 'checkin') _showCheckInDialog(provider);
                  if (value == 'checkout') _showCheckOutDialog(provider);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'checkin', child: Text('Check-in nhân viên')),
                  const PopupMenuItem(value: 'checkout', child: Text('Check-out nhân viên')),
                ],
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
                Text(
                  time != null
                      ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                      : '--:--',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
                ),
              ],
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
        children: [
          const Icon(Icons.timer_rounded, size: 16, color: AppColors.info),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Làm việc', style: AppTextStyles.caption.copyWith(fontSize: 10)),
              Text('${hours}h${minutes.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.info)),
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

    return Container(
      padding: const EdgeInsets.all(14),
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
          final employee = provider.employees.firstWhere(
            (e) => e.id == att.employeeId,
            orElse: () => provider.employees.first,
          );
          final hasCheckOut = att.checkOutTime != null;
          String? workingTime;
          if (hasCheckOut && att.checkInTime != null) {
            final diff = att.checkOutTime!.difference(att.checkInTime!);
            workingTime = '${diff.inHours}h${(diff.inMinutes % 60).toString().padLeft(2, '0')}';
          }
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: hasCheckOut
                  ? AppColors.surfaceVariant
                  : att.isCheckedIn
                      ? AppColors.successLight
                      : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
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
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(employee.fullName, style: AppTextStyles.bodyText),
                      if (_isLateArrival(att, provider.shifts))
                        Text('Đi muộn', style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                      if (att.distanceIn != null)
                        Text('📍 ${_formatDistance(att.distanceIn!)}',
                          style: AppTextStyles.caption.copyWith(fontSize: 11)),
                    ],
                  ),
                ),
                if (att.checkInTime != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.only(right: 4),
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
                    margin: const EdgeInsets.only(right: 4),
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
              ],
            ),
          );
        }),
      ],
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
    return DataPanel(
      title: AppStrings.caLamViec,
      trailing: TextButton.icon(
        onPressed: () => _showAddShiftDialog(provider),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text(AppStrings.themCa),
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      child: Column(
        children: provider.shifts.map((shift) {
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
                  child: const Icon(Icons.schedule_rounded, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shift.name, style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(shift.timeRange, style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
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

  void _showCheckInDialog(EmployeeProvider provider) {
    final unchecked = provider.employees.where((e) {
      return !provider.attendances.any((a) =>
          a.employeeId == e.id &&
          a.isCheckedIn &&
          a.date.year == DateTime.now().year &&
          a.date.month == DateTime.now().month &&
          a.date.day == DateTime.now().day);
    }).toList();

    if (unchecked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tất cả nhân viên đã chấm công hôm nay!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chấm công nhân viên'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: ListView.builder(
            itemCount: unchecked.length,
            itemBuilder: (context, index) {
              final emp = unchecked[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    emp.fullName[0].toUpperCase(),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(emp.fullName),
                subtitle: Text('${emp.employeeCode} · ${emp.positionLabel}'),
                trailing: IconButton(
                  icon: const Icon(Icons.check_circle_rounded, color: AppColors.success),
                  onPressed: () async {
                    await provider.checkIn(emp.id);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Đã chấm công cho ${emp.fullName}!'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.success,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showCheckOutDialog(EmployeeProvider provider) {
    final checkedIn = provider.attendances.where((a) =>
        a.isCheckedIn &&
        a.checkOutTime == null &&
        a.date.year == DateTime.now().year &&
        a.date.month == DateTime.now().month &&
        a.date.day == DateTime.now().day).toList();

    if (checkedIn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Không có nhân viên nào cần check-out!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check-out nhân viên'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: ListView.builder(
            itemCount: checkedIn.length,
            itemBuilder: (context, index) {
              final att = checkedIn[index];
              final emp = provider.employees.firstWhere(
                (e) => e.id == att.employeeId,
                orElse: () => provider.employees.first,
              );
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.successLight,
                  child: Text(
                    emp.fullName[0].toUpperCase(),
                    style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(emp.fullName),
                subtitle: Text('Vào lúc ${att.checkInTime!.hour.toString().padLeft(2, '0')}:${att.checkInTime!.minute.toString().padLeft(2, '0')}'),
                trailing: IconButton(
                  icon: const Icon(Icons.logout_rounded, color: AppColors.warning),
                  onPressed: () async {
                    await provider.checkOut(att.employeeId);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('Đã check-out cho ${emp.fullName}!'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.success,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showAttendanceHistory(EmployeeProvider provider) {
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Lịch sử chấm công'),
          content: SizedBox(
            width: 500,
            height: 400,
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
                            trailing: _isLateArrival(att, prov.shifts)
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.errorLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('Muộn', style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                                  )
                                : null,
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
        ),
      ),
    );
  }

  void _showAddShiftDialog(EmployeeProvider provider) {
    final nameCtrl = TextEditingController();
    TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);

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
              const SizedBox(height: 16),
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
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  provider.addShift(WorkShift(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameCtrl.text,
                    startTime: startTime,
                    endTime: endTime,
                  ));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Đã thêm ca "${nameCtrl.text}"'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
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
