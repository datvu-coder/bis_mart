import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import 'responsive_form.dart';

const _kProductUnits = ['Lon', 'Hộp', 'Gói'];
const _kProductGroups = ['DELI', 'DELIMIL', 'AUMIL', 'GOODLIFE', 'TP'];

/// Shared "Thêm sản phẩm" form, usable from both Danh sách sản phẩm and the
/// Bán hàng (POS) tab so staff can add a missing product without leaving
/// the screen they're working in.
void showAddProductDialog(BuildContext context) {
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final barcodeCtrl = TextEditingController();
  String unit = _kProductUnits.first;
  String group = _kProductGroups.first;
  bool saving = false;

  showResponsiveForm(
    context: context,
    title: 'Thêm sản phẩm',
    contentBuilder: (ctx, setDialogState) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên sản phẩm')),
        const SizedBox(height: 8),
        TextField(
          controller: priceCtrl,
          decoration: const InputDecoration(labelText: 'Giá'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: barcodeCtrl,
          decoration: const InputDecoration(labelText: 'Mã vạch (tùy chọn)'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: unit,
          decoration: const InputDecoration(labelText: 'Đơn vị'),
          items: _kProductUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
          onChanged: (v) => setDialogState(() => unit = v ?? unit),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: group,
          decoration: const InputDecoration(labelText: 'Nhóm sản phẩm'),
          items: _kProductGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          onChanged: (v) => setDialogState(() => group = v ?? group),
        ),
      ],
    ),
    actionsBuilder: (ctx, setDialogState) => [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(ctx),
        child: const Text('Hủy'),
      ),
      ElevatedButton(
        onPressed: saving
            ? null
            : () async {
                if (nameCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng nhập tên sản phẩm'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                setDialogState(() => saving = true);
                final productProvider = context.read<ProductProvider>();
                final ok = await productProvider.addProduct(Product(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameCtrl.text,
                      unit: unit,
                      priceWithVAT: double.tryParse(priceCtrl.text) ?? 0,
                      productGroup: group,
                      barcode: barcodeCtrl.text.trim().isEmpty ? null : barcodeCtrl.text.trim(),
                    ));
                if (!ctx.mounted) return;
                if (ok) {
                  Navigator.pop(ctx);
                } else {
                  setDialogState(() => saving = false);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(productProvider.error ??
                          'Không thể thêm sản phẩm. Vui lòng thử lại.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
        child: Text(saving ? 'Đang lưu...' : 'Thêm'),
      ),
    ],
  );
}
