import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/product_provider.dart';
import '../../widgets/common/add_product_dialog.dart';
import '../../widgets/common/gradient_fab.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  static const _groups = ['Tất cả', 'DELI', 'DELIMIL', 'AUMIL', 'GOODLIFE', 'TP'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
    });
  }

  /// Small pill badge showing the item count, placed in the AppBar's
  /// actions — same spot phan_quyen_screen.dart uses for its counts.
  Widget _buildCountBadge(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// Group filter as a dropdown menu anchored to the search field's own
  /// icon instead of a full-width chip row — same "tune" pattern as Kinh
  /// doanh's Bán hàng, so the list itself gets the vertical space back.
  Widget _buildGroupFilterButton(ProductProvider provider) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.tune_rounded, size: 20),
      tooltip: 'Lọc theo nhóm',
      color: AppColors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      onSelected: provider.setGroup,
      itemBuilder: (context) => [
        for (final group in _groups)
          PopupMenuItem<String>(
            value: group,
            child: Builder(builder: (context) {
              final isSelected = provider.selectedGroup == group;
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
    return Consumer<ProductProvider>(
      builder: (context, provider, _) {
        final products = provider.filteredProducts;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            titleSpacing: 4,
            title: const Text('Danh sách sản phẩm'),
            actions: [_buildCountBadge('${products.length} sản phẩm')],
          ),
          floatingActionButton: GradientFab(
            icon: Icons.add_rounded,
            tooltip: 'Thêm sản phẩm',
            onPressed: () => showAddProductDialog(context),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  decoration: AppDecorations.searchField(
                    'Tìm sản phẩm...',
                    suffixIcon: _buildGroupFilterButton(provider),
                  ),
                  onChanged: (v) => provider.setSearch(v),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : products.isEmpty
                        ? Center(
                            child: Text('Không có sản phẩm phù hợp', style: AppTextStyles.caption),
                          )
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                                itemBuilder: (context, index) {
                                  final product = products[index];
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
                                          child: const Icon(Icons.inventory_2_rounded,
                                              size: 20, color: AppColors.textGrey),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product.name,
                                                style: AppTextStyles.bodyText
                                                    .copyWith(fontWeight: FontWeight.w500),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.surfaceVariant,
                                                      borderRadius: BorderRadius.circular(AppRadius.pill),
                                                    ),
                                                    child: Text(product.unit,
                                                        style: AppTextStyles.caption.copyWith(fontSize: 11)),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primaryLight,
                                                      borderRadius: BorderRadius.circular(AppRadius.pill),
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
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          CurrencyFormatter.formatVND(product.priceWithVAT),
                                          style: AppTextStyles.bodyText.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

}
