import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/product.dart';
import '../../models/sales_report.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/sales_provider.dart';

class CreateReportScreen extends StatefulWidget {
  const CreateReportScreen({super.key});

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
  int _nu = 0;
  final _saleOutController = TextEditingController();
  final _revenueController = TextEditingController();
  final List<SaleItem> _products = [];
  bool _isSubmitting = false;
  SalesReport? _editingReport;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_editingReport == null) {
      final arg = ModalRoute.of(context)?.settings.arguments;
      if (arg is SalesReport) {
        _editingReport = arg;
        _selectedDate = arg.date;
        _nu = arg.nu;
        _saleOutController.text = arg.saleOut.toStringAsFixed(0);
        _revenueController.text = arg.revenue.toStringAsFixed(0);
        _products.addAll(arg.products);
      }
    }

    final productProvider = context.read<ProductProvider>();
    if (!productProvider.isLoading && productProvider.products.isEmpty) {
      productProvider.loadProducts();
    }
  }

  @override
  void dispose() {
    _saleOutController.dispose();
    _revenueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_editingReport != null ? 'Chỉnh sửa báo cáo' : AppStrings.taoPhieuBaoCao),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.taoPhieuBaoCao, style: AppTextStyles.appTitle),
                const SizedBox(height: 4),
                Text('Điền thông tin báo cáo bán hàng hàng ngày',
                    style: AppTextStyles.caption),
                const SizedBox(height: 24),

                // Date picker
                _buildLabel(AppStrings.ngay, required: true),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      suffixIcon: Icon(Icons.calendar_today_rounded, size: 20),
                    ),
                    child: Text(
                      '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                      style: AppTextStyles.bodyText,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // PG (auto-fill)
                _buildLabel(AppStrings.pg, required: true),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_rounded, size: 18, color: AppColors.textGrey),
                      const SizedBox(width: 10),
                      Text(user?.fullName ?? 'N/A', style: AppTextStyles.bodyText),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // NU stepper
                _buildLabel(AppStrings.nu),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (_nu > 0) setState(() => _nu--);
                        },
                        icon: const Icon(Icons.remove_circle_rounded, size: 22),
                        color: AppColors.primary,
                      ),
                      Container(
                        width: 48,
                        alignment: Alignment.center,
                        child: Text(
                          '$_nu',
                          style: AppTextStyles.sectionHeader,
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _nu++),
                        icon: const Icon(Icons.add_circle_rounded, size: 22),
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Sale Out
                _buildLabel('Sale Out'),
                TextFormField(
                  controller: _saleOutController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Nhập Sale Out',
                    suffixText: 'đ',
                  ),
                ),
                const SizedBox(height: 16),

                // Product list
                _buildLabel(AppStrings.danhSachSanPhamField),
                if (_products.isNotEmpty)
                  ..._products.asMap().entries.map((entry) {
                    final item = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.productName,
                                    style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w500)),
                                Text(
                                  'SL: ${item.quantity} × ${CurrencyFormatter.formatVND(item.unitPrice)}',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatVND(item.total),
                            style: AppTextStyles.bodyText.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => setState(() => _products.removeAt(entry.key)),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.errorLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.close_rounded,
                                  size: 16, color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                TextButton.icon(
                  onPressed: _addProduct,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Thêm sản phẩm'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                ),
                const SizedBox(height: 16),

                // Doanh thu
                _buildLabel(AppStrings.doanhThu, required: true),
                TextFormField(
                  controller: _revenueController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Nhập doanh thu',
                    suffixText: 'đ',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập doanh thu';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(AppStrings.huy),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitForm,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    color: AppColors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.save_rounded, size: 18),
                        label: const Text(AppStrings.luu),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(text, style: AppTextStyles.metricLabel),
          if (required)
            const Text(' *', style: TextStyle(color: AppColors.error, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _addProduct() {
    final productProvider = context.read<ProductProvider>();
    if (!productProvider.isLoading && productProvider.products.isEmpty) {
      productProvider.loadProducts();
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final qtyCtrl = TextEditingController(text: '1');
        final priceCtrl = TextEditingController();
        final searchCtrl = TextEditingController();
        String selectedGroup = 'Tất cả';
        Product? selectedProduct;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Consumer<ProductProvider>(
              builder: (context, provider, _) {
                final keyword = searchCtrl.text.trim().toLowerCase();
                final availableProducts = provider.products.where((product) {
                  final matchesGroup =
                      selectedGroup == 'Tất cả' || product.productGroup == selectedGroup;
                  final matchesSearch = keyword.isEmpty ||
                      product.name.toLowerCase().contains(keyword);
                  return matchesGroup && matchesSearch;
                }).toList()
                  ..sort((a, b) => a.name.compareTo(b.name));

                if (selectedProduct != null &&
                    !availableProducts.any((product) => product.id == selectedProduct!.id)) {
                  selectedProduct = null;
                  priceCtrl.clear();
                }

                return AlertDialog(
                  title: const Text('Thêm sản phẩm'),
                  content: SizedBox(
                    width: 520,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (provider.isLoading)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: LinearProgressIndicator(color: AppColors.primary),
                          ),
                        if (provider.error != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.errorLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              provider.error!,
                              style: AppTextStyles.caption.copyWith(color: AppColors.error),
                            ),
                          ),
                        TextField(
                          controller: searchCtrl,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Tìm sản phẩm',
                            prefixIcon: Icon(Icons.search_rounded, size: 20),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['Tất cả', 'DELI', 'DELIMIL', 'AUMIL', 'GOODLIFE', 'TP']
                                .map((group) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: Text(group),
                                        selected: selectedGroup == group,
                                        selectedColor: AppColors.primaryLight,
                                        onSelected: (_) {
                                          setDialogState(() {
                                            selectedGroup = group;
                                          });
                                        },
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 220),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: availableProducts.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text('Không có sản phẩm phù hợp'),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: availableProducts.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final product = availableProducts[index];
                                    final isSelected = selectedProduct?.id == product.id;
                                    return ListTile(
                                      dense: true,
                                      selected: isSelected,
                                      selectedTileColor: AppColors.primaryLight,
                                      title: Text(product.name),
                                      subtitle: Text(
                                        '${product.productGroup} • ${product.unit} • ${CurrencyFormatter.formatVND(product.priceWithVAT)}',
                                        style: AppTextStyles.caption,
                                      ),
                                      trailing: isSelected
                                          ? const Icon(Icons.check_circle_rounded,
                                              color: AppColors.primary, size: 20)
                                          : null,
                                      onTap: () {
                                        setDialogState(() {
                                          selectedProduct = product;
                                          priceCtrl.text = product.priceWithVAT.toStringAsFixed(0);
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Số lượng'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Đơn giá'),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(AppStrings.huy),
                    ),
                    ElevatedButton(
                      onPressed: selectedProduct == null
                          ? null
                          : () {
                              final quantity = int.tryParse(qtyCtrl.text) ?? 1;
                              final unitPrice =
                                  double.tryParse(priceCtrl.text) ?? selectedProduct!.priceWithVAT;
                              setState(() {
                                _products.add(SaleItem(
                                  productId: selectedProduct!.id,
                                  productName: selectedProduct!.name,
                                  quantity: quantity > 0 ? quantity : 1,
                                  unitPrice: unitPrice,
                                ));
                              });
                              Navigator.pop(ctx);
                            },
                      child: const Text('Thêm'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_revenueController.text.isEmpty || (double.tryParse(_revenueController.text) ?? 0) <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Doanh thu phải lớn hơn 0'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      setState(() => _isSubmitting = true);
      final user = context.read<AuthProvider>().currentUser;
      final report = SalesReport(
        id: _editingReport?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        date: _selectedDate,
        pgName: user?.fullName ?? '',
        nu: _nu,
        saleOut: double.tryParse(_saleOutController.text) ?? 0,
        products: _products,
        revenue: double.tryParse(_revenueController.text) ?? 0,
      );

      final bool success;
      if (_editingReport != null) {
        success = await context.read<SalesProvider>().updateReport(report);
      } else {
        success = await context.read<SalesProvider>().createReport(report);
      }
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingReport != null ? 'Cập nhật báo cáo thành công!' : 'Tạo phiếu báo cáo thành công!'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingReport != null ? 'Cập nhật thất bại. Vui lòng thử lại.' : 'Tạo phiếu thất bại. Vui lòng thử lại.'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
