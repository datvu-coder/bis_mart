import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_routes.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'models/employee.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/nhan_su/employee_detail_screen.dart';
import 'screens/kinh_doanh/create_report_screen.dart';
import 'screens/ca_nhan/store_list_screen.dart';
import 'screens/ca_nhan/employee_list_screen.dart';
import 'screens/ca_nhan/product_list_screen.dart';
import 'screens/ca_nhan/phan_quyen_screen.dart';
import 'widgets/common/main_shell.dart';

class BismartApp extends StatelessWidget {
  const BismartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const _SplashGate(),
      onGenerateRoute: _onGenerateRoute,
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    Widget page;

    switch (settings.name) {
      case AppRoutes.login:
        page = const LoginScreen();
        break;
      case AppRoutes.dashboard:
        page = const MainShell(initialIndex: 0);
        break;
      case AppRoutes.nhanSu:
        page = const MainShell(initialIndex: 1);
        break;
      case AppRoutes.kinhDoanh:
        page = const MainShell(initialIndex: 2);
        break;
      case AppRoutes.daoTao:
        page = const MainShell(initialIndex: 3);
        break;
      case AppRoutes.caNhan:
        page = const MainShell(initialIndex: 4);
        break;
      case AppRoutes.employeeDetail:
        final employee = settings.arguments as Employee;
        page = EmployeeDetailScreen(employee: employee);
        break;
      case AppRoutes.createReport:
        page = const CreateReportScreen();
        break;
      case AppRoutes.storeList:
        page = const StoreListScreen();
        break;
      case AppRoutes.employeeList:
        page = const EmployeeListScreen();
        break;
      case AppRoutes.productList:
        page = const ProductListScreen();
              case AppRoutes.phanQuyen:
                page = const PhanQuyenScreen();
                break;
        break;
      default:
        page = const MainShell(initialIndex: 0);
    }

    return MaterialPageRoute(
      builder: (_) => page,
      settings: settings,
    );
  }
}

class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final auth = context.read<AuthProvider>();
    await auth.checkAuthStatus();
    if (!mounted) return;

    if (auth.isLoggedIn) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
