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

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const NhanSuScreen();
      case 2:
        return const KinhDoanhScreen();
      case 3:
        return const DaoTaoScreen();
      case 4:
        return const CaNhanScreen();
      default:
        return const DashboardScreen();
    }
  }

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
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: AppColors.sidebarBorder, width: 1),
        ),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppColors.textDark),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          _navItems[_selectedIndex].label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.textHint, size: 22),
            onPressed: _handleLogout,
            tooltip: AppStrings.dangXuat,
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: _MobileDrawer(
        selectedIndex: _selectedIndex,
        onItemTap: (i) {
          _onNavTap(i);
          Navigator.pop(context);
        },
        onLogout: () {
          Navigator.pop(context);
          _handleLogout();
        },
      ),
      body: PageView(
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
    );
  }
}

// --- Mobile Drawer ---
class _MobileDrawer extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTap;
  final VoidCallback onLogout;

  const _MobileDrawer({
    required this.selectedIndex,
    required this.onItemTap,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Drawer(
      backgroundColor: AppColors.sidebarBg,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Logo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.gradientStart, AppColors.gradientEnd],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('B',
                        style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(AppStrings.appName,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark, letterSpacing: -0.4)),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // User info
            if (user != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.sidebarSurfaceHover,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.sidebarBorder, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.gradientStart, AppColors.gradientEnd],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                          style: const TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.fullName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                            overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(user.positionLabel,
                            style: const TextStyle(fontSize: 12, color: AppColors.sidebarMuted, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Nav items
            ...List.generate(_MainShellState._navItems.length, (i) {
              final item = _MainShellState._navItems[i];
              final isSelected = selectedIndex == i;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                child: InkWell(
                  onTap: () => onItemTap(i),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.sidebarSurface : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: AppColors.primary.withValues(alpha: 0.12), width: 1)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? item.selectedIcon : item.icon,
                          color: isSelected ? AppColors.sidebarActive : AppColors.sidebarText,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? AppColors.sidebarActive : AppColors.sidebarText,
                            ),
                          ),
                        ),
                        if (isSelected)
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
                ),
              );
            }),

            const Spacer(),

            // Logout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: InkWell(
                onTap: onLogout,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
                      const SizedBox(width: 14),
                      Text(AppStrings.dangXuat,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.error)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
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
              gradient: const LinearGradient(
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'B',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: -0.5,
                ),
              ),
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
              gradient: const LinearGradient(
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
              ),
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
