import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Desktop tab selector with equal-width layout.
/// All tabs share the same width for visual symmetry. Custom flex weights
/// can still be supplied via the `flexes` parameter when needed.
class WeightedTabSelector extends StatelessWidget {
  final TabController controller;
  final List<String> labels;
  final List<int>? flexes;

  const WeightedTabSelector({
    super.key,
    required this.controller,
    required this.labels,
    this.flexes,
  });

  List<int> _defaultFlexes() {
    return List<int>.filled(labels.length, 1);
  }

  @override
  Widget build(BuildContext context) {
    final f = flexes ?? _defaultFlexes();
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          children: List.generate(labels.length, (i) {
            final selected = controller.index == i;
            return Expanded(
              flex: i < f.length ? f[i] : 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Material(
                  color: selected ? AppColors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => controller.animateTo(i),
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        labels[i],
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textGrey,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
