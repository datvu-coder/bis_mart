import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// A fully-rounded, color-coded status label — tinted background + bold
/// text in the same color, no icon or border. One shared look for every
/// "state at a glance" badge in the app (attendance, lesson progress,
/// order status) instead of each screen picking its own chip style.
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const StatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
