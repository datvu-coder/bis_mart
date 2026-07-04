import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';

class FilterDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const FilterDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textGrey),
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
          items: const [
            DropdownMenuItem(
              value: 'today',
              child: Text(AppStrings.homNay),
            ),
            DropdownMenuItem(
              value: 'week',
              child: Text(AppStrings.tuanNay),
            ),
            DropdownMenuItem(
              value: 'month',
              child: Text(AppStrings.thangNay),
            ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
