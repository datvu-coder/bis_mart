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

/// White fill + solid black border, standing out against the Quy đổi
/// cards' tinted gray background (the app-wide default fill is the same
/// gray as that card, so a plain TextField there would be invisible).
InputDecoration _conversionFieldDecoration(String label) => InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.row),
        borderSide: const BorderSide(color: Colors.black, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.row),
        borderSide: const BorderSide(color: Colors.black, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.row),
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
    );

/// A titled card grouping one part of the form (lookup, photo, basic info,
/// quy đổi) so the dialog reads as clear sections instead of one long list
/// of fields.
Widget _formSection({
  required String title,
  String? subtitle,
  Widget? trailing,
  required Widget child,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(14),
    decoration: AppDecorations.card,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle, style: AppTextStyles.caption),
        ],
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

/// One of the two square "lookup" tiles (scan / search) inside the lookup
/// section — a tappable tinted tile instead of a full-width outlined
/// button, so the two actions read as a matched pair.
Widget _lookupTile({required IconData icon, required String label, required VoidCallback onTap}) {
  return Material(
    color: AppColors.surfaceVariant,
    borderRadius: BorderRadius.circular(AppRadius.row),
    child: InkWell(
      borderRadius: BorderRadius.circular(AppRadius.row),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ],
        ),
      ),
    ),
  );
}

/// Compact circular photo picker — docked beside the name/price fields
/// instead of sitting alone in its own full-width section, so the "Thông
/// tin sản phẩm" card reads as one balanced block instead of a near-empty
/// photo card stacked on top of a dense field card.
Widget _photoPicker({required String? imageDataUrl, required VoidCallback onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.row),
            border: Border.all(color: AppColors.borderLight),
            image: imageDataUrl != null
                ? DecorationImage(image: MemoryImage(_decodeDataUrl(imageDataUrl)), fit: BoxFit.cover)
                : null,
          ),
          child: imageDataUrl == null
              ? const Icon(Icons.inventory_2_outlined, color: AppColors.textHint, size: 26)
              : null,
        ),
        Positioned(
          right: -4,
          bottom: -4,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white, width: 2.5),
            ),
            child: const Icon(Icons.camera_alt_rounded, color: AppColors.white, size: 13),
          ),
        ),
      ],
    ),
  );
}

/// One editable "Quy đổi" row: a smaller sale unit than the one before it
/// (the base/standard unit is the largest, e.g. Thùng, with each level
/// below it — Lốc, Hộp — getting progressively smaller), each with its
/// own custom selling price.
class _ConversionRow {
  final unitCtrl = TextEditingController();
  final priceCtrl = TextEditingController();

  _ConversionRow({String unit = '', String price = ''}) {
    unitCtrl.text = unit;
    priceCtrl.text = price;
  }

  void dispose() {
    unitCtrl.dispose();
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
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadius.row),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
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
        _formSection(
          title: 'Lấy sản phẩm có sẵn',
          subtitle: 'Quét mã vạch hoặc tìm kiếm để lấy sản phẩm có sẵn từ Danh sách sản phẩm.',
          child: Row(
            children: [
              Expanded(
                child: _lookupTile(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Quét mã vạch',
                  onTap: () => scanExisting(ctx, setDialogState),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _lookupTile(
                  icon: Icons.search_rounded,
                  label: 'Tìm sản phẩm',
                  onTap: () => searchExisting(ctx, setDialogState),
                ),
              ),
            ],
          ),
        ),
        _formSection(
          title: 'Thông tin sản phẩm',
          child: Column(
            children: [
              Center(
                child: _photoPicker(
                  imageDataUrl: imageDataUrl,
                  onTap: () => showImageSourceSheet(ctx, setDialogState),
                ),
              ),
              const SizedBox(height: 14),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên sản phẩm')),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: 'Giá'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: barcodeCtrl,
                decoration: const InputDecoration(labelText: 'Mã vạch (tùy chọn)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: unit,
                decoration: const InputDecoration(labelText: 'Đơn vị chuẩn (đơn vị lớn nhất)'),
                items: _kProductUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (v) => setDialogState(() => unit = v ?? unit),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: group,
                decoration: const InputDecoration(labelText: 'Nhóm sản phẩm'),
                items: _kProductGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => setDialogState(() => group = v ?? group),
              ),
            ],
          ),
        ),
        _formSection(
          title: 'Quy đổi đơn vị',
          subtitle: 'Đơn vị chuẩn là đơn vị lớn nhất (vd: Thùng), các cấp quy đổi nhỏ dần (vd: Lốc, Hộp) — chỉ cần nhập tên đơn vị và giá bán.',
          trailing: TextButton.icon(
            onPressed: () => setDialogState(() => conversions.add(_ConversionRow())),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Thêm'),
          ),
          child: conversions.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.row),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Text(
                    'Chưa có quy đổi nào',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption,
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < conversions.length; i++)
                      Container(
                        margin: EdgeInsets.only(bottom: i == conversions.length - 1 ? 0 : 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(AppRadius.row),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                                  child: Center(
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Cấp quy đổi ${i + 1}',
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => setDialogState(() {
                                    conversions[i].dispose();
                                    conversions.removeAt(i);
                                  }),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: conversions[i].unitCtrl,
                                    decoration: _conversionFieldDecoration('Đơn vị mới'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: conversions[i].priceCtrl,
                                    decoration: _conversionFieldDecoration('Giá bán'),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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
