class Product {
  final String id;
  final String name;
  final String unit; // Lon | Hộp | Gói
  final double priceWithVAT;
  final String productGroup; // DELI | DELIMIL | AUMIL | GOODLIFE | TP
  final String? productCondition;

  Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.priceWithVAT,
    required this.productGroup,
    this.productCondition,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      unit: json['unit'] as String,
      priceWithVAT: (json['priceWithVAT'] as num).toDouble(),
      productGroup: json['productGroup'] as String,
      productCondition: json['productCondition'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'priceWithVAT': priceWithVAT,
        'productGroup': productGroup,
        'productCondition': productCondition,
      };
}
