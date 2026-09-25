import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';
import '../../models/dashboard_data.dart';

class RevenueBarChart extends StatelessWidget {
  final List<DailyRevenue> data;

  const RevenueBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // All-zero data still passes `isEmpty`, but a maxY of 0 gives fl_chart
    // a zero-height axis range — it renders nothing at all (no bars, no
    // gridlines, no labels), which reads as a broken blank card instead of
    // "no data yet".
    if (data.isEmpty || _maxY == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded, size: 32, color: AppColors.textHint),
            const SizedBox(height: 8),
            Text('Chưa có dữ liệu doanh số', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
          ],
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 1.6,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${(rod.toY / 1000000).toStringAsFixed(1)}M',
                  const TextStyle(color: AppColors.white, fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${data[index].date.day}/${data[index].date.month}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${(value / 1000000).toStringAsFixed(0)}M',
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
                  toY: entry.value.revenue,
                  color: AppColors.primary,
                  width: 14,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
                BarChartRodData(
                  toY: entry.value.target,
                  color: AppColors.primaryLight,
                  width: 14,
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

  double get _maxY {
    double max = 0;
    for (final d in data) {
      if (d.revenue > max) max = d.revenue;
      if (d.target > max) max = d.target;
    }
    return max * 1.2;
  }
}
