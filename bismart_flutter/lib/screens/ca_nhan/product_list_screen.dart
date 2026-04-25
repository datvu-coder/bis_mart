import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/product_provider.dart';
import '../../models/product.dart';

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
            onPressed: () => _showAddProductDialog(),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add_rounded, color: AppColors.white),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Tìm sản phẩm...',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                  ),
                  onChanged: (v) => provider.setSearch(v),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
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
                    : ListView.builder(
                        itemCount: products.length,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(12),
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
                                        style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w500),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceVariant,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(product.unit,
                                                style: AppTextStyles.caption.copyWith(fontSize: 11)),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            ],
          ),
        );
      },
    );
  }

  void _showAddProductDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm sản phẩm'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên sản phẩm')),
            const SizedBox(height: 8),
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Mã sản phẩm')),
            const SizedBox(height: 8),
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(labelText: 'Giá'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isEmpty || codeCtrl.text.isEmpty) return;
              context.read<ProductProvider>().addProduct(Product(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameCtrl.text,
                unit: 'Lon',
                priceWithVAT: double.tryParse(priceCtrl.text) ?? 0,
                productGroup: 'DELI',
              ));
              Navigator.pop(ctx);
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }
}
