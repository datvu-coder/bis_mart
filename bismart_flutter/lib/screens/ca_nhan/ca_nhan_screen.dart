import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
import '../../widgets/common/responsive_form.dart';

String _avatarMimeType(String? ext) {
  switch ((ext ?? '').toLowerCase()) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'heic':
      return 'image/heic';
    default:
      return 'image/jpeg';
  }
}

Uint8List _decodeAvatarDataUrl(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  return base64Decode(comma == -1 ? dataUrl : dataUrl.substring(comma + 1));
}

// Keep in sync with the `version:` field in pubspec.yaml — read locally
// rather than via a plugin so "Về ứng dụng" needs zero new dependencies.
const String _appVersion = '1.0.0';

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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildMenuSection(context),
                          _buildAccountSection(context, includeLogout: false),
                        ],
                      ),
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
      padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16, vertical: isWide ? 24 : 16),
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

              // Tài khoản (đổi mật khẩu, về ứng dụng, đăng xuất) — desktop
              // already exposes logout permanently in the sidebar, so only
              // the mobile copy includes it here.
              _buildAccountSection(context, includeLogout: true),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AuthProvider>().logout();
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
    }
  }

  Widget _buildProfileCard(BuildContext context, Employee? user) {
    final stores = context.watch<StoreProvider>().stores;
    final myStore = (user?.storeCode != null && user!.storeCode!.isNotEmpty && stores.isNotEmpty)
        ? stores.cast<dynamic>().firstWhere(
            (s) => s.storeCode.toString().toUpperCase() == user.storeCode!.toUpperCase(),
            orElse: () => null,
          )
        : null;
    final storeLabel = myStore != null
        ? '${myStore.name} (${myStore.storeCode})'
        : ((user?.workLocation ?? '').isNotEmpty ? user!.workLocation : null);
    final hasAvatar = (user?.avatarUrl ?? '').isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.row + 6),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 2.5,
                  ),
                  image: hasAvatar
                      ? DecorationImage(
                          image: MemoryImage(_decodeAvatarDataUrl(user!.avatarUrl!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: hasAvatar
                    ? null
                    : Center(
                        child: Text(
                          user?.fullName.isNotEmpty == true
                              ? user!.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
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
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.fullName ?? 'Người dùng',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                          ),
                          child: Text(
                            user?.positionLabel ?? user?.position ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                          ),
                          child: Text(
                            user?.employeeCode ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (storeLabel != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.store_rounded, size: 14, color: AppColors.textGrey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              storeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showEditProfileDialog(context, user),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.row - 2),
                  ),
                  child: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 18),
                ),
              ),
            ],
          ),
          if (user != null && context.watch<PermissionProvider>().managedStoreIds.length >= 2) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _showTransferStoreDialog(context, user),
              icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.primary),
              label: const Text(
                'Chuyển cửa hàng',
                style: TextStyle(color: AppColors.primary, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.row)),
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
                            borderRadius: BorderRadius.circular(AppRadius.row - 2),
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
      if (permProv.canStoreList ||
          permProv.managedStoreIds.isNotEmpty ||
          (permProv.ownStoreCode != null && permProv.ownStoreCode!.isNotEmpty))
        _MenuItem(Icons.store_rounded, AppStrings.danhSachCuaHang, 'Danh sách cửa hàng trong hệ thống', AppRoutes.storeList, AppColors.primary, AppColors.primaryLight),
      if (permProv.canProductList)
        _MenuItem(Icons.inventory_2_rounded, AppStrings.danhSachSanPham, 'Quản lý sản phẩm & tồn kho', AppRoutes.productList, AppColors.error, AppColors.errorLight),
      if (permProv.isAdmin || permProv.canCrud)
        _MenuItem(Icons.admin_panel_settings_rounded, 'Phân quyền hệ thống', 'Cấu hình quyền & phân công cửa hàng', AppRoutes.phanQuyen, AppColors.purpleAccent, AppColors.purpleLight),
      if (permProv.isAdmin)
        _MenuItem(Icons.receipt_long_rounded, 'Cài đặt hóa đơn điện tử', 'Kết nối nhà cung cấp hóa đơn điện tử', AppRoutes.einvoiceSettings, AppColors.info, AppColors.infoLight),
      if (permProv.canReport)
        _MenuItem(Icons.print_rounded, 'Cài đặt máy in', 'Kết nối máy in hoá đơn qua WiFi', AppRoutes.printerSettings, AppColors.success, AppColors.successLight),
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

  /// Account-level actions (đổi mật khẩu, về ứng dụng, đăng xuất) — kept in
  /// its own "Tài khoản" card, separate from "Quản lý" business features.
  /// [includeLogout] is only true on mobile: desktop already exposes logout
  /// permanently in the sidebar, so this avoids showing it twice there.
  Widget _buildAccountSection(BuildContext context, {required bool includeLogout}) {
    final accountItems = <_MenuItem>[
      _MenuItem(
        Icons.lock_reset_rounded,
        'Đổi mật khẩu',
        'Cập nhật mật khẩu đăng nhập',
        null,
        AppColors.info,
        AppColors.infoLight,
        onTap: () => _showChangePasswordDialog(context),
      ),
      _MenuItem(
        Icons.info_outline_rounded,
        'Về ứng dụng',
        'Phiên bản $_appVersion',
        null,
        AppColors.textGrey,
        AppColors.surfaceVariant,
        onTap: () => _showAboutDialog(context),
      ),
      if (includeLogout)
        _MenuItem(
          Icons.logout_rounded,
          AppStrings.dangXuat,
          'Thoát khỏi tài khoản hiện tại',
          null,
          AppColors.error,
          AppColors.errorLight,
          onTap: () => _confirmLogout(context),
        ),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 20),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
            child: Text('Tài khoản', style: AppTextStyles.sectionHeader),
          ),
          ...accountItems.map((item) => _buildMenuItem(context, item)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, _MenuItem item) {
    return InkWell(
      onTap: item.onTap ?? () => Navigator.pushNamed(context, item.route!),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.row),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: item.bgColor,
                  borderRadius: BorderRadius.circular(AppRadius.row),
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
    // Restrict choices to stores this user is currently a manager of.
    final managedIds = context.read<PermissionProvider>().managedStoreIds.toSet();

    String? selectedStoreId;
    String storeQuery = '';
    String selectedRole = 'PG';
    bool isLoading = false;

    showResponsiveForm(
      context: context,
      title: 'Chuyển cửa hàng',
      contentBuilder: (ctx, setDialogState) {
        final stores = context
            .read<StoreProvider>()
            .stores
            .where((s) => managedIds.contains(s.id))
            .toList();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  borderRadius: BorderRadius.circular(AppRadius.row),
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
        );
      },
      actionsBuilder: (ctx, setDialogState) {
        final stores = context
            .read<StoreProvider>()
            .stores
            .where((s) => managedIds.contains(s.id))
            .toList();
        return [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
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
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text('Đã chuyển ${user.fullName} đến ${store.name}!'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppColors.success,
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
                        ),
                      );
                    }
                  },
            child: isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Chuyển'),
          ),
        ];
      },
    );
  }

  void _showEditProfileDialog(BuildContext context, Employee? user) {
    final nameCtrl = TextEditingController(text: user?.fullName ?? '');
    final emailCtrl = TextEditingController(text: user?.email ?? '');
    final phoneCtrl = TextEditingController(text: user?.phone ?? '');
    final dobCtrl = TextEditingController(text: user?.dateOfBirth ?? '');
    final cccdCtrl = TextEditingController(text: user?.cccd ?? '');
    final addressCtrl = TextEditingController(text: user?.address ?? '');
    String? avatarDataUrl = user?.avatarUrl;

    Future<void> pickAvatar(BuildContext ctx, StateSetter setDialogState, ImageSource source) async {
      try {
        final file = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 640);
        if (file == null) return;
        final bytes = await file.readAsBytes();
        final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
        final dataUrl = 'data:${_avatarMimeType(ext)};base64,${base64Encode(bytes)}';
        setDialogState(() => avatarDataUrl = dataUrl);
      } catch (_) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('Không thể lấy ảnh.'), behavior: SnackBarBehavior.floating),
          );
        }
      }
    }

    void showAvatarSourceSheet(BuildContext ctx, StateSetter setDialogState) {
      showModalBottomSheet(
        context: ctx,
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (sheetCtx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded, color: AppColors.primary),
                title: const Text('Chụp ảnh'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  pickAvatar(ctx, setDialogState, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                title: const Text('Chọn từ thư viện'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  pickAvatar(ctx, setDialogState, ImageSource.gallery);
                },
              ),
              if (avatarDataUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  title: const Text('Xóa ảnh', style: TextStyle(color: AppColors.error)),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    setDialogState(() => avatarDataUrl = null);
                  },
                ),
            ],
          ),
        ),
      );
    }

    Future<void> pickDob(BuildContext ctx, StateSetter setDialogState) async {
      final initial = DateTime.tryParse(dobCtrl.text) ?? DateTime(1995, 1, 1);
      final picked = await showDatePicker(
        context: ctx,
        initialDate: initial,
        firstDate: DateTime(1940),
        lastDate: DateTime.now(),
      );
      if (picked != null) {
        setDialogState(() => dobCtrl.text = picked.toIso8601String().substring(0, 10));
      }
    }

    showResponsiveForm(
      context: context,
      title: 'Chỉnh sửa hồ sơ',
      contentBuilder: (ctx, setDialogState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: GestureDetector(
              onTap: () => showAvatarSourceSheet(ctx, setDialogState),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderLight),
                      image: avatarDataUrl != null
                          ? DecorationImage(image: MemoryImage(_decodeAvatarDataUrl(avatarDataUrl!)), fit: BoxFit.cover)
                          : null,
                    ),
                    child: avatarDataUrl == null
                        ? const Icon(Icons.person_rounded, color: AppColors.textHint, size: 34)
                        : null,
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 2.5),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: AppColors.white, size: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Họ tên')),
          const SizedBox(height: 8),
          TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 8),
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Số điện thoại'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: dobCtrl,
            readOnly: true,
            decoration: const InputDecoration(labelText: 'Ngày sinh', suffixIcon: Icon(Icons.cake_outlined, size: 18)),
            onTap: () => pickDob(ctx, setDialogState),
          ),
          const SizedBox(height: 8),
          TextField(controller: cccdCtrl, decoration: const InputDecoration(labelText: 'CCCD')),
          const SizedBox(height: 8),
          TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Địa chỉ')),
        ],
      ),
      actionsBuilder: (ctx, setDialogState) => [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
        ElevatedButton(
          onPressed: () {
            context.read<AuthProvider>().updateProfile(
              fullName: nameCtrl.text,
              email: emailCtrl.text.isNotEmpty ? emailCtrl.text : null,
              phone: phoneCtrl.text.isNotEmpty ? phoneCtrl.text : null,
              dateOfBirth: dobCtrl.text.isNotEmpty ? dobCtrl.text : null,
              cccd: cccdCtrl.text.isNotEmpty ? cccdCtrl.text : null,
              address: addressCtrl.text.isNotEmpty ? addressCtrl.text : null,
              avatarUrl: avatarDataUrl,
            );
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Đã cập nhật hồ sơ!'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
              ),
            );
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool isSubmitting = false;

    showResponsiveForm<void>(
      context: context,
      title: 'Đổi mật khẩu',
      contentBuilder: (ctx, setDialogState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: currentCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: newCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: confirmCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu mới'),
          ),
        ],
      ),
      actionsBuilder: (ctx, setDialogState) => [
        TextButton(
          onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: isSubmitting
              ? null
              : () async {
                  if (currentCtrl.text.isEmpty || newCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng nhập đầy đủ mật khẩu'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  if (newCtrl.text != confirmCtrl.text) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Mật khẩu xác nhận không khớp'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  setDialogState(() => isSubmitting = true);
                  final authProvider = context.read<AuthProvider>();
                  final success = await authProvider.changePassword(
                    currentPassword: currentCtrl.text,
                    newPassword: newCtrl.text,
                  );
                  if (!ctx.mounted) return;
                  if (success) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã đổi mật khẩu thành công!'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.success,
                      ),
                    );
                  } else {
                    setDialogState(() => isSubmitting = false);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(authProvider.error ?? 'Không thể đổi mật khẩu.'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
          child: isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
              : const Text('Đổi mật khẩu'),
        ),
      ],
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Về ứng dụng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppRadius.row),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Bi'S MART",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Phiên bản $_appVersion', style: AppTextStyles.bodyText),
            const SizedBox(height: 10),
            Text(
              "Bi'S MART đồng hành cùng chuỗi cửa hàng dinh dưỡng của bạn trong "
              'vận hành hằng ngày — từ chấm công GPS, quản lý nhân sự và xếp '
              'hạng hiệu suất, đến bán hàng tại quầy, báo cáo doanh thu, xuất '
              'hóa đơn điện tử và đào tạo đội ngũ, tất cả trên một ứng dụng duy nhất.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 8),
            Text(
              'Được xây dựng để đơn giản, nhanh và đáng tin cậy, giúp đội ngũ '
              'tập trung vào điều quan trọng nhất: chăm sóc khách hàng thật tốt.',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
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
  final String? route;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  const _MenuItem(this.icon, this.title, this.subtitle, this.route, this.color, this.bgColor, {this.onTap});
}
