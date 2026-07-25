import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/product.dart';
import '../../models/sales_report.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/sales_provider.dart';
import '../../providers/store_provider.dart';
import '../../widgets/common/add_product_dialog.dart';
import '../../widgets/common/responsive_form.dart';
import 'barcode_scanner_screen.dart';
import 'receipt_preview_screen.dart';

String _trimStock(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Dedicated "Tạo đơn hàng" screen: pick products into a cart, then check
/// out. Pushed as its own full-screen route from the Bán hàng tab (which
/// itself only *displays* the product catalog and sales history) so order
/// composition has its own focused workspace, separate from browsing.
class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
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
      // Start with an unfiltered catalog even if the Bán hàng tab left a
      // search/group filter active.
      productProvider.setSearch('');
      productProvider.setGroup('Tất cả');
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Adds one unit of [product] to the cart. If the product has "Quy đổi"
  /// conversion units defined, prompts the user to pick which unit (base or
  /// a conversion level) is being sold before adding — each unit carries its
  /// own price and is tracked as a distinct cart line. Returns false if the
  /// picker was dismissed without a choice.
  Future<bool> _addToCart(Product product) async {
    String unit = product.unit;
    double price = product.priceWithVAT;
    if (product.conversions.isNotEmpty) {
      final choice = await showModalBottomSheet<_UnitChoice>(
        context: context,
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (sheetCtx) => _UnitPickerSheet(product: product),
      );
      if (choice == null || !mounted) return false;
      unit = choice.unit;
      price = choice.price;
    }
    setState(() {
      final index = _cart.indexWhere((item) => item.productId == product.id && item.unit == unit);
      if (index != -1) {
        final existing = _cart[index];
        _cart[index] = SaleItem(
          productId: existing.productId,
          productName: existing.productName,
          quantity: existing.quantity + 1,
          unitPrice: existing.unitPrice,
          unit: existing.unit,
          productGroup: existing.productGroup,
        );
      } else {
        _cart.add(SaleItem(
          productId: product.id,
          productName: product.name,
          quantity: 1,
          unitPrice: price,
          unit: unit,
          productGroup: product.productGroup,
        ));
      }
    });
    return true;
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
          unit: item.unit,
          productGroup: item.productGroup,
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
    final added = await _addToCart(match);
    if (!mounted || !added) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm "${match.name}" vào giỏ hàng'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final products = productProvider.filteredProducts;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tạo đơn hàng'),
        actions: [
          IconButton(
            onPressed: () => showAddProductDialog(context),
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Thêm sản phẩm',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => productProvider.setSearch(v),
              decoration: AppDecorations.searchField(
                'Tìm sản phẩm...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                  tooltip: 'Quét mã vạch',
                  onPressed: _scanBarcode,
                ),
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
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.textHint),
                            const SizedBox(height: 8),
                            Text('Không có sản phẩm phù hợp', style: AppTextStyles.caption),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Container(
                          decoration: AppDecorations.card,
                          clipBehavior: Clip.antiAlias,
                          child: ListView.separated(
                            itemCount: products.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              indent: 14,
                              endIndent: 14,
                              color: AppColors.divider,
                            ),
                            itemBuilder: (context, i) {
                              final product = products[i];
                              final qtyInCart = _cart
                                  .where((item) => item.productId == product.id)
                                  .fold<int>(0, (s, it) => s + it.quantity);
                              return _OrderProductRow(
                                product: product,
                                quantityInCart: qtyInCart,
                                onTap: () => _addToCart(product),
                              );
                            },
                          ),
                        ),
                      ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -2)),
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
                          style: AppTextStyles.sectionHeader.copyWith(color: AppColors.primary),
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
      ),
    );
  }

  void _openCheckout() {
    final user = context.read<AuthProvider>().currentUser;
    final revenueCtrl = TextEditingController(text: _subtotal.toStringAsFixed(0));
    final cashReceivedCtrl = TextEditingController();
    final discountCtrl = TextEditingController(text: '0');
    final customerNameCtrl = TextEditingController();
    final customerPhoneCtrl = TextEditingController();
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
                      child: Text(
                        (item.unit ?? '').isEmpty ? item.productName : '${item.productName} (${item.unit})',
                        style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w600),
                      ),
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
                      style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w700)),
                ),
                Text(
                  CurrencyFormatter.formatVND(_subtotal),
                  style: AppTextStyles.sectionHeader.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: discountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Giảm giá', suffixText: 'đ', isDense: true),
              onChanged: (_) => setDialogState(() {}),
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
                  onPressed: nu > 0 ? () => setDialogState(() => nu--) : null,
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
                decoration:
                    const InputDecoration(labelText: 'Tiền khách đưa', suffixText: 'đ', isDense: true),
                onChanged: (_) => setDialogState(() {}),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('Tiền thừa: ', style: AppTextStyles.bodyText),
                  Text(
                    CurrencyFormatter.formatVND(change > 0 ? change : 0),
                    style: AppTextStyles.bodyText
                        .copyWith(fontWeight: FontWeight.w700, color: AppColors.success),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Text('Thông tin khách hàng (tùy chọn)', style: AppTextStyles.metricLabel),
            const SizedBox(height: 6),
            TextField(
              controller: customerNameCtrl,
              decoration: const InputDecoration(labelText: 'Tên khách hàng', isDense: true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: customerPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'SĐT khách hàng', isDense: true),
            ),
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
                  final storeNameForReceipt = currentStore?.name ?? user?.workLocation ?? "Bi'S MART";
                  final orderDate = DateTime.now();
                  final itemsForReceipt = List<SaleItem>.from(_cart);

                  final report = SalesReport(
                    id: orderDate.millisecondsSinceEpoch.toString(),
                    date: orderDate,
                    pgName: user?.fullName ?? '',
                    nu: nu,
                    saleOut: _subtotal,
                    products: itemsForReceipt,
                    revenue: revenue,
                    storeCode: user?.storeCode,
                    storeName: storeNameForReceipt,
                    employeeCode: user?.employeeCode,
                    paymentMethod: paymentMethod,
                    discountAmount: double.tryParse(discountCtrl.text) ?? 0,
                    customerName: customerNameCtrl.text.trim().isEmpty ? null : customerNameCtrl.text.trim(),
                    customerPhone: customerPhoneCtrl.text.trim().isEmpty ? null : customerPhoneCtrl.text.trim(),
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
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReceiptPreviewScreen(
                          storeName: storeNameForReceipt,
                          date: orderDate,
                          pgName: user?.fullName ?? '',
                          items: itemsForReceipt,
                          subtotal: revenue,
                          paymentMethod: paymentMethod,
                          discountAmount: report.discountAmount,
                          customerName: report.customerName,
                          customerPhone: report.customerPhone,
                        ),
                      ),
                    );
                    if (mounted) Navigator.of(context).pop();
                  } else {
                    setDialogState(() => isSubmitting = false);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(salesProvider.error ?? 'Bán hàng thất bại. Vui lòng thử lại.'),
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
    );
  }

}

/// Same list-row layout as Bán hàng/Danh sách sản phẩm (icon, name,
/// unit/nhóm badges, trailing price) — tapping a row adds one unit to the
/// cart. A small quantity badge overlays the icon once a product has been
/// added, and a "+" cue next to the price makes the tap-to-add behavior
/// discoverable (the previous grid tiles relied on the badge alone).
class _OrderProductRow extends StatelessWidget {
  final Product product;
  final int quantityInCart;
  final VoidCallback onTap;

  const _OrderProductRow({
    required this.product,
    required this.quantityInCart,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = quantityInCart > 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primaryLight : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.row - 2),
                  ),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    size: 20,
                    color: selected ? AppColors.primary : AppColors.textGrey,
                  ),
                ),
                if (selected)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.cardBg, width: 1.5),
                      ),
                      child: Text(
                        '$quantityInCart',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(product.unit, style: AppTextStyles.caption.copyWith(fontSize: 11)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          product.productGroup,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                      ),
                      if (product.isLowStock) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            'Tồn: ${_trimStock(product.stockQuantity)}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.error),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.formatVND(product.priceWithVAT),
                  style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.add_circle_rounded, size: 22, color: AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The unit + price a staff member picked for a product with "Quy đổi"
/// conversion levels defined.
class _UnitChoice {
  final String unit;
  final double price;

  const _UnitChoice({required this.unit, required this.price});
}

/// Bottom sheet listing a product's base unit plus every "Quy đổi"
/// conversion level, each with its own price — shown before adding a
/// product with conversions to the cart so staff pick which unit is
/// actually being sold (e.g. "Thùng" vs "Lốc" vs "Hộp").
class _UnitPickerSheet extends StatelessWidget {
  final Product product;

  const _UnitPickerSheet({required this.product});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
            Text('Chọn đơn vị bán', style: AppTextStyles.sectionHeader),
            const SizedBox(height: 2),
            Text(product.name, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.inventory_2_rounded, color: AppColors.primary),
              title: Text(product.unit, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Đơn vị chuẩn'),
              trailing: Text(
                CurrencyFormatter.formatVND(product.priceWithVAT),
                style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
              onTap: () => Navigator.pop(
                context,
                _UnitChoice(unit: product.unit, price: product.priceWithVAT),
              ),
            ),
            for (final c in product.conversions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.swap_horiz_rounded, color: AppColors.textGrey),
                title: Text(c.unit, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Quy đổi'),
                trailing: Text(
                  CurrencyFormatter.formatVND(c.price),
                  style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
                onTap: () => Navigator.pop(context, _UnitChoice(unit: c.unit, price: c.price)),
              ),
          ],
        ),
      ),
    );
  }
}
