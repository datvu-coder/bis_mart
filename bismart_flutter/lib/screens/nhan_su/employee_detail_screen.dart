import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/employee.dart';
import '../../providers/employee_provider.dart';
import '../../providers/store_provider.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final Employee employee;

  const EmployeeDetailScreen({super.key, required this.employee});

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  late Employee _employee;

  @override
  void initState() {
    super.initState();
    _employee = widget.employee;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreProvider>().loadStores();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chi tiết nhân viên'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => _showEditDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: () => _confirmDelete(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        _employee.fullName.isNotEmpty
                            ? _employee.fullName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _employee.fullName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _employee.positionLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StatBadge(label: 'Điểm', value: '${_employee.score}'),
                      const SizedBox(width: 12),
                      _StatBadge(label: 'Xếp hạng', value: '#${_employee.rank}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Thông tin công tác
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thông tin công tác',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _infoRow(Icons.badge_outlined, 'Mã nhân viên', _employee.employeeCode),
                  _infoRow(Icons.work_outline_rounded, 'Vị trí', _employee.positionLabel),
                  if (_employee.department != null && _employee.department!.isNotEmpty)
                    _infoRow(Icons.business, 'Phòng ban', _employee.department!),
                  if (_employee.status != null && _employee.status!.isNotEmpty)
                    _infoRow(Icons.info_outline, 'Trạng thái', _employee.status!),
                  if (_employee.storeCode != null && _employee.storeCode!.isNotEmpty)
                    _infoRow(Icons.store_rounded, 'Cửa hàng', _employee.storeCode!),
                  if (_employee.rankLevel != null && _employee.rankLevel!.isNotEmpty)
                    _infoRow(Icons.emoji_events, 'Cấp độ', _employee.rankLevel!),
                  _infoRow(Icons.location_on_outlined, 'Nơi làm việc', _employee.workLocation),
                  if (_employee.province != null && _employee.province!.isNotEmpty)
                    _infoRow(Icons.map_outlined, 'Tỉnh/TP', _employee.province!),
                  if (_employee.area != null && _employee.area!.isNotEmpty)
                    _infoRow(Icons.place, 'Khu vực', _employee.area!),
                ],
              ),
            ),

            // Thông tin cá nhân
            if (_employee.phone != null || _employee.email != null ||
                _employee.dateOfBirth != null || _employee.cccd != null ||
                _employee.address != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thông tin cá nhân',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_employee.phone != null && _employee.phone!.isNotEmpty)
                      _infoRow(Icons.phone_outlined, 'Số điện thoại', _employee.phone!),
                    if (_employee.email != null && _employee.email!.isNotEmpty)
                      _infoRow(Icons.email_outlined, 'Email', _employee.email!),
                    if (_employee.dateOfBirth != null && _employee.dateOfBirth!.isNotEmpty)
                      _infoRow(Icons.cake_outlined, 'Ngày sinh', _employee.dateOfBirth!),
                    if (_employee.cccd != null && _employee.cccd!.isNotEmpty)
                      _infoRow(Icons.credit_card_outlined, 'CCCD', _employee.cccd!),
                    if (_employee.address != null && _employee.address!.isNotEmpty)
                      _infoRow(Icons.home_outlined, 'Địa chỉ', _employee.address!),
                  ],
                ),
              ),
            ],

            // Lịch sử công tác
            if (_employee.createdDate != null || _employee.probationDate != null ||
                _employee.officialDate != null || _employee.resignDate != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lịch sử công tác',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_employee.createdDate != null && _employee.createdDate!.isNotEmpty)
                      _infoRow(Icons.calendar_today_outlined, 'Ngày vào làm', _employee.createdDate!),
                    if (_employee.probationDate != null && _employee.probationDate!.isNotEmpty)
                      _infoRow(Icons.event_note_outlined, 'Thử việc từ', _employee.probationDate!),
                    if (_employee.officialDate != null && _employee.officialDate!.isNotEmpty)
                      _infoRow(Icons.verified_outlined, 'Chính thức từ', _employee.officialDate!),
                    if (_employee.resignDate != null && _employee.resignDate!.isNotEmpty)
                      _infoRow(Icons.logout, 'Ngày nghỉ việc', _employee.resignDate!),
                    if (_employee.resignReason != null && _employee.resignReason!.isNotEmpty)
                      _infoRow(Icons.description_outlined, 'Lý do nghỉ', _employee.resignReason!),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog() {
    final nameCtrl = TextEditingController(text: _employee.fullName);
    final emailCtrl = TextEditingController(text: _employee.email ?? '');
    String selectedPosition = _employee.position;
    String? selectedStoreCode = _employee.storeCode;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final stores = this.context.watch<StoreProvider>().stores;
          return AlertDialog(
            title: const Text('Chỉnh sửa nhân viên'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Họ tên'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedStoreCode,
                    decoration: const InputDecoration(labelText: 'Mã cửa hàng (nơi làm việc)'),
                    items: stores
                        .map((s) => DropdownMenuItem(
                              value: s.storeCode,
                              child: Text('${s.storeCode} - ${s.name}'),
                            ))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedStoreCode = v),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedPosition,
                    decoration: const InputDecoration(labelText: 'Vị trí'),
                    items: ['ADM', 'PG', 'TLD', 'MNG', 'CS']
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedPosition = v!),
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
                onPressed: () {
                  final selectedStore = stores.cast<dynamic>().firstWhere(
                    (s) => s.storeCode == selectedStoreCode,
                    orElse: () => null,
                  );
                  final updated = _employee.copyWith(
                    fullName: nameCtrl.text,
                    position: selectedPosition,
                    workLocation: selectedStore?.name ?? '',
                    storeCode: selectedStoreCode,
                    email: emailCtrl.text.isNotEmpty ? emailCtrl.text : null,
                  );
                  this.context.read<EmployeeProvider>().updateEmployee(updated);
                  setState(() => _employee = updated);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: const Text('Đã cập nhật thông tin!'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
                child: const Text('Lưu'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa nhân viên'),
        content: Text('Bạn có chắc muốn xóa "${_employee.fullName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<EmployeeProvider>().deleteEmployee(_employee.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Đã xóa nhân viên!'),
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

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  const _StatBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.white)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}
