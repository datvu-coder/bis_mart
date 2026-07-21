import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/product.dart';
import '../../models/sales_report.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/sales_provider.dart';
import '../../providers/store_provider.dart';
import '../../widgets/common/add_product_dialog.dart';
import '../../widgets/common/responsive_form.dart';
import 'barcode_scanner_screen.dart';

/// POS-style "Bán hàng" tab: tap products to build a cart, then check out.
/// Submits through the same sales-report API as the manual report form, so
/// it shows up identically in the report list/statistics — the difference
/// is purely the entry workflow (cart-first, like a cashier screen).
///
/// Embedded directly as a tab inside Kinh doanh's TabBarView (no own
/// Scaffold/AppBar) — keeps its cart alive across tab switches via
/// AutomaticKeepAliveClientMixin so browsing other tabs doesn't lose it.
class SalesPosScreen extends StatefulWidget {
  const SalesPosScreen({super.key});

  @override
  State<SalesPosScreen> createState() => _SalesPosScreenState();
}

class _SalesPosScreenState extends State<SalesPosScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const _groups = ['Tất cả', 'DELI', 'DELIMIL', 'AUMIL', 'GOODLIFE', 'TP'];

  final List<SaleItem> _cart = [];
  final _searchCtrl = TextEditingController();

  double get _subtotal => _cart.fold<double>(0, (sum, item) => sum + item.total);
  int get _cartCount => _cart.fold<int>(0, (sum, item) => sum + item.quantity);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productProvider = context.read<ProductProvider>();
      if (!productProvider.isLoading && productProvider.products.isEmpty) {
        productProvider.loadProducts();
      }
      final storeProvider = context.read<StoreProvider>();
      if (!storeProvider.isLoading && storeProvider.stores.isEmpty) {
        storeProvider.loadStores();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _addToCart(Product product) {
    setState(() {
      final index = _cart.indexWhere((item) => item.productId == product.id);
      if (index != -1) {
        final existing = _cart[index];
        _cart[index] = SaleItem(
          productId: existing.productId,
          productName: existing.productName,
          quantity: existing.quantity + 1,
          unitPrice: existing.unitPrice,
        );
      } else {
        _cart.add(SaleItem(
          productId: product.id,
          productName: product.name,
          quantity: 1,
          unitPrice: product.priceWithVAT,
        ));
      }
    });
  }

  void _updateCartQty(int index, int delta) {
    final item = _cart[index];
    final newQty = item.quantity + delta;
    setState(() {
      if (newQty < 1) {
        _cart.removeAt(index);
      } else {
        _cart[index] = SaleItem(
          productId: item.productId,
          productName: item.productName,
          quantity: newQty,
          unitPrice: item.unitPrice,
        );
      }
    });
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || !mounted) return;
    final products = context.read<ProductProvider>().products;
    Product? match;
    for (final p in products) {
      if (p.barcode != null && p.barcode!.trim() == code.trim()) {
        match = p;
        break;
      }
    }
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không tìm thấy sản phẩm với mã vạch "$code"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _addToCart(match);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm "${match.name}" vào giỏ hàng'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _confirmNewOrder() async {
    if (_cart.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tạo đơn hàng mới'),
        content: const Text('Giỏ hàng hiện tại sẽ bị xóa. Bạn có chắc chắn muốn bắt đầu đơn hàng mới?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đồng ý')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _cart.clear());
    }
  }

  void _showSalesHistory() {
    final salesProvider = context.read<SalesProvider>();
    if (salesProvider.reports.isEmpty && !salesProvider.isLoading) {
      salesProvider.loadReports();
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Consumer<SalesProvider>(
          builder: (ctx, provider, _) {
            final reports = provider.reports;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Text('Lịch sử bán hàng', style: AppTextStyles.sectionHeader),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                if (provider.isLoading && reports.isEmpty)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  )
                else if (reports.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text('Chưa có đơn bán hàng nào', style: AppTextStyles.caption),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: reports.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (context, i) {
                        final r = reports[i];
                        final itemCount = r.products.fold<int>(0, (s, it) => s + it.quantity);
                        return Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.storeName?.isNotEmpty == true ? r.storeName! : r.pgName,
                                    style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${DateFormatter.formatDateTime(r.date)} · $itemCount sản phẩm',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              CurrencyFormatter.formatVND(r.revenue),
                              style: AppTextStyles.bodyText
                                  .copyWith(fontWeight: FontWeight.w700, color: AppColors.primary),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final productProvider = context.watch<ProductProvider>();
    final products = productProvider.filteredProducts;
    final isWide = MediaQuery.of(context).size.width >= 900;

    final crossAxisCount = isWide ? 5 : (MediaQuery.of(context).size.width >= 420 ? 3 : 2);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 2),
          child: Row(
            children: [
              Text('${products.length} sản phẩm', style: AppTextStyles.caption),
              const Spacer(),
              IconButton(
                onPressed: _showSalesHistory,
                icon: const Icon(Icons.history_rounded),
                tooltip: 'Lịch sử bán hàng',
                color: AppColors.textSecondary,
              ),
              IconButton(
                onPressed: () => showAddProductDialog(context),
                icon: const Icon(Icons.add_box_outlined),
                tooltip: 'Thêm sản phẩm',
                color: AppColors.textSecondary,
              ),
              OutlinedButton.icon(
                onPressed: _cart.isEmpty ? null : _confirmNewOrder,
                icon: const Icon(Icons.receipt_long_rounded, size: 16),
                label: const Text('Đơn mới'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => productProvider.setSearch(v),
            decoration: InputDecoration(
              hintText: 'Tìm sản phẩm...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                tooltip: 'Quét mã vạch',
                onPressed: _scanBarcode,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ),
        SizedBox(
          height: 32,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: _groups.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final group = _groups[i];
              final isSelected = productProvider.selectedGroup == group;
              return ChoiceChip(
                label: Text(group),
                labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                selected: isSelected,
                selectedColor: AppColors.primaryLight,
                side: BorderSide(
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border,
                ),
                onSelected: (_) => productProvider.setGroup(group),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: productProvider.isLoading && products.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : products.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inventory_2_outlined,
                              size: 40, color: AppColors.textHint),
                          const SizedBox(height: 8),
                          Text('Không có sản phẩm phù hợp',
                              style: AppTextStyles.caption),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.05,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, i) {
                        final product = products[i];
                        final qtyInCart = _cart
                            .where((item) => item.productId == product.id)
                            .fold<int>(0, (s, it) => s + it.quantity);
                        return _ProductTile(
                          product: product,
                          quantityInCart: qtyInCart,
                          onTap: () => _addToCart(product),
                        );
                      },
                    ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$_cartCount sản phẩm', style: AppTextStyles.caption),
                      Text(
                        CurrencyFormatter.formatVND(_subtotal),
                        style: AppTextStyles.sectionHeader
                            .copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _cart.isEmpty ? null : _openCheckout,
                  icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 18),
                  label: const Text('Thanh toán'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openCheckout() {
    final user = context.read<AuthProvider>().currentUser;
    final revenueCtrl = TextEditingController(text: _subtotal.toStringAsFixed(0));
    final cashReceivedCtrl = TextEditingController();
    int nu = 0;
    String paymentMethod = 'cash';
    bool isSubmitting = false;

    showResponsiveForm<void>(
      context: context,
      title: 'Thanh toán',
      contentBuilder: (ctx, setDialogState) {
        final revenue = double.tryParse(revenueCtrl.text) ?? _subtotal;
        final cashReceived = double.tryParse(cashReceivedCtrl.text) ?? 0;
        final change = cashReceived - revenue;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._cart.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(item.productName,
                          style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      onPressed: () {
                        _updateCartQty(i, -1);
                        setDialogState(() {});
                      },
                      icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                      color: AppColors.primary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    ),
                    SizedBox(
                      width: 22,
                      child: Text('${item.quantity}',
                          textAlign: TextAlign.center, style: AppTextStyles.bodyText),
                    ),
                    IconButton(
                      onPressed: () {
                        _updateCartQty(i, 1);
                        setDialogState(() {});
                      },
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                      color: AppColors.primary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 84,
                      child: Text(
                        CurrencyFormatter.formatVND(item.total),
                        textAlign: TextAlign.end,
                        style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (_cart.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('Giỏ hàng trống', style: AppTextStyles.caption),
              ),
            const Divider(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text('Tạm tính',
                      style: AppTextStyles.bodyText
                          .copyWith(fontWeight: FontWeight.w700)),
                ),
                Text(
                  CurrencyFormatter.formatVND(_subtotal),
                  style: AppTextStyles.sectionHeader
                      .copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: revenueCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Doanh thu', suffixText: 'đ', isDense: true),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Text('NU', style: AppTextStyles.metricLabel),
                IconButton(
                  onPressed:
                      nu > 0 ? () => setDialogState(() => nu--) : null,
                  icon: const Icon(Icons.remove_circle_rounded),
                  color: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                Text('$nu', style: AppTextStyles.sectionHeader),
                IconButton(
                  onPressed: () => setDialogState(() => nu++),
                  icon: const Icon(Icons.add_circle_rounded),
                  color: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Phương thức thanh toán', style: AppTextStyles.metricLabel),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Tiền mặt'),
                    labelStyle: TextStyle(
                      color: paymentMethod == 'cash' ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    selected: paymentMethod == 'cash',
                    selectedColor: AppColors.primaryLight,
                    side: BorderSide(
                      color: paymentMethod == 'cash'
                          ? AppColors.primary.withValues(alpha: 0.4)
                          : AppColors.border,
                    ),
                    onSelected: (_) => setDialogState(() => paymentMethod = 'cash'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Chuyển khoản'),
                    labelStyle: TextStyle(
                      color: paymentMethod == 'transfer' ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    selected: paymentMethod == 'transfer',
                    selectedColor: AppColors.primaryLight,
                    side: BorderSide(
                      color: paymentMethod == 'transfer'
                          ? AppColors.primary.withValues(alpha: 0.4)
                          : AppColors.border,
                    ),
                    onSelected: (_) => setDialogState(() => paymentMethod = 'transfer'),
                  ),
                ),
              ],
            ),
            if (paymentMethod == 'cash') ...[
              const SizedBox(height: 10),
              TextField(
                controller: cashReceivedCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Tiền khách đưa', suffixText: 'đ', isDense: true),
                onChanged: (_) => setDialogState(() {}),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('Tiền thừa: ', style: AppTextStyles.bodyText),
                  Text(
                    CurrencyFormatter.formatVND(change > 0 ? change : 0),
                    style: AppTextStyles.bodyText.copyWith(
                        fontWeight: FontWeight.w700, color: AppColors.success),
                  ),
                ],
              ),
            ],
          ],
        );
      },
      actionsBuilder: (ctx, setDialogState) => [
        TextButton(
          onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: (isSubmitting || _cart.isEmpty)
              ? null
              : () async {
                  final revenue = double.tryParse(revenueCtrl.text) ?? _subtotal;
                  if (revenue <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Doanh thu phải lớn hơn 0'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  setDialogState(() => isSubmitting = true);

                  final stores = context.read<StoreProvider>().stores;
                  final currentStore = (user?.storeCode != null && stores.isNotEmpty)
                      ? stores.cast<dynamic>().firstWhere(
                          (s) => s.storeCode.toString().toUpperCase() ==
                              user!.storeCode!.toUpperCase(),
                          orElse: () => null,
                        )
                      : null;

                  final report = SalesReport(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    date: DateTime.now(),
                    pgName: user?.fullName ?? '',
                    nu: nu,
                    saleOut: _subtotal,
                    products: List<SaleItem>.from(_cart),
                    revenue: revenue,
                    storeCode: user?.storeCode,
                    storeName: currentStore?.name ?? user?.workLocation,
                    employeeCode: user?.employeeCode,
                    paymentMethod: paymentMethod,
                  );

                  final salesProvider = context.read<SalesProvider>();
                  final success = await salesProvider.createReport(report);
                  if (!ctx.mounted) return;
                  if (success) {
                    Navigator.pop(ctx);
                    setState(() => _cart.clear());
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Bán hàng thành công!'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.success,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  } else {
                    setDialogState(() => isSubmitting = false);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(salesProvider.error ??
                            'Bán hàng thất bại. Vui lòng thử lại.'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.error,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                },
          child: isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2),
                )
              : const Text('Hoàn tất'),
        ),
      ],
    ).then((_) {
      // Quantity edits made inside the checkout sheet mutate `_cart` directly;
      // refresh the grid's badges/cart bar once the sheet closes either way.
      if (mounted) setState(() {});
    });
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final int quantityInCart;
  final VoidCallback onTap;

  const _ProductTile({
    required this.product,
    required this.quantityInCart,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = quantityInCart > 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? null
              : [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyText
                      .copyWith(fontWeight: FontWeight.w600, fontSize: 12.5, height: 1.2),
                ),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(product.unit,
                          style: AppTextStyles.caption.copyWith(fontSize: 10)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product.productGroup,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  CurrencyFormatter.formatVND(product.priceWithVAT),
                  style: AppTextStyles.bodyText.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ],
            ),
            if (selected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$quantityInCart',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
