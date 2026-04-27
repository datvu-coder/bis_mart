import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class DataPanel extends StatelessWidget {
  final String? title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  const DataPanel({
    super.key,
    this.title,
    required this.child,
    this.trailing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final hasTitle = title != null && title!.isNotEmpty;
    final hasHeader = hasTitle || trailing != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppDecorations.card,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasHeader) ...[
              Row(
                mainAxisAlignment: hasTitle
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.end,
                children: [
                  if (hasTitle)
                    Flexible(
                      child:
                          Text(title!, style: AppTextStyles.sectionHeader),
                    ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 18),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
