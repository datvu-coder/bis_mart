class SalesReport {
  final String id;
  final DateTime date;
  final String pgName;
  final int nu;
  final double revenueN1;
  final List<SaleItem> products;
  final double revenue;

  SalesReport({
    required this.id,
    required this.date,
    required this.pgName,
    this.nu = 0,
    this.revenueN1 = 0,
    this.products = const [],
    required this.revenue,
  });

  factory SalesReport.fromJson(Map<String, dynamic> json) {
    return SalesReport(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      pgName: json['pgName'] as String,
      nu: json['nu'] as int? ?? 0,
      revenueN1: (json['revenueN1'] as num?)?.toDouble() ?? 0,
      products: (json['products'] as List<dynamic>?)
              ?.map((p) => SaleItem.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      revenue: (json['revenue'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'pgName': pgName,
        'nu': nu,
        'revenueN1': revenueN1,
        'products': products.map((p) => p.toJson()).toList(),
        'revenue': revenue,
      };
}

class SaleItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;

  SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => quantity * unitPrice;

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      quantity: json['quantity'] as int,
      unitPrice: (json['unitPrice'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };
}
