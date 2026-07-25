import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/leave_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/permission_provider.dart';
import '../../widgets/common/gradient_fab.dart';
import '../../widgets/common/responsive_form.dart';

const _kLeaveTypes = ['Nghỉ phép năm', 'Nghỉ ốm', 'Nghỉ không lương', 'Khác'];

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Self-service leave requests: anyone can file one for themselves, a
/// manager (canManageAttendance) sees every request for their store and
/// can approve/reject; the requester can cancel their own while pending.
class LeaveRequestsScreen extends StatefulWidget {
  const LeaveRequestsScreen({super.key});

  @override
  State<LeaveRequestsScreen> createState() => _LeaveRequestsScreenState();
}

class _LeaveRequestsScreenState extends State<LeaveRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = context.read<AuthProvider>().currentUser;
      context.read<EmployeeProvider>().loadLeaveRequests(storeCode: currentUser?.storeCode);
    });
  }

  void _showRequestDialog() {
    DateTime? startDate;
    DateTime? endDate;
    String leaveType = _kLeaveTypes.first;
    final reasonCtrl = TextEditingController();
    bool saving = false;

    showResponsiveForm(
      context: context,
      title: 'Xin nghỉ phép',
      contentBuilder: (ctx, setDialogState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: startDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        startDate = picked;
                        if (endDate != null && endDate!.isBefore(picked)) endDate = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Từ ngày'),
                    child: Text(startDate != null ? _fmtDate(startDate!) : 'Chọn ngày'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: endDate ?? startDate ?? DateTime.now(),
                      firstDate: startDate ?? DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setDialogState(() => endDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Đến ngày'),
                    child: Text(endDate != null ? _fmtDate(endDate!) : 'Chọn ngày'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: leaveType,
            decoration: const InputDecoration(labelText: 'Loại nghỉ'),
            items: _kLeaveTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setDialogState(() => leaveType = v ?? leaveType),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: reasonCtrl,
            decoration: const InputDecoration(labelText: 'Lý do (tùy chọn)'),
            maxLines: 2,
          ),
        ],
      ),
      actionsBuilder: (ctx, setDialogState) => [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(ctx),
          child: const Text('Huỷ'),
        ),
        ElevatedButton(
          onPressed: saving
              ? null
              : () async {
                  if (startDate == null || endDate == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng chọn ngày bắt đầu và kết thúc'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  setDialogState(() => saving = true);
                  final provider = context.read<EmployeeProvider>();
                  final ok = await provider.submitLeaveRequest(
                    startDate: startDate!,
                    endDate: endDate!,
                    leaveType: leaveType,
                    reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
                  );
                  if (!ctx.mounted) return;
                  if (ok) {
                    Navigator.pop(ctx);
                  } else {
                    setDialogState(() => saving = false);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(provider.error ?? 'Gửi đơn thất bại'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
          child: Text(saving ? 'Đang gửi...' : 'Gửi đơn'),
        ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Đã duyệt';
      case 'rejected':
        return 'Từ chối';
      default:
        return 'Chờ duyệt';
    }
  }

  Future<void> _confirmCancel(LeaveRequest r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Huỷ đơn nghỉ phép'),
        content: const Text('Bạn có chắc muốn huỷ đơn nghỉ phép này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Huỷ đơn'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await context.read<EmployeeProvider>().cancelLeaveRequest(r.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Đã huỷ đơn' : 'Huỷ đơn thất bại'), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _decide(LeaveRequest r, bool approve) async {
    final provider = context.read<EmployeeProvider>();
    final ok = approve ? await provider.approveLeaveRequest(r.id) : await provider.rejectLeaveRequest(r.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? (approve ? 'Đã duyệt đơn' : 'Đã từ chối đơn') : 'Cập nhật thất bại'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canManage = context.watch<PermissionProvider>().canManageAttendance;
    final myEmployeeId = context.watch<AuthProvider>().currentUser?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Nghỉ phép')),
      floatingActionButton: GradientFab(
        icon: Icons.add_rounded,
        tooltip: 'Xin nghỉ phép',
        onPressed: _showRequestDialog,
      ),
      body: Consumer<EmployeeProvider>(
        builder: (context, provider, _) {
          final requests = provider.leaveRequests;
          if (requests.isEmpty) {
            return Center(
              child: Text('Chưa có đơn nghỉ phép nào', style: AppTextStyles.caption),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 84),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = requests[i];
              final isOwner = myEmployeeId != null && r.employeeId == myEmployeeId;
              final isPending = r.status == 'pending';
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: AppDecorations.card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            canManage ? (r.employeeName ?? '') : r.leaveType,
                            style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _statusColor(r.status).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _statusLabel(r.status),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor(r.status)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (canManage) Text(r.leaveType, style: AppTextStyles.caption),
                    Text(
                      '${_fmtDate(r.startDate)} - ${_fmtDate(r.endDate)} · ${r.dayCount} ngày',
                      style: AppTextStyles.caption,
                    ),
                    if (r.reason != null && r.reason!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(r.reason!, style: AppTextStyles.caption),
                    ],
                    if (isPending && (canManage || isOwner)) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (canManage) ...[
                            TextButton(
                              onPressed: () => _decide(r, false),
                              style: TextButton.styleFrom(foregroundColor: AppColors.error),
                              child: const Text('Từ chối'),
                            ),
                            const SizedBox(width: 6),
                            ElevatedButton(
                              onPressed: () => _decide(r, true),
                              child: const Text('Duyệt'),
                            ),
                          ] else if (isOwner)
                            TextButton(
                              onPressed: () => _confirmCancel(r),
                              style: TextButton.styleFrom(foregroundColor: AppColors.error),
                              child: const Text('Huỷ đơn'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
