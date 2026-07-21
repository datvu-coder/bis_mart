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
/// Scaffold/AppBar) — keeps search text and the Sản phẩm/Lịch sử toggle
/// alive across tab switches via AutomaticKeepAliveClientMixin.
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

  bool _showHistory = false;
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

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final productProvider = context.watch<ProductProvider>();
    final products = productProvider.filteredProducts;
    final isWide = MediaQuery.of(context).size.width >= 900;
    final crossAxisCount = isWide ? 5 : (MediaQuery.of(context).size.width >= 420 ? 3 : 2);

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: _HistoryToggle(
                showHistory: _showHistory,
                onChanged: (v) => setState(() => _showHistory = v),
              ),
            ),
            Expanded(
              child: _showHistory
                  ? _SalesHistoryList(
                      onRefresh: () => context.read<SalesProvider>().loadReports(),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (v) => productProvider.setSearch(v),
                            decoration: InputDecoration(
                              hintText: 'Tìm sản phẩm...',
                              prefixIcon: const Icon(Icons.search_rounded, size: 20),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.add_box_outlined, size: 20),
                                tooltip: 'Thêm sản phẩm',
                                onPressed: () => showAddProductDialog(context),
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
                                  : GridView.builder(
                                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 84),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        mainAxisSpacing: 8,
                                        crossAxisSpacing: 8,
                                        childAspectRatio: 1.05,
                                      ),
                                      itemCount: products.length,
                                      itemBuilder: (context, i) => _ProductDisplayTile(product: products[i]),
                                    ),
                        ),
                      ],
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
              elevation: 3,
              shadowColor: AppColors.primary.withValues(alpha: 0.4),
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

/// Compact sliding segmented control, matching the pill style used for the
/// tab selector elsewhere in the app (see WeightedTabSelector) so this
/// secondary toggle still reads as "the same app".
class _HistoryToggle extends StatelessWidget {
  final bool showHistory;
  final ValueChanged<bool> onChanged;

  const _HistoryToggle({required this.showHistory, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: showHistory ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: const Offset(0, 1))],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _segment('Sản phẩm', Icons.inventory_2_outlined, !showHistory, () => onChanged(false)),
              ),
              Expanded(
                child: _segment('Lịch sử', Icons.history_rounded, showHistory, () => onChanged(true)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segment(String label, IconData icon, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: selected ? AppColors.primary : AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
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
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 84),
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
                    style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _ProductDisplayTile extends StatelessWidget {
  final Product product;

  const _ProductDisplayTile({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: AppColors.primary.withValues(alpha: 0.65)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w600, fontSize: 12.5, height: 1.2),
                  ),
                  Text(
                    '${product.unit} · ${product.productGroup}',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                  Text(
                    CurrencyFormatter.formatVND(product.priceWithVAT),
                    style: AppTextStyles.bodyText.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
