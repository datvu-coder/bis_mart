import 'package:flutter/material.dart';

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
