import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/nhan_su/nhan_su_screen.dart';
import '../../screens/kinh_doanh/kinh_doanh_screen.dart';
import '../../screens/dao_tao/dao_tao_screen.dart';
import '../../screens/ca_nhan/ca_nhan_screen.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _selectedIndex;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static const _navItems = [
    _NavItem(Icons.dashboard_outlined, Icons.dashboard_rounded, AppStrings.dashboard),
    _NavItem(Icons.people_outline_rounded, Icons.people_rounded, AppStrings.nhanSu),
    _NavItem(Icons.trending_up_rounded, Icons.trending_up_rounded, AppStrings.kinhDoanh),
    _NavItem(Icons.school_outlined, Icons.school_rounded, AppStrings.daoTao),
    _NavItem(Icons.person_outline_rounded, Icons.person_rounded, AppStrings.caNhan),
  ];

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleLogout() {
    context.read<AuthProvider>().logout();
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            _DesktopSidebar(
              selectedIndex: _selectedIndex,
              onItemTap: _onNavTap,
              onLogout: _handleLogout,
              isExpanded: width >= 1100,
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _selectedIndex = i),
                children: const [
                  DashboardScreen(),
                  NhanSuScreen(),
                  KinhDoanhScreen(),
                  DaoTaoScreen(),
                  CaNhanScreen(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (i) => setState(() => _selectedIndex = i),
          children: const [
            DashboardScreen(),
            NhanSuScreen(),
            KinhDoanhScreen(),
            DaoTaoScreen(),
            CaNhanScreen(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 4),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
          child: _FloatingNavBar(
            items: _navItems,
            selectedIndex: _selectedIndex,
            onTap: _onNavTap,
          ),
        ),
      ),
    );
  }
}

/// Bottom nav as a floating rounded card with a gap from the screen edges,
/// the active item's icon+label wrapped in one tinted pill — instead of a
/// full-width bar flush with the edges.
class _FloatingNavBar extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _FloatingNavItem(
                item: items[i],
                isSelected: i == selectedIndex,
                onTap: () => onTap(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _FloatingNavItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _FloatingNavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? item.selectedIcon : item.icon,
                size: 21,
                color: isSelected ? AppColors.primary : AppColors.textGrey,
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Modern Dark Sidebar ---
class _DesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTap;
  final VoidCallback onLogout;
  final bool isExpanded;

  const _DesktopSidebar({
    required this.selectedIndex,
    required this.onItemTap,
    required this.onLogout,
    required this.isExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: isExpanded ? 264 : 84,
      decoration: BoxDecoration(
        color: AppColors.sidebarBg,
        border: const Border(
          right: BorderSide(color: AppColors.sidebarBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 24,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          _buildLogo(),
          const SizedBox(height: 12),
          if (isExpanded)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22),
              child: Divider(color: AppColors.sidebarBorder, height: 1, thickness: 1),
            ),
          const SizedBox(height: 16),

          // Section label
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 4, 22, 10),
              child: Row(
                children: [
                  Text(
                    'MENU CHÍNH',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.sidebarMuted.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),

          // Nav items
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  ..._buildNavItems(),
                  const Spacer(),
                  if (isExpanded && user != null) ...[
                    _buildUserInfo(user),
                    const SizedBox(height: 12),
                  ],
                  _buildNavTile(
                    icon: Icons.logout_rounded,
                    label: AppStrings.dangXuat,
                    isSelected: false,
                    onTap: onLogout,
                    isLogout: true,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        mainAxisAlignment:
            isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  AppStrings.appName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  'Business Suite',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.sidebarMuted.withValues(alpha: 0.9),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildNavItems() {
    const items = _MainShellState._navItems;
    return List.generate(items.length, (i) {
      final item = items[i];
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: _buildNavTile(
          icon: selectedIndex == i ? item.selectedIcon : item.icon,
          label: item.label,
          isSelected: selectedIndex == i,
          onTap: () => onItemTap(i),
        ),
      );
    });
  }

  Widget _buildNavTile({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    final color = isLogout
        ? AppColors.error
        : isSelected
            ? AppColors.sidebarActive
            : AppColors.sidebarText;

    if (!isExpanded) {
      return Tooltip(
        message: label,
        preferBelow: false,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.sidebarSurface
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: color, size: 22),
                if (isSelected)
                  Positioned(
                    left: -2,
                    top: 12,
                    bottom: 12,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.sidebarSurface
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.12), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            if (isSelected && !isLogout)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo(dynamic user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.sidebarSurfaceHover,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sidebarBorder, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  user.position ?? '',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.sidebarMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem(this.icon, this.selectedIcon, this.label);
}
