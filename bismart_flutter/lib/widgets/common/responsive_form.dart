import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Shows a form as a full-screen page on mobile (proper native feel, no
/// cramped centered box) and as a centered dialog on wider/desktop screens.
///
/// [contentBuilder] and [actionsBuilder] receive the same `setState` so
/// existing dialog code that used `StatefulBuilder` can be ported by simply
/// splitting its `content:`/`actions:` into these two callbacks.
Future<T?> showResponsiveForm<T>({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext context, StateSetter setState) contentBuilder,
  required List<Widget> Function(BuildContext context, StateSetter setState) actionsBuilder,
  double desktopWidth = 480,
}) {
  final isMobile = MediaQuery.of(context).size.width < 700;

  if (isMobile) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (routeContext) => StatefulBuilder(
          builder: (ctx, setState) {
            final actions = actionsBuilder(ctx, setState);
            return Scaffold(
              appBar: AppBar(
                title: Text(title),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: contentBuilder(ctx, setState),
                ),
              ),
              bottomNavigationBar: actions.isEmpty
                  ? null
                  : SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          border: Border(top: BorderSide(color: AppColors.surfaceVariant)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            for (int i = 0; i < actions.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              actions[i],
                            ],
                          ],
                        ),
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }

  return showDialog<T>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: desktopWidth,
          child: SingleChildScrollView(child: contentBuilder(ctx, setState)),
        ),
        actions: actionsBuilder(ctx, setState),
      ),
    ),
  );
}
