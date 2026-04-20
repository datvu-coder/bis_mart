import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/employee_provider.dart';
import '../../models/attendance.dart';
import '../../models/work_shift.dart';
import '../../widgets/common/data_panel.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/cards/rank_list_tile.dart';

class NhanSuScreen extends StatefulWidget {
  const NhanSuScreen({super.key});

  @override
  State<NhanSuScreen> createState() => _NhanSuScreenState();
}

class _NhanSuScreenState extends State<NhanSuScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<EmployeeProvider>();
      provider.loadEmployees();
      provider.loadAttendances();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

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
                    Expanded(child: _buildAttendancePanel(provider)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildShiftPanel(provider)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildRankPanel(provider)),
                  ],
                )
              else ...[
                _buildAttendancePanel(provider),
                _buildShiftPanel(provider),
                _buildRankPanel(provider),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttendancePanel(EmployeeProvider provider) {
    return DataPanel(
      title: AppStrings.chamCong,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            onPressed: () => _showCheckInDialog(provider),
            icon: const Icon(Icons.fingerprint_rounded, size: 18),
            label: const Text(AppStrings.chamCong),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _showCheckOutDialog(provider),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Check-out'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _showAttendanceHistory(provider),
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Lịch sử chấm công',
          ),
        ],
      ),
      child: provider.employees.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Chưa có dữ liệu nhân viên'),
            )
          : Column(
        children: provider.attendances.map((att) {
          final employee = provider.employees.firstWhere(
            (e) => e.id == att.employeeId,
            orElse: () => provider.employees.first,
          );
          final hasCheckOut = att.checkOutTime != null;
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
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Ra ${att.checkOutTime!.hour.toString().padLeft(2, '0')}:${att.checkOutTime!.minute.toString().padLeft(2, '0')}',
                      style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
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
