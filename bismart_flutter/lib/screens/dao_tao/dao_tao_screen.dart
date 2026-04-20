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

class _DaoTaoScreenState extends State<DaoTaoScreen> with SingleTickerProviderStateMixin {
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
    final isWide = MediaQuery.of(context).size.width > 800;

    if (isWide) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.daoTao, style: AppTextStyles.appTitle),
            const SizedBox(height: 4),
            Text('Cộng đồng, bài học & lịch đào tạo', style: AppTextStyles.caption),
            const SizedBox(height: 20),
            _buildAiBanner(),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildCommunityPanel()),
                const SizedBox(width: 16),
                Expanded(child: _buildLessonPanel()),
                const SizedBox(width: 16),
                Expanded(child: _buildSchedulePanel()),
              ],
            ),
          ],
        ),
      );
    }

    // Mobile: horizontal sub-tabs
    return Column(
      children: [
        Container(
          color: AppColors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textHint,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildAiBanner(),
                    const SizedBox(height: 16),
                    _buildCommunityPanel(),
                  ],
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildLessonPanel(),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildSchedulePanel(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAiBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          final url = Uri.parse('https://momcare.ai');
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        },
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: AppColors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✨ ${AppStrings.troPlyAI}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.momCareAI,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: AppColors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityPanel() {
    final provider = context.watch<TrainingProvider>();

    return DataPanel(
      title: '${AppStrings.congDong} 💬',
      trailing: ElevatedButton.icon(
        onPressed: () => _showCreatePostDialog(),
        icon: const Icon(Icons.edit_rounded, size: 16),
        label: const Text(AppStrings.vietBai),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      child: provider.isLoading
          ? const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppColors.primary),
            ))
          : Column(
              children: provider.posts.map((post) {
                return SocialPostCard(
                  post: post,
                  onLike: () => provider.toggleLike(post.id),
                  onComment: () => _showCommentDialog(post.id),
                );
              }).toList(),
            ),
    );
  }

  void _showCreatePostDialog() {
    final controller = TextEditingController();
    final userName = context.read<AuthProvider>().currentUser?.fullName ?? 'Bạn';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Viết bài mới'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Chia sẻ suy nghĩ của bạn...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.huy),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<TrainingProvider>().createPost(
                  controller.text,
                  authorName: userName,
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Đăng'),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonPanel() {
    final provider = context.watch<TrainingProvider>();

    return DataPanel(
      title: '${AppStrings.baiHoc} 📖',
      child: Column(
        children: provider.lessons.map((lesson) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LessonCard(
              lesson: lesson,
              onJoin: () => _showLessonDetail(lesson),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSchedulePanel() {
    final provider = context.watch<TrainingProvider>();
    final selectedEvents =
        _selectedDay != null ? provider.getEventsForDay(_selectedDay!) : <String>[];

    return DataPanel(
      title: '${AppStrings.lichHoc} 📅',
      trailing: TextButton(
        onPressed: () => _showAddEventDialog(),
        child: const Text('+ Thêm sự kiện'),
      ),
      child: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2027, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            eventLoader: (day) => provider.getEventsForDay(day),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              outsideDaysVisible: false,
            ),
            headerStyle: const HeaderStyle(
              formatButtonShowsNext: false,
              titleCentered: true,
            ),
          ),
          if (selectedEvents.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...selectedEvents.map((event) => Dismissible(
                  key: Key(event),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_rounded, color: AppColors.white, size: 20),
                  ),
                  onDismissed: (_) {
                    if (_selectedDay != null) {
                      context.read<TrainingProvider>().removeEvent(_selectedDay!, event);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(event,
                              style: AppTextStyles.bodyText.copyWith(fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  void _showCommentDialog(String postId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bình luận'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Viết bình luận...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.huy),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<TrainingProvider>().addComment(postId);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Đã bình luận thành công!'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
  }

  void _showLessonDetail(dynamic lesson) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lesson.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryLight, AppColors.surfaceVariant],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.play_circle_filled_rounded, size: 56, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Đối tượng: ${lesson.targetRole}',
                      style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Nội dung bài học sẽ được cập nhật từ hệ thống đào tạo.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Đã đăng ký tham gia bài học!'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Tham gia'),
          ),
        ],
      ),
    );
  }

  void _showAddEventDialog() {
    final controller = TextEditingController();
    DateTime eventDate = _selectedDay ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm sự kiện'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: eventDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2028),
                  );
                  if (picked != null) {
                    setDialogState(() => eventDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Ngày',
                    suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                  ),
                  child: Text('${eventDate.day.toString().padLeft(2, '0')}/${eventDate.month.toString().padLeft(2, '0')}/${eventDate.year}'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Tên sự kiện',
                  hintText: 'VD: Đào tạo PG mới',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(AppStrings.huy),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  this.context.read<TrainingProvider>().addEvent(eventDate, controller.text);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Đã thêm sự kiện "${controller.text}"'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
  }
}
