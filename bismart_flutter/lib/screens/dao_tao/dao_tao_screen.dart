import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lms_provider.dart';
import '../../providers/training_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/common/desktop_layout.dart';
import '../../widgets/common/data_panel.dart';
import '../../widgets/common/responsive_form.dart';
import '../../widgets/common/header_action_cluster.dart';
import '../../widgets/cards/lesson_card.dart';
import '../../widgets/cards/social_post_card.dart';
import 'package:bismart_flutter/models/community_post.dart';
import '../../models/lesson.dart';
import 'lesson_detail_screen.dart';
import 'lesson_history_screen.dart';
import 'post_detail_screen.dart';

const _videoExtensions = {'mp4', 'mov', 'webm', 'm4v', 'avi', 'mkv'};

bool _isVideoExtension(String? extension) =>
    _videoExtensions.contains((extension ?? '').toLowerCase());

String _imageMimeType(String? extension) {
  switch ((extension ?? '').toLowerCase()) {
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'heic':
      return 'image/heic';
    case 'jpg':
    case 'jpeg':
    default:
      return 'image/jpeg';
  }
}

class DaoTaoScreen extends StatefulWidget {
  const DaoTaoScreen({super.key});

  @override
  State<DaoTaoScreen> createState() => _DaoTaoScreenState();
}

class _DaoTaoScreenState extends State<DaoTaoScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TrainingProvider>().loadTrainingData();
      context.read<LmsProvider>().loadAiTools();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1280;
    final isTablet = screenWidth >= 900 && screenWidth < 1280;
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
        final contentPad = isWide ? hPad : 16.0;

        final body = Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(contentPad, isWide ? 20 : 14, contentPad, 10),
                child: _buildScreenHeader(provider, isWide),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(contentPad, 2, contentPad, 12),
                  child: Column(
                    children: [
                      _buildLessonPanel(provider),
                      _buildSchedulePanel(provider),
                      _buildAiAssistantPanel(canManageAi),
                    ],
                  ),
                ),
              ),
            ],
          );
        return isDesktop ? DesktopMaxWidth(child: body) : body;
      },
    );
  }

  void _openCommunityScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('Cộng đồng')),
          body: Consumer<TrainingProvider>(
            builder: (context, provider, _) => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildCommunityPanel(provider),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildScreenHeader(TrainingProvider provider, bool emphasize) {
    final lessonCount = provider.lessons.length;
    final todayEvents = provider.getEventsForDay(DateTime.now()).length;
    final isCompactMobile = !emphasize && MediaQuery.of(context).size.width < 430;
    final communityAction = HeaderActionCluster(
      actions: [
        HeaderAction(
          icon: Icons.forum_rounded,
          label: 'Cộng đồng',
          onPressed: _openCommunityScreen,
        ),
      ],
    );

    // Phones keep just the title + community action — the KPI chips already
    // dropped their icons/numbers there, so a full card adds nothing.
    if (isCompactMobile) {
      return Row(
        children: [
          Expanded(
            child: Text(AppStrings.daoTao, style: AppTextStyles.appTitle),
          ),
          communityAction,
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(emphasize ? 20 : 14),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
              communityAction,
            ],
          ),
          const SizedBox(height: 12),
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
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                      fontSize: 10, color: AppColors.textGrey, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
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
    final isMobile = MediaQuery.of(context).size.width < 900;
    final aiTools = context.watch<LmsProvider>().aiTools;
    return DataPanel(
      title: 'Trợ lý AI',
      // Mobile: padding ngang = 0 → nội dung cách mép màn hình 2 px
      // (do outer SingleChildScrollView = 2 px), đồng nhất toàn tab.
      padding: isMobile
          ? const EdgeInsets.fromLTRB(0, 18, 0, 18)
          : null,
      trailing: canManageAi
          ? IconButton(
              onPressed: _showAddAiAssistantDialog,
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Thêm AI',
            )
          : null,
      child: aiTools.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Chưa có trợ lý AI nào.',
                  style: AppTextStyles.caption),
            )
          : Column(
              children: aiTools.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.purpleAccent,
                    borderRadius: BorderRadius.circular(AppRadius.row),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.row),
                      onTap: () => _openAiTool(item.link ?? ''),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(AppRadius.chip),
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
                                  if ((item.link ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(item.link!,
                                        style: AppTextStyles.caption
                                            .copyWith(color: Colors.white70)),
                                  ],
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
    final isMobile = MediaQuery.of(context).size.width < 900;
    // Mobile: margin ngang = 0 → cách mép màn hình 2 px (đồng nhất).
    final hMargin = isMobile ? 0.0 : 12.0;
    final visiblePosts = provider.posts.where((post) {
      if (post.visibility != 'store') return true;
      if (post.authorId != null && post.authorId == currentUser?.id) return true;
      if (post.storeCode == null || post.storeCode!.isEmpty) return true;
      return post.storeCode == currentStore;
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Inline composer ─────────────────────────────
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Container(
              margin: EdgeInsets.fromLTRB(hMargin, 12, hMargin, 12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppRadius.row),
                border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
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
                                horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(24),
                              border:
                                  Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              'Bạn đang nghĩ gì, $userName?',
                              style: AppTextStyles.bodyText
                                  .copyWith(color: AppColors.textHint),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, color: AppColors.border),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ComposerAction(
                        icon: Icons.image_rounded,
                        label: 'Ảnh',
                        color: AppColors.success,
                        onTap: () => _showCreatePostDialog(provider,
                            initialTab: 'photo'),
                      ),
                      _ComposerAction(
                        icon: Icons.videocam_rounded,
                        label: 'Video',
                        color: AppColors.error,
                        onTap: () => _showCreatePostDialog(provider,
                            initialTab: 'video'),
                      ),
                      _ComposerAction(
                        icon: Icons.edit_rounded,
                        label: 'Viết bài',
                        color: AppColors.primary,
                        onTap: () => _showCreatePostDialog(provider,
                            initialTab: 'text'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // ── Feed ─────────────────────────────────────────────────────────
        if (visiblePosts.isEmpty)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: hMargin),
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.row),
                  border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.6)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.forum_rounded,
                          size: 56, color: AppColors.textHint),
                      const SizedBox(height: 12),
                      Text('Chưa có bài viết nào',
                          style: AppTextStyles.bodyText.copyWith(
                              color: AppColors.textGrey,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Hãy là người đầu tiên chia sẻ!',
                          style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          ...visiblePosts.map<Widget>((post) => SocialPostCard(
                post: post,
                onTap: () => _openPostDetail(post.id),
                onTapMedia: () => _openPostDetail(post.id),
                onLike: () => provider.toggleLike(post.id),
                onComment: () => _openPostDetail(post.id),
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
    final isAdmin = _isAdmin();
    final isMobile = MediaQuery.of(context).size.width < 900;
    // Mobile: padding ngang = 0 → cách mép màn hình 2 px (đồng nhất).
    final panelPadding = isMobile
        ? const EdgeInsets.fromLTRB(0, 18, 0, 18)
        : null;
    return DataPanel(
      title: 'Bài giảng',
      padding: panelPadding,
      trailing: isAdmin
          ? IconButton(
              onPressed: () => _showCreateLessonDialog(provider),
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Thêm bài giảng',
            )
          : null,
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
                  .map<Widget>((lesson) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: LessonCard(
                          lesson: lesson,
                          onJoin: () => _showLessonDetail(lesson),
                          onHistory: () => _openLessonHistory(lesson),
                          onEdit: isAdmin
                              ? () => _showLessonDetail(lesson)
                              : null,
                          onDelete: isAdmin
                              ? () => _confirmDeleteLesson(provider, lesson)
                              : null,
                        ),
                      ))
                  .toList(),
            ),
    );
  }

  bool _isAdmin() {
    final pos = (context.read<AuthProvider>().currentUser?.position ?? '')
        .toUpperCase();
    // Theo yêu cầu mới: TMK quản lý bài giảng. ADM/ADMIN là super-admin.
    return pos == 'ADM' || pos == 'ADMIN' || pos == 'TMK';
  }

  Widget _buildSchedulePanel(TrainingProvider provider) {
    final events = (_selectedDay != null
            ? provider.getEventsForDay(_selectedDay!)
            : provider.getEventsForDay(_focusedDay))
        .toList();
    final isMobile = MediaQuery.of(context).size.width < 900;

    return DataPanel(
      title: 'Lịch học',
      // Mobile: padding ngang = 0 → cách mép màn hình 2 px (đồng nhất).
      padding: isMobile
          ? const EdgeInsets.fromLTRB(0, 18, 0, 18)
          : null,
      trailing: IconButton(
        onPressed: () => _showAddEventDialog(provider),
        icon: const Icon(Icons.add_rounded),
        tooltip: 'Thêm sự kiện',
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
                      borderRadius: BorderRadius.circular(AppRadius.chip),
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
              final result = await FilePicker.pickFiles(
                type: videoOnly ? FileType.video : FileType.media,
                allowMultiple: true,
                withData: true,
              );
              if (result == null) return;
              for (final file in result.files) {
                final bytes = file.bytes;
                if (bytes == null) continue;
                final isVideo = _isVideoExtension(file.extension);
                if (isVideo) {
                  // Only one video per post.
                  if (pickedFiles.any((f) => f['isVideo'] == true)) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Mỗi bài chỉ được đính kèm 1 video.'),
                        ),
                      );
                    }
                    continue;
                  }
                  if (file.size > 1024 * 1024 * 1024) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Video vượt quá 1GB.'),
                        ),
                      );
                    }
                    continue;
                  }
                  // Insert placeholder while uploading.
                  final placeholder = <String, dynamic>{
                    'name': file.name,
                    'isVideo': true,
                    'uploading': true,
                    'progress': 0.0,
                  };
                  setDialogState(() => pickedFiles.add(placeholder));
                  try {
                    final remote = await ApiService().uploadPostVideo(
                      bytes: bytes,
                      filename: file.name,
                      onProgress: (sent, total) {
                        if (total > 0) {
                          setDialogState(() {
                            placeholder['progress'] = sent / total;
                          });
                        }
                      },
                    );
                    setDialogState(() {
                      placeholder['uploading'] = false;
                      placeholder['remoteUrl'] = remote;
                      placeholder['progress'] = 1.0;
                    });
                  } catch (e) {
                    setDialogState(() => pickedFiles.remove(placeholder));
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text('Tải video lỗi: $e'),
                        ),
                      );
                    }
                  }
                } else {
                  final dataUrl =
                      'data:${_imageMimeType(file.extension)};base64,${base64Encode(bytes)}';
                  setDialogState(() {
                    pickedFiles.add({
                      'name': file.name,
                      'dataUrl': dataUrl,
                      'isVideo': false,
                    });
                  });
                }
              }
            } catch (_) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Không thể mở cửa sổ chọn file.'),
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

          final mq = MediaQuery.of(ctx);
          final isMobileDialog = mq.size.width < 600;
          // Available height after virtual keyboard inset (avoid hiding the
          // text field / action bar / submit button).
          final availableHeight =
              mq.size.height - mq.viewInsets.bottom - (isMobileDialog ? 16 : 48);
          final dialogMaxHeight = isMobileDialog
              ? availableHeight.clamp(320.0, mq.size.height)
              : 680.0;
          return Dialog(
            insetPadding: EdgeInsets.fromLTRB(
              isMobileDialog ? 4 : 40,
              isMobileDialog ? 8 : 24,
              isMobileDialog ? 4 : 40,
              isMobileDialog ? 8 : 24,
            ),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isMobileDialog ? 12 : 16)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight: dialogMaxHeight,
              ),
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
                          // Block submit while video upload is still in
                          // progress.
                          final stillUploading = pickedFiles.any((f) =>
                              f['isVideo'] == true && f['uploading'] == true);
                          if (stillUploading) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Vui lòng đợi video tải lên hoàn tất.'),
                              ),
                            );
                            return;
                          }
                          final imageDataUrls = pickedFiles
                              .where((f) =>
                                  f['isVideo'] != true &&
                                  f['dataUrl'] != null)
                              .map((f) => f['dataUrl'] as String)
                              .toList();
                          Map<String, dynamic>? video;
                          for (final f in pickedFiles) {
                            if (f['isVideo'] == true &&
                                (f['remoteUrl'] ?? '') != '') {
                              video = f;
                              break;
                            }
                          }
                          try {
                            await provider.createPost(
                              text,
                              authorName: userName,
                              authorId: currentUser?.id,
                              visibility: selectedVisibility,
                              storeCode: currentUser?.storeCode,
                              imageDataUrls: imageDataUrls,
                              videoUrl: video?['remoteUrl'] as String?,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('Đăng bài thất bại: $e'),
                                  backgroundColor: AppColors.error,
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
                              borderRadius: BorderRadius.circular(AppRadius.chip)),
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
            borderRadius: BorderRadius.circular(AppRadius.chip),
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
      final uploading = file['uploading'] == true;
      final progress = (file['progress'] as double?) ?? 0.0;
      return Container(
        width: double.infinity,
        height: height ?? 160,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.gradientDarkStart, AppColors.gradientDarkEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              uploading
                  ? Icons.cloud_upload_rounded
                  : Icons.play_circle_fill_rounded,
              size: 40,
              color: Colors.white,
            ),
            const SizedBox(height: 6),
            Text(
              file['name'] as String? ?? 'Video',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
            if (uploading) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  backgroundColor: Colors.white24,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Đang tải lên ${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
            ] else if ((file['remoteUrl'] ?? '') != '') ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_rounded,
                      size: 12, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Sẵn sàng',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
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

  void _openPostDetail(String postId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: postId),
      ),
    );
  }

  Future<void> _submitComment(
    BuildContext context,
    TrainingProvider provider,
    String postId,
    String userName,
    TextEditingController commentController,
    StateSetter setSheetState,
  ) async {
    final text = commentController.text.trim();
    if (text.isEmpty) return;
    commentController.clear();
    final ok = await provider.addCommentText(postId, text, authorName: userName);
    setSheetState(() {});
    if (!ok && context.mounted) {
      commentController.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể gửi bình luận. Vui lòng thử lại.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

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
                            onSubmitted: (val) => _submitComment(
                                context,
                                provider,
                                postId,
                                userName,
                                commentController,
                                setSheetState),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _submitComment(
                              context,
                              provider,
                              postId,
                              userName,
                              commentController,
                              setSheetState),
                          borderRadius: BorderRadius.circular(50),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
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
    final isPrivileged = role == 'ADM' || role == 'ADMIN' || role == 'TMK';
    return isOwnerById || isOwnerByName || isPrivileged;
  }

  void _showEditPostDialog(TrainingProvider provider, CommunityPost post) {
    final controller = TextEditingController(text: post.content ?? '');
    var visibility = post.visibility;

    showResponsiveForm(
      context: context,
      title: 'Sửa bài viết',
      contentBuilder: (ctx, setDialogState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
      actionsBuilder: (ctx, setDialogState) => [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () async {
            final text = controller.text.trim();
            if (text.isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('Nội dung bài viết không được để trống'),
                ),
              );
              return;
            }
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
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            }
          },
          child: const Text('Lưu'),
        ),
      ],
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
                      backgroundColor: AppColors.error,
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
    final Lesson l = lesson is Lesson
        ? lesson
        : Lesson(
            id: (lesson.id ?? '').toString(),
            title: (lesson.title ?? '').toString(),
            thumbnailUrl: (lesson.thumbnailUrl ?? '').toString(),
            targetRole: (lesson.targetRole ?? 'ALL').toString(),
          );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LessonDetailScreen(lesson: l)),
    ).then((_) {
      // Reload to refresh progress after returning.
      if (mounted) {
        context.read<TrainingProvider>().loadTrainingData();
      }
    });
  }

  Future<void> _confirmDeleteLesson(
      TrainingProvider provider, Lesson lesson) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá bài giảng?'),
        content: Text(
            'Bạn có chắc chắn muốn xoá "${lesson.title}"? Mọi phần và bài kiểm tra sẽ bị xoá.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await provider.deleteLesson(lesson.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xoá bài giảng')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xoá thất bại: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _openLessonHistory(Lesson lesson) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonHistoryScreen(lesson: lesson),
      ),
    );
  }

  void _showCreateLessonDialog(TrainingProvider provider) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final thumbCtrl = TextEditingController();
    String role = 'ALL';
    final List<_QuizDraft> drafts = [_QuizDraft()];
    String? errorMsg;
    bool busy = false;
    double uploadProgress = 0;
    Uint8List? videoBytes;
    String? videoFilename;
    final parentMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final mq = MediaQuery.of(ctx);
          final isMobileDialog = mq.size.width < 600;
          final availableHeight = mq.size.height -
              mq.viewInsets.bottom -
              (isMobileDialog ? 16 : 48);
          final dialogMaxHeight = isMobileDialog
              ? availableHeight.clamp(320.0, mq.size.height)
              : 720.0;
          return Dialog(
            insetPadding: EdgeInsets.fromLTRB(
              isMobileDialog ? 4 : 40,
              isMobileDialog ? 8 : 24,
              isMobileDialog ? 4 : 40,
              isMobileDialog ? 8 : 24,
            ),
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(isMobileDialog ? 12 : 16)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 600,
                maxHeight: dialogMaxHeight,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
                    child: Row(
                    children: [
                      const Expanded(
                        child: Text('Thêm bài giảng',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: titleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Tên bài giảng *',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: descCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Mô tả',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                            border: Border.all(
                                color: AppColors.border.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('File video *',
                                  style: AppTextStyles.bodyTextMedium),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: busy
                                        ? null
                                        : () async {
                                            try {
                                              final result = await FilePicker.pickFiles(
                                                type: FileType.video,
                                                allowMultiple: false,
                                                withData: true,
                                              );
                                              if (result == null || result.files.isEmpty) return;
                                              final file = result.files.first;
                                              const allowed = ['mp4', 'webm', 'mov', 'm4v'];
                                              if (!allowed.contains((file.extension ?? '').toLowerCase())) {
                                                setS(() => errorMsg = 'Định dạng không hỗ trợ. Chỉ nhận: mp4, webm, mov, m4v');
                                                return;
                                              }
                                              final bytes = file.bytes;
                                              if (bytes == null) {
                                                setS(() => errorMsg = 'Không đọc được dữ liệu file.');
                                                return;
                                              }
                                              setS(() {
                                                videoBytes = bytes;
                                                videoFilename = file.name;
                                                errorMsg = null;
                                              });
                                            } catch (e) {
                                              setS(() => errorMsg = 'Lỗi mở file: $e');
                                            }
                                          },
                                    icon: const Icon(
                                        Icons.upload_file_rounded,
                                        size: 18),
                                    label: const Text('Chọn file'),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      videoFilename == null
                                          ? 'Chưa chọn file (mp4/webm/mov)'
                                          : '$videoFilename (${(videoBytes!.length / 1024 / 1024).toStringAsFixed(1)} MB)',
                                      style: AppTextStyles.caption,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (busy && uploadProgress > 0 && uploadProgress < 1) ...[
                                const SizedBox(height: 8),
                                LinearProgressIndicator(value: uploadProgress),
                                const SizedBox(height: 4),
                                Text(
                                  'Đang upload: ${(uploadProgress * 100).toStringAsFixed(0)}%',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: thumbCtrl,
                          decoration: const InputDecoration(
                            labelText: 'URL ảnh thumbnail',
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: role,
                          decoration: const InputDecoration(
                            labelText: 'Đối tượng',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('Tất cả')),
                            DropdownMenuItem(value: 'PG', child: Text('PG')),
                            DropdownMenuItem(value: 'TLD', child: Text('TLD')),
                            DropdownMenuItem(value: 'ADM', child: Text('ADM')),
                          ],
                          onChanged: (v) => setS(() => role = v ?? 'ALL'),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text('Bài kiểm tra (${drafts.length} câu)',
                                style: AppTextStyles.sectionHeader),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => setS(() => drafts.add(_QuizDraft())),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Thêm câu hỏi'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        for (int i = 0; i < drafts.length; i++)
                          _buildQuizDraftEditor(i, drafts[i],
                              () => setS(() => drafts.removeAt(i).dispose())),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                if (errorMsg != null)
                  Container(
                    width: double.infinity,
                    color: AppColors.errorLight,
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      errorMsg!,
                      style: TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: busy
                          ? null
                          : () async {
                        if (titleCtrl.text.trim().isEmpty) {
                          setS(() => errorMsg = 'Vui lòng nhập tên bài giảng');
                          return;
                        }
                        if (videoBytes == null) {
                          setS(() => errorMsg = 'Vui lòng chọn file video');
                          return;
                        }
                        final qs = drafts
                            .where((d) => d.questionCtrl.text.trim().isNotEmpty)
                            .map((d) => {
                                  'question': d.questionCtrl.text.trim(),
                                  'options': d.optionCtrls
                                      .map((c) => c.text.trim())
                                      .toList(),
                                  'correctAnswer': d.correct,
                                  'points': 1,
                                  'type': 'TN',
                                })
                            .toList();
                        setS(() {
                          busy = true;
                          errorMsg = null;
                          uploadProgress = 0;
                        });
                        try {
                          final videoPath =
                              await ApiService().uploadLessonVideo(
                            bytes: videoBytes!,
                            filename: videoFilename ?? 'video.mp4',
                            onProgress: (sent, total) {
                              if (total > 0) {
                                setS(() => uploadProgress = sent / total);
                              }
                            },
                          );
                          await provider.createLesson({
                            'title': titleCtrl.text.trim(),
                            'description': descCtrl.text.trim(),
                            'thumbnailUrl': thumbCtrl.text.trim(),
                            'targetRole': role,
                            'parts': [
                              {
                                'title': 'Phần 1',
                                'description': '',
                                'videoPath': videoPath,
                                'questions': qs,
                              }
                            ],
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                          parentMessenger.showSnackBar(const SnackBar(
                              content: Text('Đã thêm bài giảng')));
                        } catch (e) {
                          setS(() {
                            busy = false;
                            errorMsg = e.toString().replaceFirst('Exception: ', '');
                          });
                        }
                      },
                      child: Text(busy
                          ? (uploadProgress > 0 && uploadProgress < 1
                              ? 'Upload ${(uploadProgress * 100).toStringAsFixed(0)}%'
                              : 'Đang lưu...')
                          : 'Lưu bài giảng'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        },
      ),
    ).then((_) {
      titleCtrl.dispose();
      descCtrl.dispose();
      thumbCtrl.dispose();
      for (final d in drafts) {
        d.dispose();
      }
    });
  }

  Widget _buildQuizDraftEditor(int index, _QuizDraft d, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Câu ${index + 1}', style: AppTextStyles.bodyTextMedium),
              const Spacer(),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
              ),
            ],
          ),
          TextField(
            controller: d.questionCtrl,
            decoration: const InputDecoration(labelText: 'Nội dung câu hỏi'),
          ),
          for (int i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextField(
                controller: d.optionCtrls[i],
                decoration: InputDecoration(
                  labelText: 'Đáp án ${["A", "B", "C", "D"][i]}',
                ),
              ),
            ),
          const SizedBox(height: 6),
          DropdownButton<String>(
            value: d.correct,
            isDense: true,
            items: const [
              DropdownMenuItem(value: 'A', child: Text('Đáp án đúng: A')),
              DropdownMenuItem(value: 'B', child: Text('Đáp án đúng: B')),
              DropdownMenuItem(value: 'C', child: Text('Đáp án đúng: C')),
              DropdownMenuItem(value: 'D', child: Text('Đáp án đúng: D')),
            ],
            onChanged: (v) {
              d.correct = v ?? 'A';
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  void _showAddEventDialog(TrainingProvider provider) {
    final controller = TextEditingController();
    final targetDay = _selectedDay ?? _focusedDay;

    showResponsiveForm(
      context: context,
      title: 'Thêm sự kiện',
      contentBuilder: (ctx, setDialogState) => TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Tên sự kiện...',
          border: OutlineInputBorder(),
        ),
      ),
      actionsBuilder: (ctx, setDialogState) => [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy')),
        ElevatedButton(
          onPressed: () {
            if (controller.text.trim().isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('Vui lòng nhập tên sự kiện'),
                ),
              );
              return;
            }
            provider.addEvent(targetDay, controller.text.trim());
            Navigator.pop(ctx);
          },
          child: const Text('Thêm'),
        ),
      ],
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
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final urlController = TextEditingController(text: 'https://');
    bool saving = false;

    showResponsiveForm(
      context: context,
      title: 'Thêm trợ lý AI mới',
      contentBuilder: (ctx, setDialogState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
            controller: urlController,
            decoration: const InputDecoration(
              labelText: 'Đường dẫn',
              border: OutlineInputBorder(),
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
                  final name = nameController.text.trim();
                  final url = urlController.text.trim();
                  final parsed = Uri.tryParse(url);

                  if (name.isEmpty ||
                      parsed == null ||
                      parsed.scheme.isEmpty ||
                      parsed.host.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng nhập đầy đủ và URL hợp lệ.'),
                      ),
                    );
                    return;
                  }

                  setDialogState(() => saving = true);
                  final ok = await context
                      .read<LmsProvider>()
                      .addAiTool(name: name, link: url);
                  if (!ctx.mounted) return;
                  if (ok) {
                    Navigator.pop(ctx);
                  } else {
                    setDialogState(() => saving = false);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Không thể thêm trợ lý AI. Vui lòng thử lại.'),
                      ),
                    );
                  }
                },
          child: Text(saving ? 'Đang lưu...' : 'Thêm'),
        ),
      ],
    );
  }
}

class _QuizDraft {
  final TextEditingController questionCtrl = TextEditingController();
  final List<TextEditingController> optionCtrls = List.generate(
    4,
    (_) => TextEditingController(),
  );
  String correct = 'A';

  void dispose() {
    questionCtrl.dispose();
    for (final c in optionCtrls) {
      c.dispose();
    }
  }
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
        color: AppColors.primary,
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