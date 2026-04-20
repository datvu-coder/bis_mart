class SalesReport {
  final String id;
  final DateTime date;
  final String pgName;
  final int nu;
  final double saleOut;
  final List<SaleItem> products;
  final double revenue;
  final String? storeName;
  final String? storeCode;
  final String? reportMonth;
  final int points;
  final String? employeeCode;

  SalesReport({
    required this.id,
    required this.date,
    required this.pgName,
    this.nu = 0,
    this.saleOut = 0,
    this.products = const [],
    required this.revenue,
    this.storeName,
    this.storeCode,
    this.reportMonth,
    this.points = 0,
    this.employeeCode,
  });

  factory SalesReport.fromJson(Map<String, dynamic> json) {
    return SalesReport(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      pgName: json['pgName'] as String,
      nu: json['nu'] as int? ?? 0,
      saleOut: (json['saleOut'] as num?)?.toDouble() ?? 0,
      products: (json['products'] as List<dynamic>?)
              ?.map((p) => SaleItem.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      revenue: (json['revenue'] as num).toDouble(),
      storeName: json['storeName'] as String?,
      storeCode: json['storeCode'] as String?,
      reportMonth: json['reportMonth'] as String?,
      points: json['points'] as int? ?? 0,
      employeeCode: json['employeeCode'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'pgName': pgName,
        'nu': nu,
        'saleOut': saleOut,
        'products': products.map((p) => p.toJson()).toList(),
        'revenue': revenue,
        'storeName': storeName,
        'storeCode': storeCode,
        'reportMonth': reportMonth,
        'employeeCode': employeeCode,
      };
}

class SaleItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final String? unit;
  final String? productGroup;

  SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.unit,
    this.productGroup,
  });

  double get total => quantity * unitPrice;

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      quantity: json['quantity'] as int,
      unitPrice: (json['unitPrice'] as num).toDouble(),
      unit: json['unit'] as String?,
      productGroup: json['productGroup'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };
}
