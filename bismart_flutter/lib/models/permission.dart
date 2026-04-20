class Permission {
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
      position: json['position'] as String,
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
}
