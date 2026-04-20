class Store {
  final String id;
  final String name;
  final String group; // CS | HO | I | II
  final String storeCode;
  final List<StoreManager> managers;
  final double? latitude;
  final double? longitude;

  Store({
    required this.id,
    required this.name,
    required this.group,
    required this.storeCode,
    this.managers = const [],
    this.latitude,
    this.longitude,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] as String,
      name: json['name'] as String,
      group: json['group'] as String,
      storeCode: json['storeCode'] as String,
      managers: (json['managers'] as List<dynamic>?)
              ?.map((m) => StoreManager.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'group': group,
        'storeCode': storeCode,
        'managers': managers.map((m) => m.toJson()).toList(),
        'latitude': latitude,
        'longitude': longitude,
      };
}

class StoreManager {
  final String employeeId;
  final String name;
  final String employeeCode;
  final String? email;

  StoreManager({
    required this.employeeId,
    required this.name,
    required this.employeeCode,
    this.email,
  });

  factory StoreManager.fromJson(Map<String, dynamic> json) {
    return StoreManager(
      employeeId: json['employeeId'] as String,
      name: json['name'] as String,
      employeeCode: json['employeeCode'] as String,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'employeeId': employeeId,
        'name': name,
        'employeeCode': employeeCode,
        'email': email,
      };
}
