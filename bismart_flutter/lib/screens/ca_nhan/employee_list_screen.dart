import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../models/employee.dart';
import '../../providers/employee_provider.dart';
import '../../providers/store_provider.dart';
import '../../widgets/common/responsive_form.dart';
import '../../widgets/common/screen_header_card.dart';
import '../../widgets/common/gradient_fab.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  String _searchQuery = '';
  String _selectedPosition = 'Tất cả';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeProvider>().loadEmployees();
      context.read<StoreProvider>().loadStores();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const SizedBox.shrink(),
      ),
      floatingActionButton: GradientFab(
        icon: Icons.add_rounded,
        tooltip: 'Thêm nhân viên',
        onPressed: () => _showAddEmployeeDialog(context),
      ),
      body: Consumer<EmployeeProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.employees.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final employees = provider.employees.where((e) {
            final matchSearch = _searchQuery.isEmpty ||
                e.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                e.employeeCode.contains(_searchQuery);
            final matchPosition = _selectedPosition == 'Tất cả' ||
                e.position == _selectedPosition;
            return matchSearch && matchPosition;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: ScreenHeaderCard(
                  icon: Icons.badge_rounded,
                  iconColor: AppColors.primary,
                  iconBg: AppColors.primaryLight,
                  title: 'Danh sách nhân viên',
                  subtitle: '${employees.length} nhân viên',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  decoration: AppDecorations.searchField('Tìm kiếm nhân viên...'),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: ['Tất cả', 'ADM', 'PG', 'TLD', 'MNG', 'CS'].map((pos) {
                    final selected = _selectedPosition == pos;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(pos),
                        selected: selected,
                        selectedColor: AppColors.primaryLight,
                        checkmarkColor: AppColors.primary,
                        onSelected: (_) {
                          setState(() => _selectedPosition = pos);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '${employees.length} nhân viên',
                      style: AppTextStyles.caption,
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: employees.isEmpty
                    ? Center(
                        child: Text('Không có nhân viên phù hợp', style: AppTextStyles.caption),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                        child: Container(
                          decoration: AppDecorations.card,
                          clipBehavior: Clip.antiAlias,
                          child: ListView.separated(
                            itemCount: employees.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              indent: 14,
                              endIndent: 14,
                              color: AppColors.divider,
                            ),
                            itemBuilder: (context, index) {
                              final emp = employees[index];
                              return InkWell(
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.employeeDetail,
                                    arguments: emp,
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [AppColors.gradientStart, AppColors.gradientEnd],
                                          ),
                                          borderRadius: BorderRadius.circular(AppRadius.row - 2),
                                        ),
                                        child: Center(
                                          child: Text(
                                            emp.fullName.isNotEmpty
                                                ? emp.fullName[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              color: AppColors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
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
                                              emp.fullName,
                                              style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w500),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${emp.employeeCode} · ${emp.positionLabel}',
                                              style: AppTextStyles.caption,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius: BorderRadius.circular(AppRadius.pill),
                                        ),
                                        child: Text(
                                          emp.position,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddEmployeeDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String selectedPosition = 'PG';
    String? selectedStoreCode;

    showResponsiveForm(
      context: context,
      title: 'Thêm nhân viên',
      contentBuilder: (ctx, setDialogState) {
        final stores = this.context.watch<StoreProvider>().stores;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Họ tên *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(labelText: 'Mã nhân viên *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedStoreCode,
              decoration: const InputDecoration(labelText: 'Mã cửa hàng (nơi làm việc)'),
              items: stores
                  .map((s) => DropdownMenuItem(
                        value: s.storeCode,
                        child: Text('${s.storeCode} - ${s.name}'),
                      ))
                  .toList(),
              onChanged: (v) => setDialogState(() => selectedStoreCode = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedPosition,
              decoration: const InputDecoration(labelText: 'Vị trí'),
              items: ['ADM', 'PG', 'TLD', 'MNG', 'CS']
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setDialogState(() => selectedPosition = v!),
            ),
          ],
        );
      },
      actionsBuilder: (ctx, setDialogState) {
        final stores = this.context.read<StoreProvider>().stores;
        return [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isEmpty || codeCtrl.text.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng nhập họ tên và mã nhân viên'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              final provider = this.context.read<EmployeeProvider>();
              final selectedStore = stores.cast<dynamic>().firstWhere(
                (s) => s.storeCode == selectedStoreCode,
                orElse: () => null,
              );
              provider.addEmployee(Employee(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                fullName: nameCtrl.text,
                employeeCode: codeCtrl.text,
                position: selectedPosition,
                workLocation: selectedStore?.name ?? '',
                storeCode: selectedStoreCode,
                email: emailCtrl.text.isNotEmpty ? emailCtrl.text : null,
              ));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text('Đã thêm nhân viên "${nameCtrl.text}"'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: const Text('Thêm'),
          ),
        ];
      },
    );
  }
}
