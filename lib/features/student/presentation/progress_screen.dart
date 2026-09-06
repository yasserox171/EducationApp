import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/ar_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/progress.dart';
import '../../shared/providers/content_providers.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/status_banner.dart';

/// صفحة «تقدّمي»: ملخّص لكل مادة — كم درسًا أكمل التلميذ من المجموع.
///
/// كل الأرقام تُحسب من قاعدة البيانات المحلية، فتعمل الصفحة بلا إنترنت.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(progressSummariesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(S.myProgress)),
      body: Column(
        children: [
          const StatusBanner(),
          Expanded(
            child: AsyncView(
              value: summaries,
              onRetry: () => ref.invalidate(progressSummariesProvider),
              isEmpty: (list) => list.isEmpty,
              emptyMessage: 'لا توجد مواد لعرض تقدّمك فيها بعد.',
              builder: (list) {
                final totalLessons = list.fold<int>(
                  0,
                  (sum, item) => sum + item.totalLessons,
                );
                final totalCompleted = list.fold<int>(
                  0,
                  (sum, item) => sum + item.completedLessons,
                );

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _OverallCard(
                      completed: totalCompleted,
                      total: totalLessons,
                    ),
                    const SizedBox(height: 8),
                    for (final summary in list)
                      _SubjectProgressCard(summary: summary),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = total == 0 ? 0.0 : completed / total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الإجمالي', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  Formatters.percent(ratio),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '$completed ${S.lessonsCompleted} من $total',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: ratio, minHeight: 8),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectProgressCard extends StatelessWidget {
  const _SubjectProgressCard({required this.summary});

  final SubjectProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    summary.subjectTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${summary.completedLessons} / ${summary.totalLessons}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: summary.ratio,
                minHeight: 6,
              ),
            ),
            if (summary.inProgressLessons > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${summary.inProgressLessons} ${LessonStatusLabel.inProgress}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// تسميات مختصرة تُستعمل في هذه الصفحة فقط.
class LessonStatusLabel {
  const LessonStatusLabel._();

  static const String inProgress = 'درسًا قيد التقدم';
}
