import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// One action inside a [HeaderActionCluster]. `label` is shown as the menu
/// text when there are multiple actions (and doubles as the tooltip when
/// there's just one), so it's required even though a lone action doesn't
/// display it directly.
class HeaderAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  const HeaderAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });
}

/// Top-right header actions, styled after the iOS system-app pattern (e.g.
/// Reminders' list screen: a single Share icon plus one "..." menu holding
/// everything else, including a destructive action at the bottom) instead
/// of a row of separate icon buttons:
/// - One action → a single plain icon button.
/// - 2+ actions → one "..." icon that opens a dropdown menu listing them,
///   so the header never shows more than one extra tap target.
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
      child: actions.length == 1 ? _singleIcon(actions.single) : _overflowMenu(),
    );
  }

  Widget _singleIcon(HeaderAction action) {
    return IconButton(
      icon: Icon(action.icon, size: 20),
      color: action.color ?? AppColors.textPrimary,
      tooltip: action.label,
      onPressed: action.onPressed,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _overflowMenu() {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.more_horiz_rounded, size: 20, color: AppColors.textPrimary),
      tooltip: 'Thêm',
      onSelected: (i) => actions[i].onPressed(),
      itemBuilder: (context) => [
        for (var i = 0; i < actions.length; i++)
          PopupMenuItem(
            value: i,
            child: Row(
              children: [
                Icon(actions[i].icon, size: 18, color: actions[i].color ?? AppColors.textSecondary),
                const SizedBox(width: 12),
                Text(
                  actions[i].label,
                  style: TextStyle(color: actions[i].color ?? AppColors.textPrimary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
