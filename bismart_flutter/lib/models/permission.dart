class Permission {
  // ── System role codes (Chức vụ hệ thống) ─────────────────────────────────
  static const String roleAdmin    = 'ADM';  // Super admin
  static const String roleManager  = 'MNG';  // Multi-store manager
  static const String roleAsmgr    = 'ASM';  // Area manager
  static const String roleSupervisor = 'TMK'; // Giám sát

  // ── Store role codes (Chức vụ tại cửa hàng) ──────────────────────────────
  static const String storeRoleSM   = 'SM';  // Cửa hàng trưởng
  static const String storeRoleTLD  = 'TLD'; // Trưởng nhóm
  static const String storeRolePG   = 'PG';  // Nhân viên tư vấn
  static const String storeRoleCS   = 'CS';  // Chủ shop chuỗi

  // ── System role display labels ────────────────────────────────────────────
  static const Map<String, String> systemRoleLabels = {
    'ADM': 'Super Admin',
    'MNG': 'Quản lý (chuỗi)',
    'ASM': 'Quản lý khu vực',
    'TMK': 'Giám sát',
    'SM':  'Cửa hàng trưởng',
    'TLD': 'Trưởng nhóm',
    'PG':  'Nhân viên tư vấn',
    'CS':  'Chủ shop chuỗi',
  };

  // ── Store role display labels ─────────────────────────────────────────────
  static const Map<String, String> storeRoleLabels = {
    'SM':  'Cửa hàng trưởng',
    'TLD': 'Trưởng nhóm',
    'PG':  'Nhân viên tư vấn',
    'CS':  'Chủ shop',
    'OWNER': 'Chủ sở hữu',
  };

  final int id;
  final String position;
  final String? description;
  final bool canAttendance;
  final bool canReport;
  final bool canManageAttendance;
  final bool canEmployees;
  final bool canMore;
  final bool canCrud;
  final bool canSwitchStore;
  final bool canStoreList;
  final bool canProductList;

  Permission({
    required this.id,
    required this.position,
    this.description,
    this.canAttendance = false,
    this.canReport = false,
    this.canManageAttendance = false,
    this.canEmployees = false,
    this.canMore = false,
    this.canCrud = false,
    this.canSwitchStore = false,
    this.canStoreList = false,
    this.canProductList = false,
  });

  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(
      id: json['id'] as int? ?? 0,
      position: (json['position'] as String?) ?? '',
      description: json['description'] as String?,
      canAttendance: json['canAttendance'] as bool? ?? false,
      canReport: json['canReport'] as bool? ?? false,
      canManageAttendance: json['canManageAttendance'] as bool? ?? false,
      canEmployees: json['canEmployees'] as bool? ?? false,
      canMore: json['canMore'] as bool? ?? false,
      canCrud: json['canCrud'] as bool? ?? false,
      canSwitchStore: json['canSwitchStore'] as bool? ?? false,
      canStoreList: json['canStoreList'] as bool? ?? false,
      canProductList: json['canProductList'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'position': position,
    'description': description,
    'canAttendance': canAttendance,
    'canReport': canReport,
    'canManageAttendance': canManageAttendance,
    'canEmployees': canEmployees,
    'canMore': canMore,
    'canCrud': canCrud,
    'canSwitchStore': canSwitchStore,
    'canStoreList': canStoreList,
    'canProductList': canProductList,
  };

  Permission copyWith({
    int? id, String? position, String? description,
    bool? canAttendance, bool? canReport, bool? canManageAttendance,
    bool? canEmployees, bool? canMore, bool? canCrud,
    bool? canSwitchStore, bool? canStoreList, bool? canProductList,
  }) => Permission(
    id: id ?? this.id,
    position: position ?? this.position,
    description: description ?? this.description,
    canAttendance: canAttendance ?? this.canAttendance,
    canReport: canReport ?? this.canReport,
    canManageAttendance: canManageAttendance ?? this.canManageAttendance,
    canEmployees: canEmployees ?? this.canEmployees,
    canMore: canMore ?? this.canMore,
    canCrud: canCrud ?? this.canCrud,
    canSwitchStore: canSwitchStore ?? this.canSwitchStore,
    canStoreList: canStoreList ?? this.canStoreList,
    canProductList: canProductList ?? this.canProductList,
  );

  /// Default permissions based on position code (fallback when DB has no record).
  static Permission defaultForPosition(String position) {
    final pos = position.toUpperCase();
    final isHighLevel = const {'ADM', 'MNG', 'CS'}.contains(pos);
    final isMid = const {'ASM', 'TMK', 'SM', 'TLD'}.contains(pos);
    return Permission(
      id: 0,
      position: pos,
      description: 'Mặc định',
      canAttendance: true,
      canReport: isHighLevel || isMid,
      canManageAttendance: isHighLevel || pos == 'SM' || pos == 'TLD',
      canEmployees: true,
      canMore: true,
      canCrud: isHighLevel,
      canSwitchStore: isHighLevel || pos == 'ASM' || pos == 'TMK',
      canStoreList: isHighLevel || isMid,
      canProductList: isHighLevel || isMid,
    );
  }
}
