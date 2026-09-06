import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/ar_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/teacher_stats.dart';
import '../../shared/widgets/async_view.dart';
import '../providers/teacher_providers.dart';

/// إحصائيات بسيطة: عدد التلاميذ، نسبة إكمال كل درس، متوسط نتائج الكويزات.
class TeacherStatsScreen extends ConsumerWidget {
  const TeacherStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(teacherStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(S.stats)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(teacherStatsProvider),
        child: AsyncView(
          value: stats,
          onRetry: () => ref.invalidate(teacherStatsProvider),
          builder: (data) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.people_outline,
                      label: S.studentsCount,
                      value: '${data.studentsCount}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.menu_book_outlined,
                      label: S.lessons,
                      value: '${data.lessonsCount}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _StatCard(
                icon: Icons.quiz_outlined,
                label: S.averageQuizScore,
                value: data.averageQuizScore == null
                    ? '—'
                    : Formatters.percent(data.averageQuizScore!),
              ),
              const SizedBox(height: 24),
              Text(
                S.completionRate,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (data.lessons.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('لا توجد بيانات دروس بعد.'),
                )
              else
                for (final lesson in data.lessons)
                  _LessonStatsCard(stats: lesson),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonStatsCard extends StatelessWidget {
  const _LessonStatsCard({required this.stats});

  final LessonStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stats.lessonTitle, style: theme.textTheme.titleSmall),
            Text(
              stats.subjectTitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: stats.completionRate,
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(Formatters.percent(stats.completionRate)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              children: [
                Text(
                  'بدأوا: ${stats.studentsStarted}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  'أكملوا: ${stats.studentsCompleted}',
                  style: theme.textTheme.bodySmall,
                ),
                if (stats.averageQuizScore != null)
                  Text(
                    '${S.averageQuizScore}: '
                    '${Formatters.percent(stats.averageQuizScore!)}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
