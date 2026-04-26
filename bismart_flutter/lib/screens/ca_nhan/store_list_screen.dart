import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/store.dart';
import '../../providers/store_provider.dart';
import '../../providers/permission_provider.dart';
import '../../services/location_service.dart';

class StoreListScreen extends StatefulWidget {
  const StoreListScreen({super.key});

  @override
  State<StoreListScreen> createState() => _StoreListScreenState();
}

class _StoreListScreenState extends State<StoreListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreProvider>().loadStores();
    });
  }

  @override
  Widget build(BuildContext context) {
    final permProv = context.watch<PermissionProvider>();
    final canCreate = permProv.canCreateStore;
    final managedIds = permProv.managedStoreIds.toSet();
    final ownStoreCode = permProv.ownStoreCode;
    return Consumer<StoreProvider>(
      builder: (context, provider, _) {
        // Visible list = stores managed by this user (manager-list membership)
        // PLUS the store they are assigned to via employee.storeCode.
        final stores = provider.filteredStores.where((s) =>
            managedIds.contains(s.id) ||
            (ownStoreCode != null && s.storeCode == ownStoreCode)).toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Danh sách cửa hàng'),
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
                      '${stores.length} cửa hàng',
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
          floatingActionButton: canCreate
              ? FloatingActionButton(
                  onPressed: () => _showStoreFormDialog(),
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.add_rounded, color: AppColors.white),
                )
              : null,
          body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Tìm cửa hàng...',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
              onChanged: (v) => provider.setSearch(v),
            ),
          ),

          // Group filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: ['Tất cả', 'CS', 'HO', 'I', 'II'].map((group) {
                final selected = provider.selectedGroup == group;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(group),
                    selected: selected,
                    selectedColor: AppColors.primaryLight,
                    checkmarkColor: AppColors.primary,
                    onSelected: (_) {
                      provider.setGroup(group);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Store list
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView.builder(
              itemCount: stores.length,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemBuilder: (context, index) {
                final store = stores[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                  ),
                  child: InkWell(
                    onTap: () => _showStoreDetail(store),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                store.storeCode,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  store.name,
                                  style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Nhóm ${store.group}',
                                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (store.latitude != null)
                            IconButton(
                              icon: const Icon(Icons.location_on_rounded, size: 20),
                              color: AppColors.primary,
                              onPressed: () => _openMap(store),
                              tooltip: 'Xem bản đồ',
                            ),
                          if (permProv.canEditStore(store.id))
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              color: AppColors.primary,
                              onPressed: () => _showStoreFormDialog(initial: store),
                              tooltip: 'Sửa',
                            ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 20),
                        ],
                      ),
                    ),
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

  Future<void> _openMap(Store store) async {
    if (store.latitude == null || store.longitude == null) return;
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${store.latitude},${store.longitude}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showStoreDetail(Store store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.store_rounded, color: AppColors.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(store.name, style: AppTextStyles.sectionHeader),
                            const SizedBox(height: 2),
                            Text('Mã: ${store.storeCode} · Nhóm ${store.group}',
                                style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      if (context.read<PermissionProvider>().canEditStore(store.id)) ...[
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                          onPressed: () {
                            Navigator.pop(context);
                            _showStoreFormDialog(initial: store);
                          },
                          tooltip: 'Sửa',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                          onPressed: () {
                            Navigator.pop(context);
                            _confirmDeleteStore(store);
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  _detailRow(Icons.tag_rounded, 'Mã cửa hàng', store.storeCode),
                  _detailRow(Icons.category_rounded, 'Nhóm', store.group),
                  if (store.latitude != null)
                    _detailRow(Icons.location_on_rounded, 'Tọa độ',
                        '${store.latitude}, ${store.longitude}'),
                  if (store.managers.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Quản lý (${store.managers.length})',
                        style: AppTextStyles.sectionHeader),
                    const SizedBox(height: 8),
                    ...store.managers.map((m) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.infoLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.person_rounded,
                                    size: 16, color: AppColors.info),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.name,
                                        style: AppTextStyles.bodyText
                                            .copyWith(fontWeight: FontWeight.w500)),
                                    Text(m.email ?? m.employeeCode,
                                        style: AppTextStyles.caption),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.textGrey),
          ),
          const SizedBox(width: 10),
          Text(label, style: AppTextStyles.caption),
          const Spacer(),
          Text(value, style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showStoreFormDialog({Store? initial}) {
    final isEdit = initial != null;
    final nameCtrl = TextEditingController(text: initial?.name ?? '');
    final codeCtrl = TextEditingController(text: initial?.storeCode ?? '');
    final addressCtrl = TextEditingController(text: initial?.address ?? '');
    final phoneCtrl = TextEditingController(text: initial?.phone ?? '');
    final ownerCtrl = TextEditingController(text: initial?.owner ?? '');
    final taxCtrl = TextEditingController(text: initial?.taxCode ?? '');
    final provinceCtrl = TextEditingController(text: initial?.province ?? '');
    final supCtrl = TextEditingController(text: initial?.sup ?? '');
    final latCtrl = TextEditingController(
        text: initial?.latitude != null ? initial!.latitude.toString() : '');
    final lngCtrl = TextEditingController(
        text: initial?.longitude != null ? initial!.longitude.toString() : '');
    final openCtrl = TextEditingController(text: initial?.openDate ?? '');
    final closeCtrl = TextEditingController(text: initial?.closeDate ?? '');
    final typeCtrl = TextEditingController(text: initial?.storeType ?? '');
    String group = initial?.group ?? 'I';
    String status = initial?.status ?? 'Hoạt động';

    const groups = ['CS', 'HO', 'I', 'II'];
    const statuses = ['Hoạt động', 'Tạm ngưng', 'Đóng cửa'];

    InputDecoration dec(String label) => InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        );

    showDialog(
      context: context,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final isWide = mq.size.width >= 600;
        final dialogWidth = isWide ? 480.0 : (mq.size.width - 4);

        Future<void> useCurrentLocation(StateSetter setLocal) async {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text('Đang lấy vị trí hiện tại...'),
              duration: Duration(seconds: 2),
            ),
          );
          try {
            final pos = await LocationService.getCurrentPosition();
            setLocal(() {
              latCtrl.text = pos.latitude.toStringAsFixed(7);
              lngCtrl.text = pos.longitude.toStringAsFixed(7);
            });
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('Đã cập nhật vị trí'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          } catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(e.toString()),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        }

        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: isWide ? 40 : 2,
              vertical: 24,
            ),
            contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(isEdit ? 'Sửa cửa hàng' : 'Thêm cửa hàng'),
            content: SizedBox(
              width: dialogWidth,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameCtrl, decoration: dec('Tên cửa hàng *')),
                    const SizedBox(height: 10),
                    TextField(controller: codeCtrl, decoration: dec('Mã cửa hàng *')),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: groups.contains(group) ? group : 'I',
                            decoration: dec('Nhóm'),
                            items: groups
                                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                .toList(),
                            onChanged: (v) => setLocal(() => group = v ?? 'I'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: statuses.contains(status) ? status : 'Hoạt động',
                            decoration: dec('Trạng thái'),
                            items: statuses
                                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) => setLocal(() => status = v ?? 'Hoạt động'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: addressCtrl, decoration: dec('Địa chỉ')),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: provinceCtrl, decoration: dec('Tỉnh/Thành'))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: phoneCtrl, decoration: dec('SĐT'))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: ownerCtrl, decoration: dec('Chủ sở hữu'))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: taxCtrl, decoration: dec('Mã số thuế'))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: typeCtrl, decoration: dec('Loại cửa hàng'))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: supCtrl, decoration: dec('SUP'))),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Định vị cửa hàng
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded,
                                  size: 18, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text('Định vị cửa hàng',
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontWeight: FontWeight.w600,
                                  )),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: latCtrl,
                                  decoration: dec('Vĩ độ'),
                                  keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true, signed: true),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: lngCtrl,
                                  decoration: dec('Kinh độ'),
                                  keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true, signed: true),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => useCurrentLocation(setLocal),
                                  icon: const Icon(Icons.my_location_rounded, size: 18),
                                  label: const Text('Lấy vị trí hiện tại'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(color: AppColors.primary),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                              if (latCtrl.text.isNotEmpty && lngCtrl.text.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Xoá vị trí',
                                  onPressed: () => setLocal(() {
                                    latCtrl.clear();
                                    lngCtrl.clear();
                                  }),
                                  icon: const Icon(Icons.clear_rounded,
                                      color: AppColors.error),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: openCtrl, decoration: dec('Ngày mở (YYYY-MM-DD)'))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: closeCtrl, decoration: dec('Ngày đóng (YYYY-MM-DD)'))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
              ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty || codeCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Vui lòng nhập tên và mã cửa hàng')),
                    );
                    return;
                  }
                  String? nz(String s) => s.trim().isEmpty ? null : s.trim();
                  final updated = Store(
                    id: initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameCtrl.text.trim(),
                    storeCode: codeCtrl.text.trim(),
                    group: group,
                    managers: initial?.managers ?? const [],
                    latitude: double.tryParse(latCtrl.text.trim()),
                    longitude: double.tryParse(lngCtrl.text.trim()),
                    province: nz(provinceCtrl.text),
                    sup: nz(supCtrl.text),
                    status: status,
                    openDate: nz(openCtrl.text),
                    closeDate: nz(closeCtrl.text),
                    storeType: nz(typeCtrl.text),
                    address: nz(addressCtrl.text),
                    phone: nz(phoneCtrl.text),
                    owner: nz(ownerCtrl.text),
                    taxCode: nz(taxCtrl.text),
                  );
                  final prov = context.read<StoreProvider>();
                  if (isEdit) {
                    prov.updateStore(updated);
                  } else {
                    prov.addStore(updated);
                  }
                  Navigator.pop(ctx);
                },
                child: Text(isEdit ? 'Lưu' : 'Thêm'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteStore(Store store) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa cửa hàng'),
        content: Text('Bạn có chắc muốn xóa "${store.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              context.read<StoreProvider>().deleteStore(store.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}
