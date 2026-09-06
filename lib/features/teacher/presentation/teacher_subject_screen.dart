import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/l10n/ar_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/lesson.dart';
import '../../shared/providers/content_providers.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/status_banner.dart';
import '../widgets/lesson_form_sheet.dart';

/// إدارة دروس مادة: إضافة، تعديل، حذف، وإعادة ترتيب بالسحب.
class TeacherSubjectScreen extends ConsumerWidget {
  const TeacherSubjectScreen({required this.subjectId, super.key});

  final String subjectId;

  LessonsQuery get _query =>
      LessonsQuery(subjectId: subjectId, publishedOnly: false);

  void _refresh(WidgetRef ref) {
    ref
      ..invalidate(lessonsProvider(_query))
      ..invalidate(subjectsProvider);
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final result = await LessonFormSheet.show(context);
    if (result == null) return;

    await _run(context, ref, () async {
      await ref.read(teacherRepositoryProvider).createLesson(
            subjectId: subjectId,
            title: result.title,
            level: result.level,
            summary: result.summary,
          );
    });
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Lesson lesson,
  ) async {
    final result = await LessonFormSheet.show(context, lesson: lesson);
    if (result == null) return;

    await _run(context, ref, () async {
      await ref.read(teacherRepositoryProvider).updateLesson(
            id: lesson.id,
            title: result.title,
            level: result.level,
            summary: result.summary,
          );
    });
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Lesson lesson,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(S.delete),
        content: Text('سيُحذف الدرس «${lesson.title}» وكل فقراته نهائيًا.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(S.delete),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;

    await _run(context, ref, () async {
      await ref.read(teacherRepositoryProvider).deleteLesson(lesson.id);
    });
  }

  Future<void> _togglePublish(
    BuildContext context,
    WidgetRef ref,
    Lesson lesson,
  ) async {
    await _run(context, ref, () async {
      await ref.read(teacherRepositoryProvider).updateLesson(
            id: lesson.id,
            isPublished: !lesson.isPublished,
          );
    });
  }

  Future<void> _reorder(
    BuildContext context,
    WidgetRef ref,
    List<Lesson> lessons,
    int oldIndex,
    int newIndex,
  ) async {
    final reordered = [...lessons];
    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    reordered.insert(target, reordered.removeAt(oldIndex));

    await _run(context, ref, () async {
      await ref.read(teacherRepositoryProvider).reorderLessons(
            subjectId: subjectId,
            orderedIds: reordered.map((lesson) => lesson.id).toList(),
          );
    });
  }

  /// ينفّذ عملية على الخادم ويعرض رسالة الخطأ العربية عند الفشل.
  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      _refresh(ref);
    } on AppException catch (error) {
      _refresh(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = ref.watch(subjectProvider(subjectId)).valueOrNull;
    final lessons = ref.watch(lessonsProvider(_query));

    return Scaffold(
      appBar: AppBar(title: Text(subject?.title ?? S.lessons)),
      body: Column(
        children: [
          const StatusBanner(),
          Expanded(
            child: AsyncView(
              value: lessons,
              onRetry: () => ref.invalidate(lessonsProvider(_query)),
              isEmpty: (list) => list.isEmpty,
              emptyMessage: 'لم تُضِف أي درس لهذه المادة بعد.',
              builder: (list) => ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                onReorder: (oldIndex, newIndex) =>
                    _reorder(context, ref, list, oldIndex, newIndex),
                itemBuilder: (context, index) {
                  final lesson = list[index];
                  return Card(
                    key: ValueKey(lesson.id),
                    child: ListTile(
                      title: Text(lesson.title),
                      subtitle: Row(
                        children: [
                          _LevelChip(level: lesson.level),
                          const SizedBox(width: 8),
                          Text('${lesson.blocksCount} فقرة'),
                          if (!lesson.isPublished) ...[
                            const SizedBox(width: 8),
                            const Text('(مخفي)'),
                          ],
                        ],
                      ),
                      onTap: () =>
                          context.push(Routes.teacherLessonEditor(lesson.id)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PopupMenuButton<String>(
                            onSelected: (value) => switch (value) {
                              'edit' => _edit(context, ref, lesson),
                              'publish' => _togglePublish(context, ref, lesson),
                              'delete' => _delete(context, ref, lesson),
                              _ => null,
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text(S.edit),
                              ),
                              PopupMenuItem(
                                value: 'publish',
                                child: Text(
                                  lesson.isPublished ? S.unpublish : S.publish,
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text(S.delete),
                              ),
                            ],
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.drag_handle),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text(S.addLesson),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.level});

  final LessonLevel level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        level.label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
