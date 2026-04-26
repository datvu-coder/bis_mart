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
  String? _ownStoreCode; // employee.storeCode — the store this user is assigned to
  bool _isLoading = false;
  // storeId -> store_role for every store this user is a manager of (Tier-2)
  final Map<String, String> _managedStoreRoles = {};

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

  // ── Per-store (Tier-2) helpers ────────────────────────────────────────────
  Map<String, String> get managedStoreRoles =>
      Map.unmodifiable(_managedStoreRoles);
  List<String> get managedStoreIds => _managedStoreRoles.keys.toList();
  bool isManagerOfStore(String storeId) =>
      _managedStoreRoles.containsKey(storeId);
  String? roleForStore(String storeId) => _managedStoreRoles[storeId];
  String? get ownStoreCode => _ownStoreCode;

  /// Effective permission specifically for [storeId]: system perm OR'ed with
  /// the perm derived from the store-role this user holds for that store.
  Permission permissionForStore(String storeId) {
    final base = _systemPerm ??
        Permission.defaultForPosition(_systemRole ?? 'PG');
    final role = _managedStoreRoles[storeId];
    if (role == null) return base;
    final sp = Permission.defaultForPosition(role);
    return base.copyWith(
      canAttendance:       base.canAttendance       || sp.canAttendance,
      canReport:           base.canReport           || sp.canReport,
      canManageAttendance: base.canManageAttendance || sp.canManageAttendance,
      canEmployees:        base.canEmployees        || sp.canEmployees,
      canMore:             base.canMore             || sp.canMore,
      canCrud:             base.canCrud             || sp.canCrud,
      canSwitchStore:      base.canSwitchStore      || sp.canSwitchStore,
      canStoreList:        base.canStoreList        || sp.canStoreList,
      canProductList:      base.canProductList      || sp.canProductList,
    );
  }

  /// Can the current user view this store? Admin / system canStoreList /
  /// or being in the manager list of that store all grant view access.
  bool canViewStore(String storeId) =>
      isAdmin || canStoreList || _managedStoreRoles.containsKey(storeId);

  /// Can the current user edit this store?
  bool canEditStore(String storeId) => permissionForStore(storeId).canCrud;

  String get systemRoleLabel =>
      Permission.systemRoleLabels[_systemRole ?? ''] ?? (_systemRole ?? '');
  String get storeRoleLabel =>
      Permission.storeRoleLabels[_storeRole ?? ''] ?? (_storeRole ?? '');

  /// Load effective permissions from the backend (resolves all 3 tiers).
  Future<void> resolveForUser(Employee user) async {
    _systemRole = user.position;
    _ownStoreCode = user.storeCode;
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
      _managedStoreRoles.clear();
      final ms = data['managedStores'] as List?;
      if (ms != null) {
        for (final m in ms) {
          if (m is Map) {
            final sid = m['storeId']?.toString();
            final role = (m['storeRole'] as String?) ?? 'PG';
            if (sid != null && sid.isNotEmpty) {
              _managedStoreRoles[sid] = role;
            }
          }
        }
      }
    } catch (_) {
      // Fallback: derive from system role only
      _effective  = Permission.defaultForPosition(user.position);
      _systemPerm = _effective;
      _storePerm  = null;
      _storeRole  = null;
      _managedStoreRoles.clear();
    }

    _isLoading = false;
    notifyListeners();
  }

  void clear() {
    _effective = _systemPerm = _storePerm = null;
    _systemRole = _storeRole = null;
    _ownStoreCode = null;
    _managedStoreRoles.clear();
    notifyListeners();
  }
}
