import 'package:flutter/material.dart';
import '../models/permission.dart';
import '../models/employee.dart';
import '../services/api_service.dart';

/// Central permission manager for the 3-tier role system:
///   Tier 1 — Chức vụ hệ thống  (employee.position)
///   Tier 2 — Cửa hàng          (employee.storeCode / store_managers)
///   Tier 3 — Chức vụ cửa hàng  (store_managers.store_role)
class PermissionProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  Permission? _effective;
  Permission? _systemPerm;
  Permission? _storePerm;
  String? _systemRole;
  String? _storeRole;
  bool _isLoading = false;

  Permission? get effective => _effective;
  Permission? get systemPerm => _systemPerm;
  Permission? get storePerm => _storePerm;
  String? get systemRole => _systemRole;
  String? get storeRole => _storeRole;
  bool get isLoading => _isLoading;

  // ── Convenience permission getters ────────────────────────────────────────
  bool get canAttendance       => _effective?.canAttendance       ?? false;
  bool get canReport           => _effective?.canReport           ?? false;
  bool get canManageAttendance => _effective?.canManageAttendance ?? false;
  bool get canEmployees        => _effective?.canEmployees        ?? false;
  bool get canMore             => _effective?.canMore             ?? false;
  bool get canCrud             => _effective?.canCrud             ?? false;
  bool get canSwitchStore      => _effective?.canSwitchStore      ?? false;
  bool get canStoreList        => _effective?.canStoreList        ?? false;
  bool get canProductList      => _effective?.canProductList      ?? false;

  bool get isAdmin    => _systemRole == Permission.roleAdmin;
  bool get isManager  => const {
    Permission.roleAdmin, Permission.roleManager, Permission.storeRoleCS
  }.contains(_systemRole);

  String get systemRoleLabel =>
      Permission.systemRoleLabels[_systemRole ?? ''] ?? (_systemRole ?? '');
  String get storeRoleLabel =>
      Permission.storeRoleLabels[_storeRole ?? ''] ?? (_storeRole ?? '');

  /// Load effective permissions from the backend (resolves all 3 tiers).
  Future<void> resolveForUser(Employee user) async {
    _systemRole = user.position;
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _api.getMyEffectivePermissions();
      _effective  = Permission.fromJson(data['effective']  as Map<String, dynamic>);
      _systemPerm = Permission.fromJson(data['systemPerm'] as Map<String, dynamic>);
      _storeRole  = data['storeRole'] as String?;
      _storePerm  = data['storePerm'] != null
          ? Permission.fromJson(data['storePerm'] as Map<String, dynamic>)
          : null;
    } catch (_) {
      // Fallback: derive from system role only
      _effective  = Permission.defaultForPosition(user.position);
      _systemPerm = _effective;
      _storePerm  = null;
      _storeRole  = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  void clear() {
    _effective = _systemPerm = _storePerm = null;
    _systemRole = _storeRole = null;
    notifyListeners();
  }
}
