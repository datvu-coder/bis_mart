import 'package:flutter/material.dart';
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

class DaoTaoScreen extends StatefulWidget {
  const DaoTaoScreen({super.key});

  @override
  State<DaoTaoScreen> createState() => _DaoTaoScreenState();
}

class _DaoTaoScreenState extends State<DaoTaoScreen>
    with SingleTickerProviderStateMixin {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1280;
    final isTablet = screenWidth >= 900 && screenWidth < 1280;
    final isWide = isDesktop || isTablet;

    return Consumer<TrainingProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.posts.isEmpty && provider.lessons.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (isWide) {
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 24,
              vertical: isDesktop ? 24 : 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScreenHeader(provider, isDesktop),
                    const SizedBox(height: 20),
                    _buildAiBanner(),
                    const SizedBox(height: 20),
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildCommunityPanel(provider)),
                          const SizedBox(width: 18),
                          Expanded(child: _buildLessonPanel(provider)),
                          const SizedBox(width: 18),
                          Expanded(child: _buildSchedulePanel(provider)),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildCommunityPanel(provider)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildLessonPanel(provider)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildSchedulePanel(provider),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        }

        // Mobile: pill-style tabs
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: _buildScreenHeader(provider, false),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      children: [
                        _buildAiBanner(),
                        const SizedBox(height: 12),
                        _buildCommunityPanel(provider),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: _buildLessonPanel(provider),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: _buildSchedulePanel(provider),
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

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(emphasize ? 20 : 16),
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
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.infoLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school_rounded, color: AppColors.info),
              ),
              const SizedBox(width: 12),
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
          const SizedBox(height: 14),
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
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

  // ── AI Banner ─────────────────────────────────────────────────────────────

  Widget _buildAiBanner() {
    return GestureDetector(
      onTap: () async {
        final url = Uri.parse('https://momcare.ai');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Trợ lý Momcare',
                      style: AppTextStyles.sectionHeader
                          .copyWith(color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('Khám phá AI hỗ trợ chăm sóc mẹ & bé',
                      style:
                          AppTextStyles.caption.copyWith(color: Colors.white70)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  // ── Panels ────────────────────────────────────────────────────────────────

  Widget _buildCommunityPanel(TrainingProvider provider) {
    return DataPanel(
      title: 'Cộng đồng',
      trailing: TextButton.icon(
        onPressed: () => _showCreatePostDialog(provider),
        icon: const Icon(Icons.edit_rounded, size: 16),
        label: const Text('Viết bài'),
      ),
      child: provider.posts.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.forum_rounded,
                        size: 40, color: AppColors.textHint),
                    const SizedBox(height: 8),
                    Text('Chưa có bài viết', style: AppTextStyles.caption),
                  ],
                ),
              ),
            )
          : Column(
              children: provider.posts
                  .map<Widget>((post) => SocialPostCard(
                        post: post,
                        onLike: () => provider.toggleLike(post.id),
                        onComment: () => _showCommentDialog(post.id, provider),
                      ))
                  .toList(),
            ),
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

  void _showCreatePostDialog(TrainingProvider provider) {
    final controller = TextEditingController();
    final authProvider = context.read<AuthProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Viết bài'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Chia sẻ điều gì đó với cộng đồng...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              await provider.createPost(controller.text.trim(),
                  authorName: authProvider.currentUser?.fullName);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Đăng'),
          ),
        ],
      ),
    );
  }

  void _showCommentDialog(String postId, TrainingProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bình luận'),
        content: const Text('Tính năng đang phát triển.'),
        actions: [
          TextButton(
            onPressed: () {
              provider.addComment(postId);
              Navigator.pop(ctx);
            },
            child: const Text('Thích'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
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
}
