import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand — warm terracotta on ivory, replacing the earlier bright-orange
  // Material palette (see the "Bi'S MART — Thiết kế mới" design mockup).
  static const primary = Color(0xFFC1622B);
  static const primaryDark = Color(0xFF9A4A1E);
  static const primaryLight = Color(0xFFF4E3D4);
  static const accent = Color(0xFFC1622B);

  // Surfaces
  static const background = Color(0xFFFBF7F1);
  static const cardBg = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF1ECE3);
  static const surfaceElevated = Color(0xFFFFFFFF);

  // Text — warm ink instead of cool slate
  static const textDark = Color(0xFF2A241D);
  static const textPrimary = Color(0xFF2A241D);
  static const textSecondary = Color(0xFF786F62);
  static const textGrey = Color(0xFFA79885);
  static const textHint = Color(0xFFBBAE9C);

  // Borders & dividers
  static const border = Color(0xFFEDE3D6);
  static const borderLight = Color(0xFFF3ECE1);
  static const divider = Color(0xFFEDE3D6);

  // Status — tinted to the warm neutral ground instead of cool grays
  static const success = Color(0xFF4C7A5D);
  static const successLight = Color(0xFFE3EFE6);
  static const warning = Color(0xFFB98A2A);
  static const warningLight = Color(0xFFF5EBD3);
  static const error = Color(0xFFB14A3D);
  static const errorLight = Color(0xFFF5E1DE);
  static const info = Color(0xFF3E6E82);
  static const infoLight = Color(0xFFE1EEF1);

  // Misc
  static const white = Color(0xFFFFFFFF);

  // Sidebar — light elegant theme
  static const sidebarBg = Color(0xFFFFFFFF);
  static const sidebarSurface = Color(0xFFF4E3D4); // warm primary tint for active
  static const sidebarSurfaceHover = Color(0xFFF7F2EA);
  static const sidebarText = Color(0xFF786F62);
  static const sidebarActive = Color(0xFFC1622B); // brand terracotta
  static const sidebarBorder = Color(0xFFEDE3D6);
  static const sidebarMuted = Color(0xFFA79885);

  // Gradients — dark overlay only (video thumbnails), unrelated to the
  // warm brand palette above.
  static const gradientStart = Color(0xFFC1622B);
  static const gradientEnd = Color(0xFF9A4A1E);
  static const gradientDarkStart = Color(0xFF0F172A);
  static const gradientDarkEnd = Color(0xFF1E293B);

  // Shadows — warm-tinted ink instead of pure black
  static const shadow = Color(0x142A241D);
  static const shadowMedium = Color(0x1A2A241D);

  // Purple — dùng cho Phân quyền (admin)
  static const purpleAccent = Color(0xFF7C3AED);
  static const purpleLight  = Color(0xFFF5F3FF);
}
