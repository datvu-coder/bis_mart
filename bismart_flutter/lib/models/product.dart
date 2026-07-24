/// One level of a product's "Quy đổi" (unit conversion) chain. The
/// product's base `unit` is its largest sale unit (e.g. Thùng); each
/// conversion level is a progressively smaller sale unit (e.g. Lốc, then
/// Hộp), with its own independently set selling price.
class ProductConversion {
  final String unit;
  final double price;

  const ProductConversion({
    required this.unit,
    required this.price,
  });

  factory ProductConversion.fromJson(Map<String, dynamic> json) {
    return ProductConversion(
      unit: json['unit'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'unit': unit,
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
