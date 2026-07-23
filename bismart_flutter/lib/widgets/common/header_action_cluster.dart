import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// One action inside a [HeaderActionCluster].
class HeaderAction {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onPressed;
  final Color? color;

  const HeaderAction({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
  });
}

/// A single rounded pill grouping 2+ icon actions together — the same
/// top-right cluster pattern iOS system apps use (search / secondary action
/// / overflow all inside one capsule) instead of scattering separate icon
/// buttons across a header or AppBar.
class HeaderActionCluster extends StatelessWidget {
  final List<HeaderAction> actions;

  const HeaderActionCluster({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in actions)
            IconButton(
              icon: Icon(action.icon, size: 20),
              color: action.color ?? AppColors.textPrimary,
              tooltip: action.tooltip,
              onPressed: action.onPressed,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
