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
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: contentBuilder(ctx, setState),
                    ),
                    // Numeric keypads (e.g. iOS) have no built-in Done key,
                    // and the action buttons below live in bottomNavigationBar
                    // which the keyboard covers — without this, a focused
                    // numeric field leaves no way to dismiss the keyboard.
                    if (MediaQuery.of(ctx).viewInsets.bottom > 0)
                      Positioned(
                        right: 12,
                        bottom: 8,
                        child: Material(
                          color: AppColors.textDark,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => FocusScope.of(ctx).unfocus(),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.keyboard_hide_rounded,
                                      size: 16, color: AppColors.white),
                                  SizedBox(width: 6),
                                  Text('Xong',
                                      style: TextStyle(
                                          color: AppColors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
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
