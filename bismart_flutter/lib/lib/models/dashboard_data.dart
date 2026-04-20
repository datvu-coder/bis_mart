class DashboardData {
  final DateTime date;
  final String announcement;
  final List<String> featuredPrograms;
  final List<TopEmployee> top10;
  final double groupRevenue;
  final double totalRevenue;
  final List<DailyRevenue> revenueChart;
  final List<ProductSales> productChart;

  DashboardData({
    required this.date,
    required this.announcement,
    this.featuredPrograms = const [],
    this.top10 = const [],
    this.groupRevenue = 0,
    this.totalRevenue = 0,
    this.revenueChart = const [],
    this.productChart = const [],
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      date: DateTime.parse(json['date'] as String),
      announcement: json['announcement'] as String,
      featuredPrograms: (json['featuredPrograms'] as List<dynamic>?)
              ?.map((p) => p as String)
              .toList() ??
          [],
      top10: (json['top10'] as List<dynamic>?)
              ?.map((e) => TopEmployee.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      groupRevenue: (json['groupRevenue'] as num?)?.toDouble() ?? 0,
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0,
      revenueChart: (json['revenueChart'] as List<dynamic>?)
              ?.map((r) => DailyRevenue.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      productChart: (json['productChart'] as List<dynamic>?)
              ?.map((p) => ProductSales.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class TopEmployee {
  final int rank;
  final String name;

  TopEmployee({required this.rank, required this.name});

  factory TopEmployee.fromJson(Map<String, dynamic> json) {
    return TopEmployee(
      rank: json['rank'] as int,
      name: json['name'] as String,
    );
  }
}

class DailyRevenue {
  final DateTime date;
  final double revenue;
  final double target;

  DailyRevenue({
    required this.date,
    this.revenue = 0,
    this.target = 0,
  });

  factory DailyRevenue.fromJson(Map<String, dynamic> json) {
    return DailyRevenue(
      date: DateTime.parse(json['date'] as String),
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      target: (json['target'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ProductSales {
  final String productName;
  final int quantity;

  ProductSales({required this.productName, required this.quantity});

  factory ProductSales.fromJson(Map<String, dynamic> json) {
    return ProductSales(
      productName: json['productName'] as String,
      quantity: json['quantity'] as int,
    );
  }
}
