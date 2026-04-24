import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/training_provider.dart';
import '../../widgets/common/data_panel.dart';
import '../../widgets/cards/lesson_card.dart';
import '../../widgets/cards/social_post_card.dart';
import 'package:bismart_flutter/models/community_post.dart';

class DaoTaoScreen extends StatefulWidget {
  const DaoTaoScreen({super.key});

  @override
  State<DaoTaoScreen> createState() => _DaoTaoScreenState();
}

class _DaoTaoScreenState extends State<DaoTaoScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late TabController _tabController;
  final List<_AiAssistantItem> _aiAssistants = [
    const _AiAssistantItem(
      name: 'AI Trợ lý Momcare',
      description: 'Khám phá AI hỗ trợ chăm sóc mẹ & bé',
      url: 'https://momcare.ai',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TrainingProvider>().loadTrainingData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1280;
    final isTablet = screenWidth >= 900 && screenWidth < 1280;
    final isCompactMobile = screenWidth < 430;
    final isWide = isDesktop || isTablet;
    final authProvider = context.watch<AuthProvider>();
    final canManageAi = _isTmkAccount(authProvider.currentUser?.position);

    return Consumer<TrainingProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.posts.isEmpty && provider.lessons.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final hPad = isWide ? (isDesktop ? 32.0 : 24.0) : 16.0;

        // Tab layout for all screen sizes
        return Column(
            children: [
              if (!isCompactMobile)
                Padding(
                  padding: EdgeInsets.fromLTRB(hPad, isWide ? 20 : 14, hPad, 10),
                  child: _buildScreenHeader(provider, isWide),
                ),
              Container(
                margin: EdgeInsets.fromLTRB(hPad, isCompactMobile ? 10 : 0, hPad, 0),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textGrey,
                  indicator: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelStyle:
                      const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  unselectedLabelStyle:
                      const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  tabs: const [
                    Tab(text: 'Cộng đồng'),
                    Tab(text: 'Bài giảng'),
                    Tab(text: 'Lịch học'),
                    Tab(text: 'Trợ lý AI'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 12),
                      child: _buildCommunityPanel(provider),
                    ),
                    SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 12),
                      child: _buildLessonPanel(provider),
                    ),
                    SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 12),
                      child: _buildSchedulePanel(provider),
                    ),
                    SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 12),
                      child: _buildAiAssistantPanel(canManageAi),
                    ),
                  ],
                ),
              ),
            ],
          );
      },
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildScreenHeader(TrainingProvider provider, bool emphasize) {
    final lessonCount = provider.lessons.length;
    final todayEvents = provider.getEventsForDay(DateTime.now()).length;
    final isCompactMobile = !emphasize && MediaQuery.of(context).size.width < 430;

    return Container(
      width: double.infinity,
      padding: isCompactMobile
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
          : EdgeInsets.all(emphasize ? 20 : 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCompactMobile) ...[
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: AppColors.info,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.daoTao, style: AppTextStyles.appTitle),
                      const SizedBox(height: 2),
                      Text('Cộng đồng, bài học & lịch đào tạo',
                          style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (isCompactMobile)
            Row(
              children: [
                Expanded(
                  child: _buildKpiChip(
                    icon: Icons.play_lesson_rounded,
                    label: 'Bài giảng',
                    value: '$lessonCount',
                    color: AppColors.info,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildKpiChip(
                    icon: Icons.event_rounded,
                    label: 'Hôm nay',
                    value: '$todayEvents',
                    color: AppColors.warning,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildKpiChip(
                    icon: Icons.people_rounded,
                    label: 'Bài viết',
                    value: '${provider.posts.length}',
                    color: AppColors.primary,
                    compact: true,
                  ),
                ),
              ],
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildKpiChip(
                  icon: Icons.play_lesson_rounded,
                  label: 'Bài giảng',
                  value: '$lessonCount',
                  color: AppColors.info,
                ),
                _buildKpiChip(
                  icon: Icons.event_rounded,
                  label: 'Hôm nay',
                  value: '$todayEvents sự kiện',
                  color: AppColors.warning,
                ),
                _buildKpiChip(
                  icon: Icons.people_rounded,
                  label: 'Bài viết',
                  value: '${provider.posts.length}',
                  color: AppColors.primary,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildKpiChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: compact
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption
                      .copyWith(color: color, fontWeight: FontWeight.w800),
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text('$label: ',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                Text(value,
                    style: AppTextStyles.caption
                        .copyWith(color: color, fontWeight: FontWeight.w800)),
              ],
            ),
    );
  }

  Widget _buildAiAssistantPanel(bool canManageAi) {
    return DataPanel(
      title: 'Trợ lý AI',
      trailing: canManageAi
          ? TextButton.icon(
              onPressed: _showAddAiAssistantDialog,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Thêm AI'),
            )
          : null,
      child: Column(
        children: _aiAssistants.map((item) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openAiTool(item.url),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name,
                                style: AppTextStyles.bodyTextMedium
                                    .copyWith(color: Colors.white)),
                            const SizedBox(height: 2),
                            Text(item.description,
                                style: AppTextStyles.caption
                                    .copyWith(color: Colors.white70)),
                          ],
                        ),
                      ),
                      const Icon(Icons.open_in_new_rounded,
                          color: Colors.white70, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Panels ────────────────────────────────────────────────────────────────

  Widget _buildCommunityPanel(TrainingProvider provider) {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    final userName = authProvider.currentUser?.fullName ?? 'Bạn';
    final currentStore = currentUser?.storeCode;
    final visiblePosts = provider.posts.where((post) {
      if (post.visibility != 'store') return true;
      if (post.authorId != null && post.authorId == currentUser?.id) return true;
      if (post.storeCode == null || post.storeCode!.isEmpty) return true;
      return post.storeCode == currentStore;
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Inline composer (Facebook-style) ─────────────────────────────
        Container(
          margin: const EdgeInsets.only(bottom: 1),
          color: AppColors.white,
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  _CommunityAvatar(name: userName, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showCreatePostDialog(provider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'Bạn đang nghĩ gì?',
                          style: AppTextStyles.bodyText
                              .copyWith(color: AppColors.textHint),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: AppColors.border),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ComposerAction(
                    icon: Icons.image_rounded,
                    label: 'Ảnh',
                    color: AppColors.success,
                    onTap: () => _showCreatePostDialog(provider, initialTab: 'photo'),
                  ),
                  _ComposerAction(
                    icon: Icons.videocam_rounded,
                    label: 'Video',
                    color: AppColors.error,
                    onTap: () => _showCreatePostDialog(provider, initialTab: 'video'),
                  ),
                  _ComposerAction(
                    icon: Icons.edit_rounded,
                    label: 'Viết bài',
                    color: AppColors.primary,
                    onTap: () => _showCreatePostDialog(provider, initialTab: 'text'),
                  ),
                ],
              ),
            ],
          ),
        ),
        // ── Feed ─────────────────────────────────────────────────────────
        if (visiblePosts.isEmpty)
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.forum_rounded,
                      size: 48, color: AppColors.textHint),
                  const SizedBox(height: 8),
                  Text('Chưa có bài viết nào',
                      style: AppTextStyles.caption),
                ],
              ),
            ),
          )
        else
          ...visiblePosts.map<Widget>((post) => SocialPostCard(
                post: post,
                onLike: () => provider.toggleLike(post.id),
                onComment: () => _showCommentDialog(post.id, provider),
                onShare: () => _sharePost(post),
                onEdit: _canManagePost(post, currentUser)
                    ? () => _showEditPostDialog(provider, post)
                    : null,
                onDelete: _canManagePost(post, currentUser)
                    ? () => _confirmDeletePost(provider, post)
                    : null,
              )),
      ],
    );
  }

  Widget _buildLessonPanel(TrainingProvider provider) {
    return DataPanel(
      title: 'Bài giảng',
      child: provider.lessons.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.video_library_rounded,
                        size: 40, color: AppColors.textHint),
                    const SizedBox(height: 8),
                    Text('Chưa có bài giảng', style: AppTextStyles.caption),
                  ],
                ),
              ),
            )
          : Column(
              children: provider.lessons
                  .map<Widget>((lesson) => LessonCard(
                        lesson: lesson,
                        onJoin: () => _showLessonDetail(lesson),
                      ))
                  .toList(),
            ),
    );
  }

  Widget _buildSchedulePanel(TrainingProvider provider) {
    final events = (_selectedDay != null
            ? provider.getEventsForDay(_selectedDay!)
            : provider.getEventsForDay(_focusedDay))
        .toList();

    return DataPanel(
      title: 'Lịch học',
      trailing: TextButton.icon(
        onPressed: () => _showAddEventDialog(provider),
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('Thêm'),
      ),
      child: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) => provider.getEventsForDay(day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarStyle: CalendarStyle(
              selectedDecoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: AppColors.warning,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonDecoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              formatButtonTextStyle: AppTextStyles.caption,
            ),
          ),
          if (events.isNotEmpty) ...[
            const Divider(height: 20),
            ...events.map((event) => Dismissible(
                  key: Key(event),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) =>
                      provider.removeEvent(_selectedDay ?? _focusedDay, event),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    color: AppColors.error,
                    child: const Icon(Icons.delete_rounded,
                        color: Colors.white, size: 20),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.infoLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_note_rounded,
                            size: 16, color: AppColors.info),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(event,
                              style: AppTextStyles.bodyText
                                  .copyWith(color: AppColors.info)),
                        ),
                      ],
                    ),
                  ),
                )),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Không có sự kiện ngày này',
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showCreatePostDialog(TrainingProvider provider, {String initialTab = 'text'}) {
    final textController = TextEditingController();
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    final userName = authProvider.currentUser?.fullName ?? 'Bạn';
    final List<Map<String, dynamic>> pickedFiles = [];
    String selectedVisibility = 'public';
    bool autoPickConsumed = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickMedia({bool videoOnly = false}) async {
            try {
              final uploadInput = html.FileUploadInputElement()
                ..accept = videoOnly ? 'video/*' : 'image/*,video/*'
                ..multiple = true;
              html.document.body!.append(uploadInput);
              uploadInput.onChange.listen((event) {
                final files = uploadInput.files;
                if (files == null) return;
                for (final file in files) {
                  final reader = html.FileReader();
                  reader.onLoadEnd.listen((_) {
                    final dataUrl = reader.result as String?;
                    if (dataUrl != null) {
                      setDialogState(() {
                        pickedFiles.add({
                          'name': file.name,
                          'dataUrl': dataUrl,
                          'isVideo': file.type.startsWith('video/'),
                        });
                      });
                    }
                  });
                  reader.readAsDataUrl(file);
                }
              });
              uploadInput.click();
            } catch (_) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Không thể mở cửa sổ chọn file.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          }

          Future<void> pickFeeling() async {
            final feeling = await showModalBottomSheet<String>(
              context: ctx,
              backgroundColor: AppColors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (sheetCtx) {
                const feelings = [
                  ('😀', 'vui vẻ'),
                  ('😍', 'rất thích'),
                  ('😢', 'buồn'),
                  ('😡', 'bức xúc'),
                  ('🤩', 'phấn khích'),
                  ('🙏', 'biết ơn'),
                ];
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Thêm cảm xúc', style: AppTextStyles.sectionHeader),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: feelings
                              .map(
                                (item) => ActionChip(
                                  label: Text('${item.$1} ${item.$2}'),
                                  onPressed: () => Navigator.pop(sheetCtx, '${item.$1} đang ${item.$2}'),
                                  backgroundColor: AppColors.surfaceVariant,
                                  side: const BorderSide(color: AppColors.border),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );

            if (feeling == null) return;
            final current = textController.text.trim();
            textController.text = current.isEmpty ? feeling : '$current - $feeling';
            textController.selection = TextSelection.fromPosition(
              TextPosition(offset: textController.text.length),
            );
            setDialogState(() {});
          }

          if (!autoPickConsumed && (initialTab == 'photo' || initialTab == 'video')) {
            autoPickConsumed = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (ctx.mounted) {
                pickMedia(videoOnly: initialTab == 'video');
              }
            });
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ─────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('Tạo bài viết',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700)),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.surfaceVariant,
                            padding: const EdgeInsets.all(6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Author row ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                    child: Row(
                      children: [
                        _CommunityAvatar(name: userName, size: 44),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(userName,
                                style: AppTextStyles.bodyTextMedium),
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedVisibility,
                                  icon: const Icon(Icons.arrow_drop_down_rounded,
                                      size: 16, color: AppColors.textSecondary),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                  items: const [
                                    DropdownMenuItem<String>(
                                      value: 'public',
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.public_rounded,
                                              size: 13, color: AppColors.textSecondary),
                                          SizedBox(width: 4),
                                          Text('Mọi người'),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem<String>(
                                      value: 'store',
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.storefront_rounded,
                                              size: 13, color: AppColors.textSecondary),
                                          SizedBox(width: 4),
                                          Text('Cửa hàng'),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setDialogState(() => selectedVisibility = value);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Text input ────────────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: textController,
                            maxLines: null,
                            minLines: 4,
                            autofocus: initialTab == 'text',
                            style: const TextStyle(fontSize: 18),
                            decoration: InputDecoration(
                              hintText: '$userName ơi, bạn đang nghĩ gì thế?',
                              hintStyle: const TextStyle(
                                  color: AppColors.textHint, fontSize: 18),
                              border: InputBorder.none,
                            ),
                          ),
                          // ── Image previews ──────────────────────────
                          if (pickedFiles.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _buildImagePreviews(pickedFiles, setDialogState),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // ── Add to post bar ────────────────────────────────────
                  Container(
                    margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 360;
                        return Row(
                          children: [
                            if (!compact)
                              const Text('Thêm vào bài viết',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary)),
                            if (!compact) const Spacer(),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: compact
                                    ? MainAxisAlignment.spaceBetween
                                    : MainAxisAlignment.end,
                                children: [
                                  _iconBtn(Icons.image_rounded, AppColors.success,
                                      'Ảnh', () async {
                                    await pickMedia();
                                  }),
                                  _iconBtn(Icons.videocam_rounded, AppColors.error,
                                      'Video', () async {
                                    await pickMedia(videoOnly: true);
                                  }),
                                  _iconBtn(Icons.emoji_emotions_rounded,
                                      AppColors.warning, 'Cảm xúc', () async {
                                    await pickFeeling();
                                  }),
                                  _iconBtn(Icons.location_on_rounded,
                                      AppColors.primary, 'Check-in', () {
                                    final current = textController.text.trim();
                                    const checkIn = '📍 đang check-in';
                                    textController.text =
                                        current.isEmpty ? checkIn : '$current - $checkIn';
                                    textController.selection = TextSelection.fromPosition(
                                      TextPosition(offset: textController.text.length),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // ── Submit button ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final text = textController.text.trim();
                          if (text.isEmpty && pickedFiles.isEmpty) return;
                          try {
                            await provider.createPost(
                              text,
                              authorName: userName,
                              authorId: currentUser?.id,
                              visibility: selectedVisibility,
                              storeCode: currentUser?.storeCode,
                              imageDataUrls: pickedFiles
                                  .map((f) => f['dataUrl'] as String)
                                  .toList(),
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('Đăng bài thất bại: $e'),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Đăng',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) => textController.dispose());
  }

  Widget _buildImagePreviews(
      List<Map<String, dynamic>> files, StateSetter setDialogState) {
    if (files.length == 1) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _mediaPreview(files[0], height: 200),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: _removeImageBtn(() => setDialogState(() => files.removeAt(0))),
          ),
        ],
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
      itemCount: files.length,
      itemBuilder: (_, i) => Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _mediaPreview(files[i]),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: _removeImageBtn(() => setDialogState(() => files.removeAt(i))),
          ),
        ],
      ),
    );
  }

  Widget _mediaPreview(Map<String, dynamic> file, {double? height}) {
    final isVideo = file['isVideo'] as bool? ?? false;
    if (isVideo) {
      return Container(
        width: double.infinity,
        height: height,
        color: AppColors.surfaceVariant,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_rounded,
                size: 34, color: AppColors.error),
            const SizedBox(height: 6),
            Text(
              file['name'] as String? ?? 'Video',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption,
            ),
          ],
        ),
      );
    }

    return Image.network(
      file['dataUrl'] as String,
      width: double.infinity,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _imagePlaceholder(file['name'] as String),
    );
  }

  Widget _imagePlaceholder(String name) => Container(
        color: AppColors.surfaceVariant,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.image_rounded, size: 32, color: AppColors.textHint),
          const SizedBox(height: 4),
          Text(name,
              style: AppTextStyles.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      );

  Widget _removeImageBtn(VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle),
          child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
        ),
      );

  Widget _iconBtn(IconData icon, Color color, String tooltip, VoidCallback onTap) =>
      Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      );

  void _showCommentDialog(String postId, TrainingProvider provider) {
    final commentController = TextEditingController();
    final authProvider = context.read<AuthProvider>();
    final userName = authProvider.currentUser?.fullName ?? 'Bạn';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final post = provider.posts.firstWhere(
            (p) => p.id == postId,
            orElse: () => throw StateError('Post not found'),
          );

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.92,
              expand: false,
              builder: (context, scrollController) => Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                    child: Row(
                      children: [
                        Text(
                          '${post.commentCount} bình luận',
                          style: AppTextStyles.sectionHeader,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Comment list
                  Expanded(
                    child: post.comments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded,
                                    size: 48, color: AppColors.textHint),
                                const SizedBox(height: 8),
                                Text('Chưa có bình luận nào',
                                    style: AppTextStyles.caption),
                                const SizedBox(height: 4),
                                Text('Hãy là người đầu tiên bình luận!',
                                    style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textHint)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding:
                                const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            itemCount: post.comments.length,
                            itemBuilder: (_, i) {
                              final c = post.comments[i];
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 14),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    _CommunityAvatar(
                                        name: c.authorName, size: 36),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding:
                                                const EdgeInsets.fromLTRB(
                                                    12, 8, 12, 8),
                                            decoration: BoxDecoration(
                                              color:
                                                  AppColors.surfaceVariant,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      14),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(c.authorName,
                                                    style: AppTextStyles
                                                        .bodyText
                                                        .copyWith(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700)),
                                                const SizedBox(height: 2),
                                                Text(c.text,
                                                    style: AppTextStyles
                                                        .bodyText),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 8, top: 4),
                                            child: Text(
                                              _relativeTime(c.createdAt),
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                      color: AppColors
                                                          .textHint),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  // Input row
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                    decoration: const BoxDecoration(
                      border: Border(
                          top: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        _CommunityAvatar(name: userName, size: 36),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            autofocus: true,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Viết bình luận...',
                              hintStyle: const TextStyle(
                                  color: AppColors.textHint, fontSize: 14),
                              filled: true,
                              fillColor: AppColors.surfaceVariant,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (val) {
                              final text = val.trim();
                              if (text.isEmpty) return;
                              provider.addCommentText(postId, text,
                                  authorName: userName);
                              commentController.clear();
                              setSheetState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            final text = commentController.text.trim();
                            if (text.isEmpty) return;
                            provider.addCommentText(postId, text,
                                authorName: userName);
                            commentController.clear();
                            setSheetState(() {});
                          },
                          borderRadius: BorderRadius.circular(50),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.gradientStart,
                                  AppColors.gradientEnd
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.send_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) => commentController.dispose());
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  void _sharePost(CommunityPost post) {
    final shareText = post.content ?? '${post.authorName} đã đăng một bài viết';
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Đã sao chép nội dung bài viết'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  bool _canManagePost(CommunityPost post, dynamic currentUser) {
    if (currentUser == null) return false;
    final isOwnerById = post.authorId != null && post.authorId == currentUser.id;
    final isOwnerByName = post.authorName == currentUser.fullName;
    final role = (currentUser.position ?? '').toString().toUpperCase();
    final isPrivileged = role == 'ADM' || role == 'TMK';
    return isOwnerById || isOwnerByName || isPrivileged;
  }

  void _showEditPostDialog(TrainingProvider provider, CommunityPost post) {
    final controller = TextEditingController(text: post.content ?? '');
    var visibility = post.visibility;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Sửa bài viết'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Nội dung bài viết...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: visibility,
                decoration: const InputDecoration(
                  labelText: 'Quyền xem',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'public', child: Text('Mọi người')),
                  DropdownMenuItem(value: 'store', child: Text('Cửa hàng')),
                ],
                onChanged: (val) {
                  if (val == null) return;
                  setDialogState(() => visibility = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                try {
                  await provider.updatePost(
                    post.id,
                    content: text,
                    visibility: visibility,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Lưu thất bại: $e'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    ).then((_) => controller.dispose());
  }

  void _confirmDeletePost(TrainingProvider provider, CommunityPost post) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bài viết'),
        content: const Text('Bạn có chắc muốn xóa bài viết này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
            ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              try {
                await provider.deletePost(post.id);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Xóa thất bại: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _showLessonDetail(dynamic lesson) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
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
            Text(lesson.title ?? '', style: AppTextStyles.sectionHeader),
            const SizedBox(height: 8),
            Text(lesson.description ?? '', style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }

  void _showAddEventDialog(TrainingProvider provider) {
    final controller = TextEditingController();
    final targetDay = _selectedDay ?? _focusedDay;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm sự kiện'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Tên sự kiện...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              provider.addEvent(targetDay, controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  bool _isTmkAccount(String? position) {
    return (position ?? '').toUpperCase() == 'TMK';
  }

  Future<void> _openAiTool(String urlText) async {
    final uri = Uri.tryParse(urlText.trim());
    if (uri == null) {
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showAddAiAssistantDialog() {
    final currentPos =
        (context.read<AuthProvider>().currentUser?.position ?? '').toUpperCase();
    if (currentPos != 'TMK') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chỉ tài khoản TMK mới được thêm AI mới.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final descController = TextEditingController();
    final urlController = TextEditingController(text: 'https://');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm trợ lý AI mới'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Tên AI',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Mô tả ngắn',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Đường dẫn',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final desc = descController.text.trim();
              final url = urlController.text.trim();
              final parsed = Uri.tryParse(url);

              if (name.isEmpty ||
                  desc.isEmpty ||
                  parsed == null ||
                  parsed.scheme.isEmpty ||
                  parsed.host.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng nhập đầy đủ và URL hợp lệ.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              setState(() {
                _aiAssistants.add(
                  _AiAssistantItem(name: name, description: desc, url: url),
                );
              });
              Navigator.pop(ctx);
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }
}

class _AiAssistantItem {
  final String name;
  final String description;
  final String url;

  const _AiAssistantItem({
    required this.name,
    required this.description,
    required this.url,
  });
}

class _CommunityAvatar extends StatelessWidget {
  final String name;
  final double size;

  const _CommunityAvatar({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'B',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }
}

class _ComposerAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ComposerAction({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompactMobile = MediaQuery.of(context).size.width < 390;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            if (!isCompactMobile) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}