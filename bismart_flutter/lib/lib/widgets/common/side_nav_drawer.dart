import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';

class SideNavDrawer extends StatelessWidget {
  final String currentRoute;

  const SideNavDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return NavigationDrawer(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) => _onItemTap(context, index),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'B',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                AppStrings.appName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const Divider(indent: 24, endIndent: 24),
        const NavigationDrawerDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text(AppStrings.dashboard),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: Text(AppStrings.nhanSu),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.trending_up_outlined),
          selectedIcon: Icon(Icons.trending_up),
          label: Text(AppStrings.kinhDoanh),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.school_outlined),
          selectedIcon: Icon(Icons.school),
          label: Text(AppStrings.daoTao),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: Text(AppStrings.caNhan),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Divider(),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.power_settings_new),
          label: Text(AppStrings.dangXuat),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.info_outline),
          selectedIcon: Icon(Icons.info),
          label: Text(AppStrings.thongTin),
        ),
      ],
    );
  }

  int get _selectedIndex {
    switch (currentRoute) {
      case AppRoutes.dashboard:
        return 0;
      case AppRoutes.nhanSu:
        return 1;
      case AppRoutes.kinhDoanh:
        return 2;
      case AppRoutes.daoTao:
        return 3;
      case AppRoutes.caNhan:
        return 4;
      default:
        return 0;
    }
  }

  void _onItemTap(BuildContext context, int index) {
    Navigator.pop(context); // Close drawer

    String route;
    switch (index) {
      case 0:
        route = AppRoutes.dashboard;
        break;
      case 1:
        route = AppRoutes.nhanSu;
        break;
      case 2:
        route = AppRoutes.kinhDoanh;
        break;
      case 3:
        route = AppRoutes.daoTao;
        break;
      case 4:
        route = AppRoutes.caNhan;
        break;
      case 5:
        // Logout
        context.read<AuthProvider>().logout();
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
        return;
      case 6:
        route = AppRoutes.dashboard;
        break;
      default:
        route = AppRoutes.dashboard;
    }

    if (currentRoute != route) {
      Navigator.pushReplacementNamed(context, route);
    }
  }
}
