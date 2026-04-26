class Store {
  final String id;
  final String name;
  final String group; // CS | HO | I | II
  final String storeCode;
  final List<StoreManager> managers;
  final double? latitude;
  final double? longitude;
  final String? province;
  final String? sup;
  final String? status;
  final String? openDate;
  final String? closeDate;
  final String? storeType;
  final String? address;
  final String? phone;
  final String? owner;
  final String? taxCode;

  Store({
    required this.id,
    required this.name,
    required this.group,
    required this.storeCode,
    this.managers = const [],
    this.latitude,
    this.longitude,
    this.province,
    this.sup,
    this.status,
    this.openDate,
    this.closeDate,
    this.storeType,
    this.address,
    this.phone,
    this.owner,
    this.taxCode,
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
      province: json['province'] as String?,
      sup: json['sup'] as String?,
      status: json['status'] as String?,
      openDate: json['openDate'] as String?,
      closeDate: json['closeDate'] as String?,
      storeType: json['storeType'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      owner: json['owner'] as String?,
      taxCode: json['taxCode'] as String?,
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
        'province': province,
        'sup': sup,
        'status': status,
        'openDate': openDate,
        'closeDate': closeDate,
        'storeType': storeType,
        'address': address,
        'phone': phone,
        'owner': owner,
        'taxCode': taxCode,
      };
}

class StoreManager {
  final String employeeId;
  final String name;
  final String employeeCode;
  final String? email;
  final String storeRole;

  StoreManager({
    required this.employeeId,
    required this.name,
    required this.employeeCode,
    this.email,
    this.storeRole = 'PG',
  });

  factory StoreManager.fromJson(Map<String, dynamic> json) {
    return StoreManager(
      employeeId: json['employeeId'] as String,
      name: json['name'] as String,
      employeeCode: json['employeeCode'] as String,
      email: json['email'] as String?,
      storeRole: json['storeRole'] as String? ?? 'PG',
    );
  }

  Map<String, dynamic> toJson() => {
        'employeeId': employeeId,
        'name': name,
        'employeeCode': employeeCode,
        'email': email,
        'storeRole': storeRole,
      };
}
