import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:html' as html show InputElement, FileReader, Blob, Url, AnchorElement;
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/permission.dart';
import '../../providers/auth_provider.dart';
import '../../providers/permission_provider.dart';
import '../../providers/store_provider.dart';
import '../../models/employee.dart';
import '../../models/store.dart';
import '../../providers/employee_provider.dart';
import '../../services/api_service.dart';

class PhanQuyenScreen extends StatefulWidget {
  const PhanQuyenScreen({super.key});

  @override
  State<PhanQuyenScreen> createState() => _PhanQuyenScreenState();
}

class _PhanQuyenScreenState extends State<PhanQuyenScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State for tab 1 (permissions per position)
  List<Permission> _permissions = [];
  bool _loadingPerms = false;

  // State for tab 2 (store assignments)
  List<Map<String, dynamic>> _assignments = [];
  bool _loadingAssign = false;
  String _assignmentSearch = '';
  bool _importingAssign = false;

  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPermissions();
      _loadAssignments();
      context.read<StoreProvider>().loadStores();
      context.read<EmployeeProvider>().loadEmployees();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    setState(() => _loadingPerms = true);
    try {
      final data = await _api.getPermissions();
      setState(() {
        _permissions = data
            .map((p) => Permission.fromJson(p as Map<String, dynamic>))
            .toList();
      });
    } catch (_) {}
    setState(() => _loadingPerms = false);
  }

  Future<void> _loadAssignments() async {
    setState(() => _loadingAssign = true);
    try {
      final data = await _api.getStoreManagers();
      setState(() {
        _assignments = data.cast<Map<String, dynamic>>().toList();
      });
    } catch (_) {}
    setState(() => _loadingAssign = false);
  }

  @override
  Widget build(BuildContext context) {
    final perm = context.watch<PermissionProvider>();
    // Only system admins (or roles whose permissions include canCrud) may
    // touch the role/permission catalog or manager assignments. PG/SM/etc.
    // arrive here read-only.
    final canEditPermissions = perm.isAdmin || perm.canCrud;
    final canManageAssignments = canEditPermissions;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Phân quyền hệ thống'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_permissions.length} chức vụ · ${_assignments.length} phân công',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.white,
                unselectedLabelColor: AppColors.textGrey,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(3),
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(height: 34, text: 'Quyền chức vụ'),
                  Tab(height: 34, text: 'Phân công cửa hàng'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPermissionsTab(canEditPermissions),
          _buildAssignmentsTab(canManageAssignments),
        ],
      ),
    );
  }

  // ── TAB 1: Quyền theo chức vụ ─────────────────────────────────────────────

  Widget _buildPermissionsTab(bool canEditPermissions) {
    if (_loadingPerms) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    final isWide = MediaQuery.of(context).size.width >= 600;
    final hPad = isWide ? 24.0 : 2.0;
    final innerPad = isWide ? 24.0 : 10.0;

    final systemKeys = Permission.systemRoleLabels.keys.toSet();
    final systemPerms = _permissions
        .where((p) => systemKeys.contains(p.position.toUpperCase()))
        .toList();
    final storePerms = _permissions
        .where((p) => !systemKeys.contains(p.position.toUpperCase()))
        .toList();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 6),
          child: _buildSummaryHeader(
            icon: Icons.admin_panel_settings_rounded,
            color: AppColors.primary,
            title: 'Cấu hình quyền',
            subtitle:
                '${systemPerms.length} chức vụ hệ thống · ${storePerms.length} chức vụ tại cửa hàng',
            actionLabel: 'Thêm',
            actionEnabled: canEditPermissions,
            onAction: () => _showEditPermissionDialog(null),
            readOnly: !canEditPermissions,
          ),
        ),
        Expanded(
          child: _permissions.isEmpty
              ? Center(
                  child: Text(
                      'Chưa có cấu hình quyền nào.\nNhấn "Thêm" để tạo.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption),
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(innerPad, 6, innerPad, 80),
                  children: [
                    if (systemPerms.isNotEmpty) ...[
                      _sectionLabel('Chức vụ hệ thống', systemPerms.length),
                      ...systemPerms.map((p) => _buildPermissionCard(p, canEditPermissions, isSystem: true)),
                      const SizedBox(height: 14),
                    ],
                    if (storePerms.isNotEmpty) ...[
                      _sectionLabel('Chức vụ tại cửa hàng', storePerms.length),
                      ...storePerms.map((p) => _buildPermissionCard(p, canEditPermissions, isSystem: false)),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          Text(label,
              style: AppTextStyles.bodyText.copyWith(
                  fontWeight: FontWeight.w800, color: AppColors.textGrey)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$count',
                style: AppTextStyles.caption
                    .copyWith(fontWeight: FontWeight.w700, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String actionLabel,
    required bool actionEnabled,
    required VoidCallback onAction,
    Widget? extra,
    bool readOnly = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(title,
                        style: AppTextStyles.bodyText
                            .copyWith(fontWeight: FontWeight.w700)),
                    if (readOnly) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Chỉ xem',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w700,
                                fontSize: 10)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppTextStyles.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (extra != null) ...[
                  const SizedBox(height: 6),
                  extra,
                ],
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: actionEnabled ? onAction : null,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(actionLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard(Permission perm, bool canEditPermissions, {required bool isSystem}) {
    final flags = [
      ('Chấm công', perm.canAttendance, Icons.fingerprint_rounded),
      ('Báo cáo', perm.canReport, Icons.bar_chart_rounded),
      ('Quản lý CC', perm.canManageAttendance, Icons.verified_user_rounded),
      ('Nhân viên', perm.canEmployees, Icons.people_rounded),
      ('Thêm/Sửa/Xoá', perm.canCrud, Icons.edit_rounded),
      ('Cửa hàng', perm.canStoreList, Icons.store_rounded),
      ('Sản phẩm', perm.canProductList, Icons.inventory_2_rounded),
      ('Đổi cửa hàng', perm.canSwitchStore, Icons.swap_horiz_rounded),
    ];
    final color = isSystem ? AppColors.primary : AppColors.info;
    final label = perm.description ??
        Permission.systemRoleLabels[perm.position] ??
        Permission.storeRoleLabels[perm.position] ??
        '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(perm.position,
                    style: AppTextStyles.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: AppTextStyles.bodyText
                        .copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.edit_outlined,
                    size: 17, color: AppColors.primary),
                tooltip: 'Sửa',
                onPressed: canEditPermissions
                    ? () => _showEditPermissionDialog(perm)
                    : null,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 17, color: AppColors.error),
                tooltip: 'Xoá',
                onPressed: canEditPermissions
                    ? () => _deletePermission(perm.position)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: flags.map((f) => _flagChip(f.$1, f.$2, f.$3)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _flagChip(String label, bool enabled, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.successLight
            : AppColors.surfaceVariant.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 12,
              color: enabled ? AppColors.success : AppColors.textHint),
          const SizedBox(width: 4),
          Text(label,
              style: AppTextStyles.caption.copyWith(
                color: enabled ? AppColors.success : AppColors.textHint,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              )),
        ],
      ),
    );
  }

  Future<void> _deletePermission(String position) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Xóa cấu hình quyền cho chức vụ "$position"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _api.deletePermission(position);
        await _loadPermissions();
        await _refreshCurrentUserPermissions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Đã xóa quyền cho "$position"'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Xóa quyền thất bại: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      }
    }
  }

  void _showEditPermissionDialog(Permission? existing) {
    final posCtrl = TextEditingController(text: existing?.position ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    var flags = {
      'canAttendance':       existing?.canAttendance       ?? false,
      'canReport':           existing?.canReport           ?? false,
      'canManageAttendance': existing?.canManageAttendance ?? false,
      'canEmployees':        existing?.canEmployees        ?? false,
      'canMore':             existing?.canMore             ?? false,
      'canCrud':             existing?.canCrud             ?? false,
      'canSwitchStore':      existing?.canSwitchStore      ?? false,
      'canStoreList':        existing?.canStoreList        ?? false,
      'canProductList':      existing?.canProductList      ?? false,
    };
    const flagLabels = {
      'canAttendance':       'Chấm công',
      'canReport':           'Báo cáo doanh thu',
      'canManageAttendance': 'Quản lý chấm công',
      'canEmployees':        'Xem nhân viên',
      'canMore':             'Mục cá nhân',
      'canCrud':             'Thêm / Sửa / Xóa',
      'canSwitchStore':      'Đổi cửa hàng',
      'canStoreList':        'Danh sách cửa hàng',
      'canProductList':      'Danh sách sản phẩm',
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Thêm chức vụ mới' : 'Sửa quyền — ${existing.position}'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (existing == null) ...[
                    TextField(
                      controller: posCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Mã chức vụ (VD: ADM, SM, PG)',
                        hintText: 'Nhập mã in hoa',
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Mô tả'),
                  ),
                  const SizedBox(height: 14),
                  Text('Quyền hạn:', style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ...flagLabels.entries.map((e) => SwitchListTile(
                    dense: true,
                    title: Text(e.value, style: AppTextStyles.bodyText),
                    value: flags[e.key] ?? false,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setDialogState(() => flags[e.key] = v),
                  )),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final payload = {
                    'position': existing?.position ?? posCtrl.text.trim().toUpperCase(),
                    'description': descCtrl.text.trim(),
                    ...flags,
                  };
                  if (existing == null) {
                    await _api.createPermission(payload);
                  } else {
                    await _api.updatePermission(existing.position, payload);
                  }
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  await _loadPermissions();
                  await _refreshCurrentUserPermissions();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(existing == null
                          ? 'Đã thêm chức vụ mới'
                          : 'Đã cập nhật quyền cho ${existing.position}'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ));
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text('Lưu quyền thất bại: $e'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ));
                  }
                }
              },
              child: Text(existing == null ? 'Thêm' : 'Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  // ── TAB 2: Phân công cửa hàng ────────────────────────────────────────────

  Widget _buildAssignmentsTab(bool canManageAssignments) {
    if (_loadingAssign) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    final isWide = MediaQuery.of(context).size.width >= 600;
    final hPad = isWide ? 24.0 : 2.0;
    final innerPad = isWide ? 24.0 : 10.0;

    final stores = context.watch<StoreProvider>().stores;
    final employees = context.watch<EmployeeProvider>().employees;
    final query = _assignmentSearch.trim().toLowerCase();
    final filtered = _assignments.where((a) {
      if (query.isEmpty) return true;
      final employeeName = (a['employeeName'] ?? '').toString().toLowerCase();
      final employeeCode = (a['employeeCode'] ?? '').toString().toLowerCase();
      final storeName = (a['storeName'] ?? '').toString().toLowerCase();
      final storeCode = (a['storeCode'] ?? '').toString().toLowerCase();
      final storeRole = (a['storeRole'] ?? '').toString().toLowerCase();
      return employeeName.contains(query) ||
          employeeCode.contains(query) ||
          storeName.contains(query) ||
          storeCode.contains(query) ||
          storeRole.contains(query);
    }).toList();

    // Group by store for compact, scannable layout.
    final byStore = <String, List<Map<String, dynamic>>>{};
    for (final a in filtered) {
      final key =
          '${a['storeCode'] ?? ''}|${a['storeName'] ?? ''}|${a['storeId'] ?? ''}';
      byStore.putIfAbsent(key, () => []).add(a);
    }
    final storeKeys = byStore.keys.toList()..sort();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 6),
          child: _buildSummaryHeader(
            icon: Icons.store_mall_directory_rounded,
            color: AppColors.info,
            title: 'Phân công cửa hàng',
            subtitle:
                '${_assignments.length} phân công · ${byStore.length} cửa hàng',
            actionLabel: 'Phân công',
            actionEnabled: canManageAssignments &&
                stores.isNotEmpty &&
                employees.isNotEmpty,
            onAction: () => _showAssignDialog(stores, employees),
            readOnly: !canManageAssignments,
            extra: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _miniAction(
                  Icons.upload_file_rounded,
                  _importingAssign ? 'Đang import…' : 'Import CSV',
                  AppColors.primary,
                  enabled: canManageAssignments && !_importingAssign,
                  onTap: () => _importAssignmentsFromCsv(stores, employees),
                ),
                _miniAction(
                  Icons.download_rounded,
                  'Mẫu CSV',
                  AppColors.textGrey,
                  enabled: true,
                  onTap: _downloadSampleCsv,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(innerPad, 6, innerPad, 6),
          child: TextField(
            onChanged: (v) => setState(() => _assignmentSearch = v),
            decoration: InputDecoration(
              hintText: 'Tìm theo nhân viên / cửa hàng / chức vụ…',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _assignments.isEmpty
                        ? 'Chưa có phân công nào.\nNhấn "Phân công" để thêm.'
                        : 'Không có kết quả phù hợp.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption,
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(innerPad, 4, innerPad, 80),
                  itemCount: storeKeys.length,
                  itemBuilder: (ctx, i) {
                    final k = storeKeys[i];
                    final parts = k.split('|');
                    final code = parts.isNotEmpty ? parts[0] : '';
                    final name = parts.length > 1 ? parts[1] : '';
                    final list = byStore[k]!;
                    return _buildStoreGroup(
                        code, name, list, canManageAssignments);
                  },
                ),
        ),
      ],
    );
  }

  Widget _miniAction(IconData icon, String label, Color color,
      {required bool enabled, required VoidCallback onTap}) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: enabled ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: enabled ? color : AppColors.textHint),
            const SizedBox(width: 4),
            Text(label,
                style: AppTextStyles.caption.copyWith(
                    color: enabled ? color : AppColors.textHint,
                    fontWeight: FontWeight.w700,
                    fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreGroup(String storeCode, String storeName,
      List<Map<String, dynamic>> entries, bool canManageAssignments) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Theme(
        data: Theme.of(context)
            .copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: entries.length <= 6,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding:
              const EdgeInsets.fromLTRB(8, 0, 8, 8),
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          collapsedShape:
              const RoundedRectangleBorder(side: BorderSide.none),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.store_rounded,
                size: 18, color: AppColors.info),
          ),
          title: Text(
            storeName.isNotEmpty ? storeName : storeCode,
            style: AppTextStyles.bodyText.copyWith(
                fontWeight: FontWeight.w700, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            'Mã $storeCode · ${entries.length} người quản lý',
            style: AppTextStyles.caption.copyWith(fontSize: 11),
          ),
          children: entries
              .map((a) =>
                  _buildAssignmentRow(a, canManageAssignments))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildAssignmentRow(
      Map<String, dynamic> a, bool canManageAssignments) {
    final roleCode = (a['storeRole'] ?? '').toString();
    final roleLabel = Permission.storeRoleLabels[roleCode] ??
        Permission.systemRoleLabels[roleCode] ??
        roleCode;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.person_rounded,
                size: 14, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(a['employeeName'] ?? '',
                    style: AppTextStyles.bodyText.copyWith(
                        fontWeight: FontWeight.w600, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('Mã ${a['employeeCode'] ?? ''}',
                    style: AppTextStyles.caption
                        .copyWith(fontSize: 10.5)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$roleCode · $roleLabel',
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11),
            ),
          ),
          if (canManageAssignments)
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert_rounded,
                  size: 16, color: AppColors.textGrey),
              onSelected: (v) async {
                if (v == 'edit') {
                  _showEditRoleDialog(a);
                } else if (v == 'delete') {
                  try {
                    await _api.deleteStoreManager(a['id'] as int);
                    await _loadAssignments();
                    await _refreshCurrentUserPermissions();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Xoá phân công thất bại: $e'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.error,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ));
                    }
                  }
                }
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(value: 'edit', child: Text('Đổi chức vụ')),
                PopupMenuItem(value: 'delete', child: Text('Xoá phân công')),
              ],
            ),
        ],
      ),
    );
  }

  void _showAssignDialog(List<dynamic> stores, List<dynamic> employees) {
    final employeeList = employees.cast<Employee>();
    final storeList = stores.cast<Store>();
    String? storeId;
    String? employeeId;
    String storeRole = Permission.storeRolePG;
    String employeeQuery = '';
    String storeQuery = '';

    Employee? findEmployee(String raw) {
      final query = raw.trim().toLowerCase();
      if (query.isEmpty) return null;
      for (final employee in employeeList) {
        final display =
            '${employee.fullName} (${employee.employeeCode})'.toLowerCase();
        if (employee.fullName.toLowerCase() == query ||
            employee.employeeCode.toLowerCase() == query ||
            display == query) {
          return employee;
        }
      }
      return null;
    }

    Store? findStore(String raw) {
      final query = raw.trim().toLowerCase();
      if (query.isEmpty) return null;
      for (final store in storeList) {
        final display = '${store.name} (${store.storeCode})'.toLowerCase();
        if (store.name.toLowerCase() == query ||
            store.storeCode.toLowerCase() == query ||
            display == query) {
          return store;
        }
      }
      return null;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Phân công nhân viên vào cửa hàng'),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Autocomplete<Employee>(
                    displayStringForOption: (e) =>
                        '${e.fullName} (${e.employeeCode})',
                    optionsBuilder: (textEditingValue) {
                      employeeQuery = textEditingValue.text;
                      if (textEditingValue.text.trim().isEmpty) return employeeList;
                      final query = textEditingValue.text.toLowerCase();
                      return employeeList.where((e) =>
                          e.fullName.toLowerCase().contains(query) ||
                          e.employeeCode.toLowerCase().contains(query));
                    },
                    onSelected: (e) =>
                        setDialogState(() => employeeId = e.id),
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Nhân viên',
                          hintText: 'Tìm tên hoặc mã nhân viên...',
                          prefixIcon: Icon(Icons.search_rounded, size: 18),
                        ),
                        onChanged: (value) => setDialogState(() {
                          employeeQuery = value;
                          employeeId = null;
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Autocomplete<Store>(
                    displayStringForOption: (s) =>
                        '${s.name} (${s.storeCode})',
                    optionsBuilder: (textEditingValue) {
                      storeQuery = textEditingValue.text;
                      if (textEditingValue.text.trim().isEmpty) return storeList;
                      final query = textEditingValue.text.toLowerCase();
                      return storeList.where((s) =>
                          s.name.toLowerCase().contains(query) ||
                          s.storeCode.toLowerCase().contains(query));
                    },
                    onSelected: (s) =>
                        setDialogState(() => storeId = s.id),
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Cửa hàng',
                          hintText: 'Tìm tên hoặc mã cửa hàng...',
                          prefixIcon: Icon(Icons.store_rounded, size: 18),
                        ),
                        onChanged: (value) => setDialogState(() {
                          storeQuery = value;
                          storeId = null;
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Chức vụ tại cửa hàng'),
                    value: storeRole,
                    items: Permission.storeRoleLabels.entries
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text('${e.key} — ${e.value}'),
                            ))
                        .toList(),
                    onChanged: (v) => setDialogState(() => storeRole = v!),
                  ),
                ],
              ),
            ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                final selectedEmployee = employeeId != null
                    ? employeeList.where((e) => e.id == employeeId).firstOrNull
                    : findEmployee(employeeQuery);
                final selectedStore = storeId != null
                    ? storeList.where((s) => s.id == storeId).firstOrNull
                    : findStore(storeQuery);

                if (selectedEmployee == null || selectedStore == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: const Text(
                      'Hãy chọn đúng nhân viên và cửa hàng từ danh sách gợi ý hoặc nhập đúng mã.',
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppColors.warning,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                  return;
                }

                final duplicated = _assignments.any((item) {
                  return (item['employeeCode'] ?? '').toString().toUpperCase() ==
                          selectedEmployee.employeeCode.toUpperCase() &&
                      (item['storeCode'] ?? '').toString().toUpperCase() ==
                          selectedStore.storeCode.toUpperCase();
                });
                if (duplicated) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: const Text('Nhân viên này đã được phân công vào cửa hàng đã chọn.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppColors.warning,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                  return;
                }

                try {
                  await _api.createStoreManager({
                    'storeId': selectedStore.id,
                    'employeeId': selectedEmployee.id,
                    'storeRole': storeRole,
                  });
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  await _loadAssignments();
                  await _refreshCurrentUserPermissions();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text('Phân công thất bại: $e'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ));
                  }
                }
              },
              child: const Text('Phân công'),
            ),
          ],
          );
        },
      ),
    );
  }

  void _showEditRoleDialog(Map<String, dynamic> assignment) {
    String storeRole = assignment['storeRole'] as String? ?? Permission.storeRolePG;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Đổi chức vụ — ${assignment['employeeName']}'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Cửa hàng: ${assignment['storeName']}',
                    style: AppTextStyles.caption),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Chức vụ tại cửa hàng'),
                  value: storeRole,
                  items: Permission.storeRoleLabels.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text('${e.key} — ${e.value}'),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() => storeRole = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _api.updateStoreManager(
                      assignment['id'] as int, {'storeRole': storeRole});
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  await _loadAssignments();
                  await _refreshCurrentUserPermissions();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text('Cập nhật chức vụ thất bại: $e'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ));
                  }
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshCurrentUserPermissions() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    await context.read<PermissionProvider>().resolveForUser(user);
  }

  void _downloadSampleCsv() {
    const csv = 'employeeCode,storeCode,storeRole\n'
        'NV001,CH001,PG\n'
        'NV002,CH002,SM\n'
        'NV003,CH001,ASM\n';
    final blob = html.Blob([csv], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'mau_phan_cong.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _importAssignmentsFromCsv(
      List<dynamic> stores, List<dynamic> employees) async {
    final input = html.InputElement()
      ..type = 'file'
      ..accept = '.csv';
    input.click();

    input.onChange.listen((_) {
      final file = input.files?.isNotEmpty == true ? input.files!.first : null;
      if (file == null) return;

      final reader = html.FileReader();
      reader.readAsText(file);
      reader.onLoadEnd.listen((_) async {
        final raw = (reader.result ?? '').toString();
        if (raw.trim().isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('File CSV trống.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ));
          }
          return;
        }

        final lines = raw
            .split(RegExp(r'\r?\n'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (lines.isEmpty) return;

        final start = lines.first.toLowerCase().contains('employeecode') ? 1 : 0;
        if (start >= lines.length) return;

        setState(() => _importingAssign = true);
        int success = 0;
        int failed = 0;

        final storeIdByCode = <String, String>{
          for (final s in stores)
            if ((s.storeCode ?? '').toString().isNotEmpty)
              (s.storeCode as String).toUpperCase(): s.id as String,
        };
        final employeeIdByCode = <String, String>{
          for (final e in employees)
            if ((e.employeeCode ?? '').toString().isNotEmpty)
              (e.employeeCode as String).toUpperCase(): e.id as String,
        };

        for (var i = start; i < lines.length; i++) {
          final cols = lines[i].split(',').map((e) => e.trim()).toList();
          if (cols.length < 2) {
            failed++;
            continue;
          }

          final employeeCode = cols[0].toUpperCase();
          final storeCode = cols[1].toUpperCase();
          final role =
              (cols.length >= 3 && cols[2].isNotEmpty ? cols[2] : Permission.storeRolePG)
                  .toUpperCase();

          final employeeId = employeeIdByCode[employeeCode];
          final storeId = storeIdByCode[storeCode];
          if (employeeId == null || storeId == null) {
            failed++;
            continue;
          }
          if (!Permission.storeRoleLabels.containsKey(role)) {
            failed++;
            continue;
          }

          try {
            await _api.createStoreManager({
              'storeId': storeId,
              'employeeId': employeeId,
              'storeRole': role,
            });
            success++;
          } catch (_) {
            failed++;
          }
        }

        await _loadAssignments();
        await _refreshCurrentUserPermissions();
        if (mounted) {
          setState(() => _importingAssign = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Import xong: $success thành công, $failed thất bại.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: failed == 0 ? AppColors.success : AppColors.warning,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      });
    });
  }
}
