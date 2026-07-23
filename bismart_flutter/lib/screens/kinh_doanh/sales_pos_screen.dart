import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/sales_provider.dart';
import '../../widgets/common/add_product_dialog.dart';
import 'create_order_screen.dart';

/// "Bán hàng" tab: a browsing surface only — the product catalog and recent
/// sales history. Order composition itself lives in its own dedicated
/// screen (CreateOrderScreen), reached via the floating "Tạo đơn hàng"
/// button, so building a cart doesn't compete for space with browsing here.
/// Máy in (printer) settings live under Cá nhân, not this tab.
///
/// Embedded directly as a tab inside Kinh doanh's TabBarView (no own
/// Scaffold/AppBar) — keeps search text alive across tab switches via
/// AutomaticKeepAliveClientMixin. Sales history is reached via the history
/// action button next to search rather than its own toggle/tab.
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

  Future<void> _openCreateOrder() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
    );
    // A new order may have been saved while this tab wasn't visible;
    // refresh the history list on return.
    if (mounted) context.read<SalesProvider>().loadReports();
  }

  void _showSalesHistory() {
    showDialog(
      context: context,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final isMobile = mq.size.width < 600;
        final dialogWidth = isMobile ? mq.size.width - 4 : 500.0;
        final dialogHeight = isMobile ? mq.size.height * 0.75 : 500.0;
        return AlertDialog(
          insetPadding: const EdgeInsets.all(2),
          contentPadding:
              EdgeInsets.fromLTRB(isMobile ? 4 : 16, 12, isMobile ? 4 : 16, 8),
          titlePadding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 24, 14, isMobile ? 16 : 24, 0),
          title: const Text('Lịch sử bán hàng'),
          content: SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: _SalesHistoryList(
              onRefresh: () => context.read<SalesProvider>().loadReports(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final productProvider = context.watch<ProductProvider>();
    final products = productProvider.filteredProducts;

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => productProvider.setSearch(v),
                decoration: AppDecorations.searchField(
                  'Tìm sản phẩm...',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_box_outlined, size: 20),
                        tooltip: 'Thêm sản phẩm',
                        onPressed: () => showAddProductDialog(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.history_rounded, size: 20),
                        tooltip: 'Lịch sử bán hàng',
                        onPressed: _showSalesHistory,
                      ),
                    ],
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
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 84),
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
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: SafeArea(
            top: false,
            child: Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(28),
              elevation: 2,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: _openCreateOrder,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Tạo đơn hàng',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SalesHistoryList extends StatelessWidget {
  final VoidCallback onRefresh;

  const _SalesHistoryList({required this.onRefresh});

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
