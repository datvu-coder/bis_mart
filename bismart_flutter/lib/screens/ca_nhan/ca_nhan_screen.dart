import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/lms_provider.dart';
import '../../models/employee.dart';

class CaNhanScreen extends StatefulWidget {
  const CaNhanScreen({super.key});

  @override
  State<CaNhanScreen> createState() => _CaNhanScreenState();
}

class _CaNhanScreenState extends State<CaNhanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = context.read<AuthProvider>().currentUser;
      if (currentUser != null) {
        context.read<LmsProvider>().loadPermissionForPosition(currentUser.position);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    final user = context.watch<AuthProvider>().currentUser;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 24 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppStrings.caNhan, style: AppTextStyles.appTitle),
              const SizedBox(height: 4),
              Text('Thông tin cá nhân & quản lý', style: AppTextStyles.caption),
              const SizedBox(height: 24),

              // Profile header card
              _buildProfileCard(context, user),
              const SizedBox(height: 20),

              // Quick stats row
              _buildStatsRow(user),
              const SizedBox(height: 20),

              // Menu items
              _buildMenuSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, dynamic user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2.5,
              ),
            ),
            child: Center(
              child: Text(
                user?.fullName?.isNotEmpty == true
                    ? user!.fullName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppStrings.xinChao},',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.fullName ?? 'Người dùng',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        user?.positionLabel ?? user?.position ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        user?.employeeCode ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showEditProfileDialog(context, user),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.edit_rounded, color: AppColors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(dynamic user) {
    final empProvider = context.watch<EmployeeProvider>();
    final employees = empProvider.employees;
    // Find the current user in the employee list by matching ID
    final currentEmp = (user != null && employees.isNotEmpty)
        ? employees.cast<dynamic>().firstWhere(
            (e) => e.id == user.id,
            orElse: () => null,
          )
        : null;

    final stats = [
      _StatItem(Icons.people_rounded, 'Nhân viên', '${employees.length}', AppColors.info, AppColors.infoLight),
      _StatItem(Icons.star_rounded, 'Điểm KPI', '${currentEmp?.score ?? user?.score ?? 0}', AppColors.warning, AppColors.warningLight),
      _StatItem(Icons.trending_up_rounded, 'Xếp hạng', '#${currentEmp?.rank ?? '-'}', AppColors.success, AppColors.successLight),
    ];

    return Row(
      children: stats
          .map((s) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: s == stats.last ? 0 : 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    decoration: AppDecorations.card,
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: s.bgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(s.icon, color: s.color, size: 20),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.value,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(s.label, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    final perm = context.watch<LmsProvider>().currentPermission;
    final menuItems = <_MenuItem>[
      if (perm?.canEmployees ?? true)
        _MenuItem(Icons.people_rounded, AppStrings.danhSachNhanVien, 'Xem danh sách & thông tin nhân viên', AppRoutes.employeeList, AppColors.info, AppColors.infoLight),
      if (perm?.canAttendance ?? true)
        _MenuItem(Icons.fingerprint_rounded, AppStrings.quanLyChamCong, 'Chấm công, ca làm & xếp hạng', AppRoutes.nhanSu, AppColors.success, AppColors.successLight),
      if (perm?.canReport ?? true)
        _MenuItem(Icons.bar_chart_rounded, AppStrings.quanLyBaoCao, 'Báo cáo doanh thu & thống kê', AppRoutes.kinhDoanh, AppColors.warning, AppColors.warningLight),
      if (perm?.canStoreList ?? true)
        _MenuItem(Icons.store_rounded, AppStrings.danhSachCuaHang, 'Danh sách cửa hàng trong hệ thống', AppRoutes.storeList, AppColors.primary, AppColors.primaryLight),
      if (perm?.canProductList ?? true)
        _MenuItem(Icons.inventory_2_rounded, AppStrings.danhSachSanPham, 'Quản lý sản phẩm & tồn kho', AppRoutes.productList, AppColors.error, AppColors.errorLight),
    ];

    return Container(
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
            child: Text('Quản lý', style: AppTextStyles.sectionHeader),
          ),
          ...menuItems.map((item) => _buildMenuItem(context, item)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, _MenuItem item) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, item.route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: item.bgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTextStyles.bodyTextMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, dynamic user) {
    final nameCtrl = TextEditingController(text: user?.fullName ?? '');
    final emailCtrl = TextEditingController(text: user?.email ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chỉnh sửa hồ sơ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Họ tên')),
            const SizedBox(height: 8),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              context.read<AuthProvider>().updateProfile(
                fullName: nameCtrl.text,
                email: emailCtrl.text.isNotEmpty ? emailCtrl.text : null,
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Đã cập nhật hồ sơ!'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bgColor;

  const _StatItem(this.icon, this.label, this.value, this.color, this.bgColor);
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final Color color;
  final Color bgColor;

  const _MenuItem(this.icon, this.title, this.subtitle, this.route, this.color, this.bgColor);
}
