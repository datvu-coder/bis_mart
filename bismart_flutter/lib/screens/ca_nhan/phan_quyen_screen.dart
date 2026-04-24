import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:html' show InputElement, FileReader;
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/permission.dart';
import '../../providers/auth_provider.dart';
import '../../providers/permission_provider.dart';
import '../../providers/store_provider.dart';
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
    final isCompactMobile = MediaQuery.of(context).size.width < 430;
    final perm = context.watch<PermissionProvider>();
    final canEditPermissions = perm.isAdmin || perm.canCrud;
    final canManageAssignments = canEditPermissions || perm.canSwitchStore;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phân quyền hệ thống'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withValues(alpha: 0.65),
          indicatorColor: AppColors.white,
          tabs: [
            isCompactMobile
                ? const Tab(icon: Icon(Icons.admin_panel_settings_rounded, size: 18))
                : const Tab(text: 'Quyền theo chức vụ'),
            isCompactMobile
                ? const Tab(icon: Icon(Icons.store_mall_directory_rounded, size: 18))
                : const Tab(text: 'Phân công cửa hàng'),
          ],
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
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Cấu hình quyền cho từng chức vụ hệ thống và chức vụ cửa hàng',
                  style: AppTextStyles.caption,
                ),
              ),
              if (!canEditPermissions)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    'Chỉ xem',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: canEditPermissions ? () => _showEditPermissionDialog(null) : null,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Thêm'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ),
        ),
        _buildRoleLegend(),
        Expanded(
          child: _permissions.isEmpty
              ? Center(
                  child: Text('Chưa có cấu hình quyền nào.\nNhấn "Thêm" để tạo.',
                    textAlign: TextAlign.center, style: AppTextStyles.caption),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: _permissions.length,
                  itemBuilder: (ctx, i) => _buildPermissionCard(_permissions[i], canEditPermissions),
                ),
        ),
      ],
    );
  }

  Widget _buildRoleLegend() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chức vụ hệ thống:', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: Permission.systemRoleLabels.entries
                .map((e) => _roleBadge(e.key, e.value, AppColors.primary))
                .toList(),
          ),
          const SizedBox(height: 8),
          Text('Chức vụ tại cửa hàng:', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: Permission.storeRoleLabels.entries
                .map((e) => _roleBadge(e.key, e.value, AppColors.info))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _roleBadge(String code, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text('$code — $label',
          style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }

  Widget _buildPermissionCard(Permission perm, bool canEditPermissions) {
    final flags = [
      ('Chấm công', perm.canAttendance),
      ('Báo cáo', perm.canReport),
      ('Quản lý CC', perm.canManageAttendance),
      ('Nhân viên', perm.canEmployees),
      ('Thêm/Sửa', perm.canCrud),
      ('DS Cửa hàng', perm.canStoreList),
      ('DS Sản phẩm', perm.canProductList),
      ('Đổi cửa hàng', perm.canSwitchStore),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(perm.position,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  perm.description ??
                      Permission.systemRoleLabels[perm.position] ??
                      Permission.storeRoleLabels[perm.position] ?? '',
                  style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
                tooltip: 'Chỉnh sửa',
                onPressed: canEditPermissions ? () => _showEditPermissionDialog(perm) : null,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                tooltip: 'Xóa',
                onPressed: canEditPermissions ? () => _deletePermission(perm.position) : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: flags.map((f) => _flagChip(f.$1, f.$2)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _flagChip(String label, bool enabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: enabled ? AppColors.successLight : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 13,
            color: enabled ? AppColors.success : AppColors.textHint,
          ),
          const SizedBox(width: 4),
          Text(label,
            style: AppTextStyles.caption.copyWith(
              color: enabled ? AppColors.success : AppColors.textHint,
              fontWeight: FontWeight.w600, fontSize: 11)),
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
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _assignmentSearch = v),
            decoration: InputDecoration(
              hintText: 'Tìm theo nhân viên, cửa hàng, mã, chức vụ...',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Gán nhân viên vào cửa hàng với chức vụ tại cửa hàng đó',
                  style: AppTextStyles.caption,
                ),
              ),
              TextButton.icon(
                onPressed: (!canManageAssignments || _importingAssign)
                    ? null
                    : () => _importAssignmentsFromCsv(stores, employees),
                icon: _importingAssign
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(_importingAssign ? 'Đang import...' : 'Import CSV'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
              TextButton.icon(
                onPressed: !canManageAssignments || stores.isEmpty || employees.isEmpty
                    ? null
                    : () => _showAssignDialog(stores, employees),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Phân công'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ),
        ),
        if (!canManageAssignments)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Bạn không có quyền phân công/chuyển cửa hàng.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(_assignments.isEmpty
                      ? 'Chưa có phân công nào.\nNhấn "Phân công" để thêm.'
                      : 'Không có kết quả phù hợp từ khóa tìm kiếm.',
                    textAlign: TextAlign.center, style: AppTextStyles.caption),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) =>
                      _buildAssignmentCard(filtered[i], stores, employees, canManageAssignments),
                ),
        ),
      ],
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> a,
      List<dynamic> stores, List<dynamic> employees, bool canManageAssignments) {
    final roleLabel = Permission.storeRoleLabels[a['storeRole']] ??
        Permission.systemRoleLabels[a['storeRole']] ??
        (a['storeRole'] ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.store_rounded, size: 20, color: AppColors.info),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a['employeeName'] ?? '', style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.store_rounded, size: 13, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Expanded(child: Text(a['storeName'] ?? '', style: AppTextStyles.caption)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${a['storeRole']} — $roleLabel',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),
          if (canManageAssignments)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 18),
              onSelected: (v) async {
                if (v == 'edit') {
                  _showEditRoleDialog(a);
                } else if (v == 'delete') {
                  try {
                    await _api.deleteStoreManager(a['id'] as int);
                    await _loadAssignments();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Xóa phân công thất bại: $e'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.error,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ));
                    }
                  }
                }
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(value: 'edit', child: Text('Đổi chức vụ')),
                PopupMenuItem(value: 'delete', child: Text('Xóa phân công')),
              ],
            ),
        ],
      ),
    );
  }

  void _showAssignDialog(List<dynamic> stores, List<dynamic> employees) {
    String? storeId;
    String? employeeId;
    String storeRole = Permission.storeRolePG;
    String employeeSearch = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filteredEmployees = employees.where((e) {
            if (employeeSearch.trim().isEmpty) return true;
            final query = employeeSearch.toLowerCase();
            final fullName = (e.fullName as String).toLowerCase();
            final employeeCode = (e.employeeCode as String).toLowerCase();
            return fullName.contains(query) || employeeCode.contains(query);
          }).toList();

          return AlertDialog(
            title: const Text('Phân công nhân viên vào cửa hàng'),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Tìm kiếm nhân viên',
                      hintText: 'Nhập tên hoặc mã nhân viên',
                      prefixIcon: Icon(Icons.search_rounded, size: 18),
                    ),
                    onChanged: (v) => setDialogState(() => employeeSearch = v),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Kết quả: ${filteredEmployees.length}/${employees.length}',
                      style: AppTextStyles.caption,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Nhân viên'),
                    value: filteredEmployees.any((e) => e.id == employeeId)
                        ? employeeId
                        : null,
                    isExpanded: true,
                    items: filteredEmployees
                        .map((e) => DropdownMenuItem(
                              value: e.id as String,
                              child: Text('${e.fullName} (${e.employeeCode})'),
                            ))
                        .toList(),
                    onChanged: (v) => setDialogState(() => employeeId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Cửa hàng'),
                    value: storeId,
                    isExpanded: true,
                    items: stores
                        .map((s) => DropdownMenuItem(
                              value: s.id as String,
                              child: Text(s.name as String),
                            ))
                        .toList(),
                    onChanged: (v) => setDialogState(() => storeId = v),
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
              onPressed: (storeId != null && employeeId != null)
                  ? () async {
                      try {
                        await _api.createStoreManager({
                          'storeId': storeId,
                          'employeeId': employeeId,
                          'storeRole': storeRole,
                        });
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        await _loadAssignments();
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
                    }
                  : null,
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

  Future<void> _importAssignmentsFromCsv(
      List<dynamic> stores, List<dynamic> employees) async {
    final input = InputElement()
      ..type = 'file'
      ..accept = '.csv';
    input.click();

    input.onChange.listen((_) {
      final file = input.files?.isNotEmpty == true ? input.files!.first : null;
      if (file == null) return;

      final reader = FileReader();
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
