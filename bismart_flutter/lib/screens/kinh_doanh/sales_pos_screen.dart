import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/sales_provider.dart';

/// "Bán hàng" tab: a browsing surface only — the product catalog and recent
/// sales history. Order composition itself lives in its own dedicated
/// screen (CreateOrderScreen), reached via the "Tạo đơn hàng" button in
/// Kinh doanh's screen header (top-right), so building a cart doesn't
/// compete for space with browsing here. Máy in (printer) settings live
/// under Cá nhân, not this tab.
///
/// Embedded directly as a tab inside Kinh doanh's TabBarView (no own
/// Scaffold/AppBar) — keeps search text alive across tab switches via
/// AutomaticKeepAliveClientMixin. "Thêm sản phẩm" and "Lịch sử bán hàng"
/// live in Kinh doanh's screen header instead of this search bar, so the
/// search field's own suffix icon is just the product group filter.
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

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productProvider = context.read<ProductProvider>();
      if (!productProvider.isLoading && productProvider.products.isEmpty) {
        productProvider.loadProducts();
      }
      final salesProvider = context.read<SalesProvider>();
      if (!salesProvider.isLoading && salesProvider.reports.isEmpty) {
        salesProvider.loadReports();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Group filter as a dropdown menu anchored to its own icon (drops down
  /// right below the search field, like the header's "..." menu) instead
  /// of a bottom sheet — one consistent popup style across the tab.
  Widget _buildGroupFilterButton(ProductProvider productProvider) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.tune_rounded, size: 20),
      tooltip: 'Lọc theo nhóm',
      color: AppColors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      onSelected: productProvider.setGroup,
      itemBuilder: (context) => [
        for (final group in _groups)
          PopupMenuItem<String>(
            value: group,
            child: Builder(builder: (context) {
              final isSelected = productProvider.selectedGroup == group;
              return Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: isSelected ? AppColors.primary : AppColors.textHint,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    group,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              );
            }),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final productProvider = context.watch<ProductProvider>();
    final products = productProvider.filteredProducts;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => productProvider.setSearch(v),
            decoration: AppDecorations.searchField(
              'Tìm sản phẩm...',
              suffixIcon: _buildGroupFilterButton(productProvider),
            ),
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
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
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
                          itemBuilder: (context, i) => _ProductDisplayTile(product: products[i]),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

/// Public so Kinh doanh's screen header (which now owns the "Lịch sử bán
/// hàng" action) can show this list inside its own dialog.
class SalesHistoryList extends StatelessWidget {
  final VoidCallback onRefresh;

  const SalesHistoryList({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Consumer<SalesProvider>(
      builder: (context, provider, _) {
        final reports = provider.reports;
        if (provider.isLoading && reports.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textHint),
                const SizedBox(height: 8),
                Text('Chưa có đơn bán hàng nào', style: AppTextStyles.caption),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 84),
            children: [
              Container(
                decoration: AppDecorations.card,
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reports.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                    color: AppColors.divider,
                  ),
                  itemBuilder: (context, i) {
                    final r = reports[i];
                    final itemCount = r.products.fold<int>(0, (s, it) => s + it.quantity);
                    return Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
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
                            style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Same list-row layout as Danh sách sản phẩm (product_list_screen.dart) —
/// icon, name, unit/nhóm badges, trailing price — so the two screens that
/// show the same product catalog actually look like the same catalog.
class _ProductDisplayTile extends StatelessWidget {
  final Product product;

  const _ProductDisplayTile({required this.product});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.row - 2),
            ),
            child: const Icon(Icons.inventory_2_rounded, size: 20, color: AppColors.textGrey),
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
                          'Tồn: ${product.stockQuantity == product.stockQuantity.roundToDouble() ? product.stockQuantity.toInt() : product.stockQuantity}',
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
          Text(
            CurrencyFormatter.formatVND(product.priceWithVAT),
            style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w600, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
