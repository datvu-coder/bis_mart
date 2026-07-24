import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../screens/kinh_doanh/barcode_scanner_screen.dart';
import 'responsive_form.dart';

const _kProductUnits = ['Lon', 'Hộp', 'Gói'];
const _kProductGroups = ['DELI', 'DELIMIL', 'AUMIL', 'GOODLIFE', 'TP'];

String _imageMimeType(String? ext) {
  switch ((ext ?? '').toLowerCase()) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'heic':
      return 'image/heic';
    default:
      return 'image/jpeg';
  }
}

Uint8List _decodeDataUrl(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  return base64Decode(comma == -1 ? dataUrl : dataUrl.substring(comma + 1));
}

String _trimNumber(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// One editable "Quy đổi" row: how many of the previous level (the base
/// unit for the first row) make up one of `unitCtrl`, plus its own custom
/// price — not derived from the base price.
class _ConversionRow {
  final unitCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final priceCtrl = TextEditingController();

  _ConversionRow({String unit = '', String qty = '', String price = ''}) {
    unitCtrl.text = unit;
    qtyCtrl.text = qty;
    priceCtrl.text = price;
  }

  void dispose() {
    unitCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

/// Shared "Thêm sản phẩm" form, usable from both Danh sách sản phẩm and the
/// Bán hàng (POS) tab so staff can add a missing product without leaving
/// the screen they're working in. Scanning a barcode or searching can also
/// pull in an existing catalog product (from Danh sách sản phẩm) so its
/// photo/quy đổi info can be filled in without recreating it — in that
/// case the form submits as an update instead of a new product.
void showAddProductDialog(BuildContext context) {
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final barcodeCtrl = TextEditingController();
  String unit = _kProductUnits.first;
  String group = _kProductGroups.first;
  bool saving = false;
  String? imageDataUrl;
  Product? loadedProduct;
  final conversions = <_ConversionRow>[];

  void applyProduct(StateSetter setDialogState, Product p) {
    setDialogState(() {
      loadedProduct = p;
      nameCtrl.text = p.name;
      priceCtrl.text = _trimNumber(p.priceWithVAT);
      barcodeCtrl.text = p.barcode ?? '';
      unit = _kProductUnits.contains(p.unit) ? p.unit : _kProductUnits.first;
      group = _kProductGroups.contains(p.productGroup) ? p.productGroup : _kProductGroups.first;
      imageDataUrl = p.imageUrl;
      for (final c in conversions) {
        c.dispose();
      }
      conversions
        ..clear()
        ..addAll(p.conversions.map((c) => _ConversionRow(
              unit: c.unit,
              qty: _trimNumber(c.quantity),
              price: _trimNumber(c.price),
            )));
    });
  }

  Future<void> scanExisting(BuildContext ctx, StateSetter setDialogState) async {
    final code = await Navigator.of(ctx).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || !ctx.mounted) return;
    final products = ctx.read<ProductProvider>().products;
    Product? match;
    for (final p in products) {
      if (p.barcode != null && p.barcode!.trim() == code.trim()) {
        match = p;
        break;
      }
    }
    if (match != null) {
      applyProduct(setDialogState, match);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Đã tải sản phẩm "${match.name}" để chỉnh sửa.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      setDialogState(() => barcodeCtrl.text = code);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy sản phẩm với mã vạch này. Đã điền mã vạch cho sản phẩm mới.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> searchExisting(BuildContext ctx, StateSetter setDialogState) async {
    final products = ctx.read<ProductProvider>().products;
    final selected = await showModalBottomSheet<Product>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => _ExistingProductPicker(products: products),
    );
    if (selected != null) {
      applyProduct(setDialogState, selected);
    }
  }

  Future<void> pickImage(BuildContext ctx, StateSetter setDialogState, ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, imageQuality: 80);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
      final dataUrl = 'data:${_imageMimeType(ext)};base64,${base64Encode(bytes)}';
      setDialogState(() => imageDataUrl = dataUrl);
    } catch (_) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Không thể lấy ảnh.'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void showImageSourceSheet(BuildContext ctx, StateSetter setDialogState) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: AppColors.primary),
              title: const Text('Chụp ảnh'),
              onTap: () {
                Navigator.pop(sheetCtx);
                pickImage(ctx, setDialogState, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Chọn từ thư viện'),
              onTap: () {
                Navigator.pop(sheetCtx);
                pickImage(ctx, setDialogState, ImageSource.gallery);
              },
            ),
            if (imageDataUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: const Text('Xóa ảnh', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  setDialogState(() => imageDataUrl = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  showResponsiveForm(
    context: context,
    title: 'Thêm sản phẩm',
    contentBuilder: (ctx, setDialogState) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (loadedProduct != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đang chỉnh sửa sản phẩm có sẵn: ${loadedProduct!.name}',
                    style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.primary),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Tạo sản phẩm mới thay vì chỉnh sửa',
                  onPressed: () => setDialogState(() => loadedProduct = null),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => scanExisting(ctx, setDialogState),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('Quét mã vạch'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => searchExisting(ctx, setDialogState),
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Tìm sản phẩm'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Quét mã vạch hoặc tìm kiếm để lấy sản phẩm có sẵn từ Danh sách sản phẩm.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 14),
        Center(
          child: GestureDetector(
            onTap: () => showImageSourceSheet(ctx, setDialogState),
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
                image: imageDataUrl != null
                    ? DecorationImage(image: MemoryImage(_decodeDataUrl(imageDataUrl!)), fit: BoxFit.cover)
                    : null,
              ),
              child: imageDataUrl == null
                  ? const Icon(Icons.add_a_photo_rounded, color: AppColors.textHint, size: 28)
                  : Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.edit_rounded, color: AppColors.white, size: 14),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 14),
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
          decoration: const InputDecoration(labelText: 'Đơn vị (đơn vị chuẩn)'),
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
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: Text('Quy đổi đơn vị', style: AppTextStyles.sectionHeader)),
            TextButton.icon(
              onPressed: () => setDialogState(() => conversions.add(_ConversionRow())),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Thêm'),
            ),
          ],
        ),
        Text(
          'Ví dụ: đơn vị chuẩn Hộp — 6 Hộp = 1 Lốc, 24 Lốc = 1 Thùng. Mỗi quy đổi có giá riêng.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < conversions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: conversions[i].qtyCtrl,
                    decoration: InputDecoration(
                      labelText: i == 0 ? 'SL $unit' : 'SL ${conversions[i - 1].unitCtrl.text.isEmpty ? 'trước' : conversions[i - 1].unitCtrl.text}',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textHint),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: conversions[i].unitCtrl,
                    decoration: const InputDecoration(labelText: 'Đơn vị mới', isDense: true),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: conversions[i].priceCtrl,
                    decoration: const InputDecoration(labelText: 'Giá riêng', isDense: true),
                    keyboardType: TextInputType.number,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded, size: 20, color: AppColors.error),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setDialogState(() {
                    conversions[i].dispose();
                    conversions.removeAt(i);
                  }),
                ),
              ],
            ),
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
                final product = Product(
                  id: loadedProduct?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameCtrl.text,
                  unit: unit,
                  priceWithVAT: double.tryParse(priceCtrl.text) ?? 0,
                  productGroup: group,
                  barcode: barcodeCtrl.text.trim().isEmpty ? null : barcodeCtrl.text.trim(),
                  imageUrl: imageDataUrl,
                  conversions: [
                    for (final c in conversions)
                      if (c.unitCtrl.text.trim().isNotEmpty)
                        ProductConversion(
                          unit: c.unitCtrl.text.trim(),
                          quantity: double.tryParse(c.qtyCtrl.text) ?? 0,
                          price: double.tryParse(c.priceCtrl.text) ?? 0,
                        ),
                  ],
                );
                final ok = loadedProduct != null
                    ? await productProvider.updateProduct(product)
                    : await productProvider.addProduct(product);
                if (!ctx.mounted) return;
                if (ok) {
                  Navigator.pop(ctx);
                } else {
                  setDialogState(() => saving = false);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(productProvider.error ?? 'Không thể lưu sản phẩm. Vui lòng thử lại.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
        child: Text(saving ? 'Đang lưu...' : (loadedProduct != null ? 'Cập nhật' : 'Thêm')),
      ),
    ],
  );
}

/// Bottom-sheet search/pick list over the existing Danh sách sản phẩm
/// catalog, returned via `Navigator.pop(context, product)`.
class _ExistingProductPicker extends StatefulWidget {
  final List<Product> products;

  const _ExistingProductPicker({required this.products});

  @override
  State<_ExistingProductPicker> createState() => _ExistingProductPickerState();
}

class _ExistingProductPickerState extends State<_ExistingProductPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.products
        : widget.products
            .where((p) => p.name.toLowerCase().contains(query) || (p.barcode ?? '').contains(query))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (sheetCtx, scrollCtrl) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            Text('Chọn sản phẩm có sẵn', style: AppTextStyles.sectionHeader),
            const SizedBox(height: 10),
            TextField(
              decoration: AppDecorations.searchField('Tìm theo tên hoặc mã vạch...'),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text('Không tìm thấy sản phẩm', style: AppTextStyles.caption))
                  : ListView.separated(
                      controller: scrollCtrl,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (itemCtx, i) {
                        final p = filtered[i];
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.inventory_2_rounded, size: 18, color: AppColors.textGrey),
                          ),
                          title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${p.unit} · ${p.productGroup}${p.barcode != null ? ' · ${p.barcode}' : ''}'),
                          onTap: () => Navigator.pop(context, p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
