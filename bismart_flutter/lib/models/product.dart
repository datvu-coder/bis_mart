/// One level of a product's "Quy đổi" (unit conversion) chain, e.g.
/// 6 Hộp = 1 Lốc, 24 Lốc = 1 Thùng. `quantity` is how many of the
/// *previous* level (the base unit for the first entry) make up one of
/// this `unit`. `price` is fully custom per level, not derived from the
/// base price.
class ProductConversion {
  final String unit;
  final double quantity;
  final double price;

  const ProductConversion({
    required this.unit,
    required this.quantity,
    required this.price,
  });

  factory ProductConversion.fromJson(Map<String, dynamic> json) {
    return ProductConversion(
      unit: json['unit'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'unit': unit,
        'quantity': quantity,
        'price': price,
      };
}

class Product {
  final String id;
  final String name;
  final String unit; // Lon | Hộp | Gói
  final double priceWithVAT;
  final String productGroup; // DELI | DELIMIL | AUMIL | GOODLIFE | TP
  final String? productCondition;
  final String? barcode;
  final String? imageUrl;
  final List<ProductConversion> conversions;

  Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.priceWithVAT,
    required this.productGroup,
    this.productCondition,
    this.barcode,
    this.imageUrl,
    this.conversions = const [],
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawConversions = json['conversions'] as List<dynamic>?;
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      unit: json['unit'] as String,
      priceWithVAT: (json['priceWithVAT'] as num).toDouble(),
      productGroup: json['productGroup'] as String,
      productCondition: json['productCondition'] as String?,
      barcode: json['barcode'] as String?,
      imageUrl: json['imageUrl'] as String?,
      conversions: rawConversions == null
          ? const []
          : rawConversions
              .map((c) => ProductConversion.fromJson(c as Map<String, dynamic>))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'priceWithVAT': priceWithVAT,
        'productGroup': productGroup,
        'productCondition': productCondition,
        'barcode': barcode,
        'imageUrl': imageUrl,
        'conversions': conversions.map((c) => c.toJson()).toList(),
      };
}
