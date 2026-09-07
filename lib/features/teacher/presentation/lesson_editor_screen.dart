import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/l10n/ar_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/lesson_block.dart';
import '../../../data/repositories/teacher_repository.dart';
import '../../shared/providers/content_providers.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/status_banner.dart';
import '../providers/teacher_providers.dart';
import '../widgets/attachments_sheet.dart';
import '../widgets/quiz_block_form.dart';
import '../widgets/text_block_form.dart';
import '../widgets/video_upload_sheet.dart';

/// محرّر الدرس: إضافة فقرات بالترتيب (نص / فيديو / كويز)، تعديلها، حذفها،
/// وإعادة ترتيبها بالسحب.
class LessonEditorScreen extends ConsumerWidget {
  const LessonEditorScreen({required this.lessonId, super.key});

  final String lessonId;

  void _refresh(WidgetRef ref) {
    ref
      ..invalidate(teacherBlocksProvider(lessonId))
      ..invalidate(lessonBlocksProvider(lessonId));
  }

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

  Future<void> _addText(BuildContext context, WidgetRef ref) async {
    final result = await TextBlockForm.show(context);
    if (result == null || !context.mounted) return;
    await _run(context, ref, () async {
      await ref.read(teacherRepositoryProvider).addTextBlock(
            lessonId: lessonId,
            heading: result.heading,
            body: result.body,
          );
    });
  }

  Future<void> _addVideo(BuildContext context, WidgetRef ref) async {
    final added = await VideoUploadSheet.show(context, lessonId: lessonId);
    if (added ?? false) _refresh(ref);
  }

  Future<void> _addQuiz(BuildContext context, WidgetRef ref) async {
    final result = await QuizBlockForm.show(context);
    if (result == null || !context.mounted) return;
    await _run(context, ref, () async {
      await ref.read(teacherRepositoryProvider).addQuizBlock(
            lessonId: lessonId,
            questions: result.questions,
          );
    });
  }

  Future<void> _editBlock(
    BuildContext context,
    WidgetRef ref,
    LessonBlock block,
  ) async {
    switch (block) {
      case TextBlock():
        final result = await TextBlockForm.show(context, block: block);
        if (result == null || !context.mounted) return;
        await _run(context, ref, () async {
          await ref.read(teacherRepositoryProvider).updateBlock(
            blockId: block.id,
            data: {'heading': result.heading, 'body': result.body},
          );
        });

      case QuizBlock():
        final result = await QuizBlockForm.show(context, block: block);
        if (result == null || !context.mounted) return;
        await _run(context, ref, () async {
          await ref.read(teacherRepositoryProvider).updateBlock(
                blockId: block.id,
                data: TeacherRepository.quizDataOf(result.questions),
              );
        });

      case VideoBlock():
        // الفيديو نفسه لا يُستبدل (احذف الفقرة وأضف غيرها)، لكن مرفقاته
        // تُدار من هنا.
        if (!context.mounted) return;
        final changed = await AttachmentsSheet.show(context, block: block);
        if (changed ?? false) _refresh(ref);
    }
  }

  Future<void> _deleteBlock(
    BuildContext context,
    WidgetRef ref,
    LessonBlock block,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(S.delete),
        content: Text('حذف فقرة «${block.type.label}» نهائيًا؟'),
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
    if (!(confirmed ?? false) || !context.mounted) return;

    await _run(context, ref, () async {
      await ref.read(teacherRepositoryProvider).deleteBlock(block.id);
    });
  }

  Future<void> _reorder(
    BuildContext context,
    WidgetRef ref,
    List<LessonBlock> blocks,
    int oldIndex,
    int newIndex,
  ) async {
    // `onReorderItem` يسلّمنا `newIndex` مضبوطًا مسبقًا بعد حذف العنصر.
    final reordered = [...blocks];
    reordered.insert(newIndex, reordered.removeAt(oldIndex));

    await _run(context, ref, () async {
      await ref.read(teacherRepositoryProvider).reorderBlocks(
            lessonId: lessonId,
            orderedIds: reordered.map((block) => block.id).toList(),
          );
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesson = ref.watch(lessonProvider(lessonId)).valueOrNull;
    final blocks = ref.watch(teacherBlocksProvider(lessonId));

    return Scaffold(
      appBar: AppBar(title: Text(lesson?.title ?? S.lessonEditor)),
      body: Column(
        children: [
          const StatusBanner(),
          Expanded(
            child: AsyncView(
              value: blocks,
              onRetry: () => ref.invalidate(teacherBlocksProvider(lessonId)),
              isEmpty: (list) => list.isEmpty,
              emptyMessage: 'لا فقرات بعد — أضف أول فقرة من الأسفل.',
              builder: (list) => ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: list.length,
                onReorderItem: (oldIndex, newIndex) =>
                    _reorder(context, ref, list, oldIndex, newIndex),
                itemBuilder: (context, index) => _BlockCard(
                  key: ValueKey(list[index].id),
                  index: index,
                  block: list[index],
                  onEdit: () => _editBlock(context, ref, list[index]),
                  onDelete: () => _deleteBlock(context, ref, list[index]),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AddBlockButton(
                icon: Icons.text_fields,
                label: S.addTextBlock,
                onPressed: () => _addText(context, ref),
              ),
              _AddBlockButton(
                icon: Icons.videocam_outlined,
                label: S.addVideoBlock,
                onPressed: () => _addVideo(context, ref),
              ),
              _AddBlockButton(
                icon: Icons.quiz_outlined,
                label: S.addQuizBlock,
                onPressed: () => _addQuiz(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({
    required this.index,
    required this.block,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final int index;
  final LessonBlock block;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (icon, subtitle) = switch (block) {
      TextBlock(:final heading, :final body) => (
          Icons.text_fields,
          heading?.trim().isNotEmpty ?? false ? heading! : _preview(body),
        ),
      VideoBlock(:final title, :final durationSeconds, :final sizeBytes) => (
          Icons.videocam_outlined,
          [
            if (title?.trim().isNotEmpty ?? false) title!,
            if (durationSeconds > 0) Formatters.duration(durationSeconds),
            if (sizeBytes > 0) Formatters.bytes(sizeBytes),
          ].join(' — '),
        ),
      QuizBlock(:final questions) => (
          Icons.quiz_outlined,
          questions.isEmpty
              ? 'بلا أسئلة'
              : '${_preview(questions.first.question)}'
                  '${questions.length > 1 ? ' (+${questions.length - 1} أسئلة)' : ''}',
        ),
    };

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: Icon(icon, size: 20),
        ),
        title: Text('${index + 1}. ${block.type.label}'),
        subtitle: Text(
          subtitle.isEmpty ? '—' : subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: S.edit,
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: S.delete,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle),
            ),
          ],
        ),
      ),
    );
  }

  static String _preview(String text) {
    final clean = text.trim().replaceAll('\n', ' ');
    return clean.length <= 60 ? clean : '${clean.substring(0, 60)}…';
  }
}

class _AddBlockButton extends StatelessWidget {
  const _AddBlockButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20),
                const SizedBox(height: 4),
                Text(
                  label.replaceAll('إضافة ', ''),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
}
