import 'package:flutter/material.dart';

/// On desktop (width >= breakpoint), arranges children into 2 balanced
/// columns side-by-side. On smaller screens, falls back to a single column.
class DesktopTwoCol extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double breakpoint;

  const DesktopTwoCol({
    super.key,
    required this.children,
    this.spacing = 16,
    this.breakpoint = 1280,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < breakpoint || children.length < 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            children[i],
          ],
        ],
      );
    }

    final left = <Widget>[];
    final right = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      (i.isEven ? left : right).add(children[i]);
    }

    Widget col(List<Widget> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(height: spacing),
              items[i],
            ],
          ],
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: col(left)),
        SizedBox(width: spacing),
        Expanded(child: col(right)),
      ],
    );
  }
}

/// Constrains content to a max width and centers it. Useful for desktop pages
/// to avoid stretching too wide on ultra-wide displays.
class DesktopMaxWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const DesktopMaxWidth({
    super.key,
    required this.child,
    this.maxWidth = 1440,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
