import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';
import '../../models/dashboard_data.dart';

class ProductHChart extends StatelessWidget {
  final List<ProductSales> data;

  const ProductHChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // All-zero data still passes `isEmpty`, but a maxY of 0 gives fl_chart
    // a zero-height axis range — it renders nothing at all (no bars, no
    // gridlines, no labels), which reads as a broken blank card instead of
    // "no data yet".
    if (data.isEmpty || _maxQuantity == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pie_chart_rounded, size: 32, color: AppColors.textHint),
            const SizedBox(height: 8),
            Text('Chưa có dữ liệu sản phẩm', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
          ],
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 1.4,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _maxQuantity * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final product = data[group.x.toInt()];
                return BarTooltipItem(
                  '${product.productName}\n${product.quantity}',
                  const TextStyle(color: AppColors.white, fontSize: 11),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.length) {
                    return const SizedBox.shrink();
                  }
                  final name = data[index].productName;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      name.length > 12 ? '${name.substring(0, 12)}...' : name,
                      style: const TextStyle(fontSize: 8),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(
            show: true,
            drawVerticalLine: false,
          ),
          barGroups: data.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.quantity.toDouble(),
                  color: AppColors.primary,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  double get _maxQuantity {
    double max = 0;
    for (final d in data) {
      if (d.quantity > max) max = d.quantity.toDouble();
    }
    return max;
  }
}
