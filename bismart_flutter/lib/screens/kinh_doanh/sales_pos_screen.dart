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
import 'printer_settings_screen.dart';

/// "Bán hàng" tab: a browsing surface only — the product catalog and recent
/// sales history. Order composition itself lives in its own dedicated
/// screen (CreateOrderScreen), reached via the "Tạo đơn hàng" button, so
/// building a cart doesn't compete for space with browsing/lookup here.
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openCreateOrder,
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                  label: const Text('Tạo đơn hàng'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
                ),
                icon: const Icon(Icons.print_outlined),
                tooltip: 'Cài đặt máy in',
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: _SegmentButton(
                  label: 'Sản phẩm',
                  icon: Icons.inventory_2_outlined,
                  selected: !_showHistory,
                  onTap: () => setState(() => _showHistory = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SegmentButton(
                  label: 'Lịch sử bán hàng',
                  icon: Icons.history_rounded,
                  selected: _showHistory,
                  onTap: () => setState(() => _showHistory = true),
                ),
              ),
            ],
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
                                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
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
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: const Offset(0, 2))],
      ),
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
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(4)),
                child: Text(product.unit, style: AppTextStyles.caption.copyWith(fontSize: 10)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  product.productGroup,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ),
            ],
          ),
          Text(
            CurrencyFormatter.formatVND(product.priceWithVAT),
            style: AppTextStyles.bodyText.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
