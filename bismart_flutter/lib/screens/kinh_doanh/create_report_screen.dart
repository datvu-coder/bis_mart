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
import '../../providers/store_provider.dart';

class CreateReportScreen extends StatefulWidget {
  const CreateReportScreen({super.key});

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
  int _nu = 0;
  final _revenueController = TextEditingController();
  final List<SaleItem> _products = [];
  bool _isSubmitting = false;
  SalesReport? _editingReport;

  double get _saleOut =>
      _products.fold<double>(0, (sum, p) => sum + p.total);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_editingReport == null) {
      final arg = ModalRoute.of(context)?.settings.arguments;
      if (arg is SalesReport) {
        _editingReport = arg;
        _selectedDate = arg.date;
        _nu = arg.nu;
        _revenueController.text = arg.revenue.toStringAsFixed(0);
        _products.addAll(arg.products);
      }
    }

    final productProvider = context.read<ProductProvider>();
    if (!productProvider.isLoading && productProvider.products.isEmpty) {
      productProvider.loadProducts();
    }

    final storeProvider = context.read<StoreProvider>();
    if (!storeProvider.isLoading && storeProvider.stores.isEmpty) {
      storeProvider.loadStores();
    }
  }

  @override
  void dispose() {
    _revenueController.dispose();
    super.dispose();
  }

  void _updateQty(int index, int delta) {
    final item = _products[index];
    final newQty = item.quantity + delta;
    if (newQty < 1) return;
    setState(() {
      _products[index] = SaleItem(
        productId: item.productId,
        productName: item.productName,
        quantity: newQty,
        unitPrice: item.unitPrice,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;
    final stores = context.watch<StoreProvider>().stores;
    final currentStore = (user?.storeCode != null && stores.isNotEmpty)
        ? stores.cast<dynamic>().firstWhere(
            (s) => s.storeCode.toString().toUpperCase() == user!.storeCode!.toUpperCase(),
            orElse: () => null,
          )
        : null;

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1100;
    final isTablet = width >= 700 && width < 1100;
    final outerPad = isDesktop ? 32.0 : (isTablet ? 24.0 : 12.0);
    final innerPad = isDesktop ? 28.0 : (isTablet ? 22.0 : 16.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_editingReport != null ? 'Chỉnh sửa báo cáo' : AppStrings.taoPhieuBaoCao),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(outerPad),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 1100 : 720),
            child: Form(
              key: _formKey,
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _buildInfoCard(user, currentStore, innerPad,
                              showRevenueAndActions: true),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 6,
                          child: _buildProductsCard(innerPad,
                              showBanner: true),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildInfoCard(user, currentStore, innerPad,
                            showRevenueAndActions: false),
                        const SizedBox(height: 16),
                        _buildProductsCard(innerPad, showBanner: true),
                        const SizedBox(height: 16),
                        _buildRevenueCard(innerPad),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      );

  Widget _buildInfoCard(dynamic user, dynamic currentStore, double pad,
      {bool showRevenueAndActions = true}) {
    return Container(
      padding: EdgeInsets.all(pad),
      decoration: _cardDecoration,
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
                Expanded(
                  child: Text(user?.fullName ?? 'N/A',
                      style: AppTextStyles.bodyText, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Store info (fixed by employee assignment)
          _buildLabel('Cửa hàng'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.store_rounded, size: 18, color: AppColors.textGrey),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    currentStore != null
                        ? '${currentStore.name} (${currentStore.storeCode})'
                        : ((user?.storeCode != null && user!.storeCode!.isNotEmpty)
                            ? 'Mã cửa hàng ${user.storeCode}'
                            : 'Chưa gán cửa hàng'),
                    style: AppTextStyles.bodyText,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // NU stepper
          _buildLabel(AppStrings.nu),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                  child: Text('$_nu', style: AppTextStyles.sectionHeader),
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

          if (showRevenueAndActions) ...[
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
            const SizedBox(height: 24),

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
        ],
      ),
    );
  }

  Widget _buildRevenueCard(double pad) {
    return Container(
      padding: EdgeInsets.all(pad),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 20),
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
    );
  }

  Widget _buildSaleOutBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.accent.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.point_of_sale_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sale Out', style: AppTextStyles.metricLabel),
                const SizedBox(height: 2),
                Text(
                  CurrencyFormatter.formatVND(_saleOut),
                  style: AppTextStyles.sectionHeader.copyWith(
                    color: AppColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            '${_products.length} SP',
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsCard(double pad, {bool showBanner = true}) {
    return Container(
      padding: EdgeInsets.all(pad),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBanner) ...[
            _buildSaleOutBanner(),
            const SizedBox(height: 16),
          ],
          _buildLabel(AppStrings.danhSachSanPhamField),
          if (_products.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.4),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 32, color: AppColors.textHint),
                  const SizedBox(height: 8),
                  Text('Chưa có sản phẩm',
                      style: AppTextStyles.caption),
                ],
              ),
            ),
          ..._products.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.productName,
                          style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _products.removeAt(i)),
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
                  const SizedBox(height: 6),
                  Text(
                    'Đơn giá: ${CurrencyFormatter.formatVND(item.unitPrice)}',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Quantity stepper
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: item.quantity > 1
                                  ? () => _updateQty(i, -1)
                                  : null,
                              borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(10)),
                              child: Container(
                                width: 36, height: 36,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.remove_rounded,
                                  size: 18,
                                  color: item.quantity > 1
                                      ? AppColors.primary
                                      : AppColors.textHint,
                                ),
                              ),
                            ),
                            Container(
                              width: 44, height: 36,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                border: Border.symmetric(
                                  vertical: BorderSide(color: AppColors.border),
                                ),
                              ),
                              child: Text(
                                '${item.quantity}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => _updateQty(i, 1),
                              borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(10)),
                              child: Container(
                                width: 36, height: 36,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.add_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        CurrencyFormatter.formatVND(item.total),
                        style: AppTextStyles.bodyText.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addProduct,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Thêm sản phẩm'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
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
      final stores = context.read<StoreProvider>().stores;
      final currentStore = (user?.storeCode != null && stores.isNotEmpty)
          ? stores.cast<dynamic>().firstWhere(
              (s) => s.storeCode.toString().toUpperCase() == user!.storeCode!.toUpperCase(),
              orElse: () => null,
            )
          : null;

      final report = SalesReport(
        id: _editingReport?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        date: _selectedDate,
        pgName: user?.fullName ?? '',
        nu: _nu,
        saleOut: _saleOut,
        products: _products,
        revenue: double.tryParse(_revenueController.text) ?? 0,
        storeCode: user?.storeCode,
        storeName: currentStore?.name ?? user?.workLocation,
        employeeCode: user?.employeeCode,
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
