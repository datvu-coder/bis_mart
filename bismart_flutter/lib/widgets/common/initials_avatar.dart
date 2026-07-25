import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Circular avatar showing a person's initials (first + last name word)
/// instead of a generic icon — used anywhere an employee is listed so the
/// list reads as people rather than rows of data.
class InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? background;
  final Color? foreground;

  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 38,
    this.background,
    this.foreground,
  });

  static String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? AppColors.primaryLight,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initialsOf(name),
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: foreground ?? AppColors.primary,
        ),
      ),
    );
  }
}
