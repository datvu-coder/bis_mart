import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/product_provider.dart';
import '../../widgets/common/add_product_dialog.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, provider, _) {
        final products = provider.filteredProducts;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Danh sách sản phẩm'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${products.length} sản phẩm',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => showAddProductDialog(context),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add_rounded, color: AppColors.white),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  decoration: AppDecorations.searchField('Tìm sản phẩm...'),
                  onChanged: (v) => provider.setSearch(v),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: ['Tất cả', 'DELI', 'DELIMIL', 'AUMIL', 'GOODLIFE', 'TP']
                      .map((group) {
                    final selected = provider.selectedGroup == group;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(group),
                        selected: selected,
                        selectedColor: AppColors.primaryLight,
                        checkmarkColor: AppColors.primary,
                        onSelected: (_) => provider.setGroup(group),
                      ),
                    );
                  }).toList(),
                ),
              ),
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
