import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/l10n/ar_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/lesson.dart';
import '../../../data/models/progress.dart';
import '../../shared/providers/content_providers.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/status_banner.dart';
import '../widgets/download_button.dart';
import 'level_picker.dart';

/// دروس مادة واحدة، مفلترة بالطور الذي اختاره التلميذ.
///
/// عند أول دخول للمادة (لا طور محفوظ) يُعرض منتقي الطور قبل القائمة.
class SubjectLessonsScreen extends ConsumerWidget {
  const SubjectLessonsScreen({required this.subjectId, super.key});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = ref.watch(subjectProvider(subjectId)).valueOrNull;
    final levelAsync = ref.watch(subjectLevelProvider(subjectId));

    return Scaffold(
      appBar: AppBar(
        title: Text(subject?.title ?? S.lessons),
        actions: [
          if (levelAsync.valueOrNull != null)
            TextButton.icon(
              onPressed: () async {
                await LevelPicker.show(
                  context,
                  subjectId: subjectId,
                  currentLevel: levelAsync.valueOrNull,
                );
              },
              icon: const Icon(Icons.tune, size: 18),
              label: Text(levelAsync.valueOrNull!.label),
            ),
        ],
      ),
      body: Column(
        children: [
          const StatusBanner(),
          Expanded(
            child: AsyncView(
              value: levelAsync,
              onRetry: () => ref.invalidate(subjectLevelProvider(subjectId)),
              builder: (level) {
                if (level == null) {
                  // لم يختر الطور بعد: المنتقي هو محتوى الشاشة.
                  return LevelPicker(subjectId: subjectId);
                }
                return _LessonsList(subjectId: subjectId, level: level);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonsList extends ConsumerWidget {
  const _LessonsList({required this.subjectId, required this.level});

  final String subjectId;
  final LessonLevel level;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = LessonsQuery(subjectId: subjectId, level: level);
    final lessons = ref.watch(lessonsProvider(query));
    final progress =
        ref.watch(subjectProgressProvider(subjectId)).valueOrNull ?? const {};

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(contentRepositoryProvider).getLessons(
              subjectId,
              level: level,
              forceRefresh: true,
            );
        ref
          ..invalidate(lessonsProvider(query))
          ..invalidate(subjectProgressProvider(subjectId));
      },
      child: AsyncView(
        value: lessons,
        onRetry: () => ref.invalidate(lessonsProvider(query)),
        isEmpty: (list) => list.isEmpty,
        emptyMessage: 'لا توجد دروس في طور ${level.label} بعد.',
        builder: (list) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, index) => _LessonTile(
            lesson: list[index],
            progress: progress[list[index].id],
          ),
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson, this.progress});

  final Lesson lesson;
  final LessonProgress? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = progress?.status ?? LessonStatus.notStarted;

    final (icon, color) = switch (status) {
      LessonStatus.completed => (
          Icons.check_circle,
          theme.colorScheme.primary,
        ),
      LessonStatus.inProgress => (
          Icons.play_circle_outline,
          theme.colorScheme.tertiary,
        ),
      LessonStatus.notStarted => (
          Icons.circle_outlined,
          theme.colorScheme.outline,
        ),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(lesson.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            Text(status.label, style: theme.textTheme.bodySmall),
            if (status == LessonStatus.inProgress && progress != null) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(value: progress!.ratio),
            ],
          ],
        ),
        trailing: DownloadButton(lessonId: lesson.id),
        onTap: () => context.push(Routes.lessonViewer(lesson.id)),
      ),
    );
  }
}
