import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/permission_provider.dart';
import '../../providers/store_provider.dart';
import '../../models/employee.dart';
import '../../models/store.dart';
import '../../services/api_service.dart';

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
        context.read<PermissionProvider>().resolveForUser(currentUser);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 800;
    final isDesktop = width >= 1100;
    final user = context.watch<AuthProvider>().currentUser;

    if (isDesktop) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(AppStrings.caNhan, style: AppTextStyles.appTitle),
                const SizedBox(height: 4),
                Text('Thông tin cá nhân & quản lý', style: AppTextStyles.caption),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildProfileCard(context, user),
                          const SizedBox(height: 20),
                          _buildStatsRow(user),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 7,
                      child: _buildMenuSection(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 24 : 10),
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

  Widget _buildProfileCard(BuildContext context, Employee? user) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
          if (user != null) ...[            
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _showTransferStoreDialog(context, user),
              icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.white),
              label: const Text(
                'Chuyển cửa hàng',
                style: TextStyle(color: AppColors.white, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
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
    final permProv = context.watch<PermissionProvider>();
    final menuItems = <_MenuItem>[
      if (permProv.canEmployees)
        _MenuItem(Icons.people_rounded, AppStrings.danhSachNhanVien, 'Xem danh sách & thông tin nhân viên', AppRoutes.employeeList, AppColors.info, AppColors.infoLight),
      if (permProv.canAttendance)
        _MenuItem(Icons.fingerprint_rounded, AppStrings.quanLyChamCong, 'Chấm công, ca làm & xếp hạng', AppRoutes.nhanSu, AppColors.success, AppColors.successLight),
      if (permProv.canReport)
        _MenuItem(Icons.bar_chart_rounded, AppStrings.quanLyBaoCao, 'Báo cáo doanh thu & thống kê', AppRoutes.kinhDoanh, AppColors.warning, AppColors.warningLight),
      if (permProv.canStoreList)
        _MenuItem(Icons.store_rounded, AppStrings.danhSachCuaHang, 'Danh sách cửa hàng trong hệ thống', AppRoutes.storeList, AppColors.primary, AppColors.primaryLight),
      if (permProv.canProductList)
        _MenuItem(Icons.inventory_2_rounded, AppStrings.danhSachSanPham, 'Quản lý sản phẩm & tồn kho', AppRoutes.productList, AppColors.error, AppColors.errorLight),
      if (permProv.isAdmin || permProv.canCrud)
        _MenuItem(Icons.admin_panel_settings_rounded, 'Phân quyền hệ thống', 'Cấu hình quyền & phân công cửa hàng', AppRoutes.phanQuyen, AppColors.purpleAccent, AppColors.purpleLight),
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

  void _showTransferStoreDialog(BuildContext context, Employee user) {
    final storeProvider = context.read<StoreProvider>();
    if (storeProvider.stores.isEmpty) storeProvider.loadStores();

    String? selectedStoreId;
    String storeQuery = '';
    String selectedRole = 'PG';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) {
          final stores = context.read<StoreProvider>().stores;
          return AlertDialog(
            title: const Text('Chuyển cửa hàng'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${user.fullName} (${user.employeeCode})',
                    style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  Autocomplete<Store>(
                    displayStringForOption: (s) => '${s.name} (${s.storeCode})',
                    optionsBuilder: (textEditingValue) {
                      storeQuery = textEditingValue.text;
                      if (textEditingValue.text.trim().isEmpty) return stores;
                      final query = textEditingValue.text.toLowerCase();
                      return stores.where((s) =>
                          s.name.toLowerCase().contains(query) ||
                          s.storeCode.toLowerCase().contains(query));
                    },
                    onSelected: (s) => setDialogState(() => selectedStoreId = s.id),
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
                        TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          onChanged: (_) => setDialogState(() => selectedStoreId = null),
                          decoration: const InputDecoration(
                            labelText: 'Cửa hàng *',
                            prefixIcon: Icon(Icons.store_rounded, size: 18),
                          ),
                        ),
                    optionsViewBuilder: (context, onSelected, options) => Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(10),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200, maxWidth: 360),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final store = options.elementAt(index);
                              return ListTile(
                                dense: true,
                                title: Text(store.name),
                                subtitle: Text(store.storeCode),
                                onTap: () => onSelected(store),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(labelText: 'Vai trò'),
                    items: ['PG', 'TLD', 'MNG', 'CS', 'ADM']
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedRole = v!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx2),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        Store? store;
                        if (selectedStoreId != null) {
                          try {
                            store = stores.firstWhere((s) => s.id == selectedStoreId);
                          } catch (_) {}
                        }
                        if (store == null && storeQuery.isNotEmpty) {
                          final q = storeQuery.toLowerCase();
                          try {
                            store = stores.firstWhere((s) =>
                                s.name.toLowerCase().contains(q) ||
                                s.storeCode.toLowerCase().contains(q));
                          } catch (_) {}
                        }
                        if (store == null) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: const Text('Vui lòng chọn cửa hàng hợp lệ'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppColors.error,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                          return;
                        }
                        setDialogState(() => isLoading = true);
                        try {
                          await ApiService().createStoreManager({
                            'storeId': store.id,
                            'employeeId': user.id,
                            'storeRole': selectedRole,
                          });
                          if (ctx2.mounted) Navigator.pop(ctx2);
                          if (!mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text('Đã chuyển ${user.fullName} đến ${store.name}!'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppColors.success,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => isLoading = false);
                          if (!mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text('Lỗi: $e'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppColors.error,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      },
                child: isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Chuyển'),
              ),
            ],
          );
        },
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
