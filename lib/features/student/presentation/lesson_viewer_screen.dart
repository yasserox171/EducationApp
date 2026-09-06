import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/l10n/ar_strings.dart';
import '../../../data/models/lesson.dart';
import '../../../data/models/lesson_block.dart';
import '../../../data/models/progress.dart';
import '../../shared/providers/content_providers.dart';
import '../../shared/widgets/async_view.dart';
import '../widgets/download_button.dart';
import '../widgets/quiz_block_view.dart';
import '../widgets/text_block_view.dart';
import '../widgets/video_block_view.dart';

/// عارض الدرس: الفقرات بالترتيب مع تنقّل تالي/سابق.
///
/// آخر موضع يُحفظ محليًا عند كل تنقّل (وعبر طابور الإرسال إلى الخادم)،
/// وعند إعادة فتح الدرس يبدأ من حيث توقّف التلميذ.
class LessonViewerScreen extends ConsumerWidget {
  const LessonViewerScreen({required this.lessonId, super.key});

  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesson = ref.watch(lessonProvider(lessonId)).valueOrNull;
    final blocks = ref.watch(lessonBlocksProvider(lessonId));
    final progress = ref.watch(lessonProgressProvider(lessonId));
    final attempts =
        ref.watch(lessonAttemptsProvider(lessonId)).valueOrNull ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: Text(lesson?.title ?? S.myLessons),
        actions: [DownloadButton(lessonId: lessonId)],
      ),
      body: Column(
        children: [
          DownloadStatusLine(lessonId: lessonId),
          Expanded(
            child: AsyncView(
              value: blocks,
              onRetry: () => ref.invalidate(lessonBlocksProvider(lessonId)),
              isEmpty: (list) => list.isEmpty,
              emptyMessage: 'هذا الدرس لا يحتوي فقرات بعد.',
              builder: (list) => _BlockPager(
                lesson: lesson,
                lessonId: lessonId,
                blocks: list,
                attempts: attempts,
                // نبدأ من آخر فقرة وصل إليها التلميذ.
                initialIndex: progress.valueOrNull?.lastBlockIndex ?? 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockPager extends ConsumerStatefulWidget {
  const _BlockPager({
    required this.lessonId,
    required this.blocks,
    required this.attempts,
    required this.initialIndex,
    this.lesson,
  });

  final String lessonId;
  final Lesson? lesson;
  final List<LessonBlock> blocks;
  final Map<String, QuizAttempt> attempts;
  final int initialIndex;

  @override
  ConsumerState<_BlockPager> createState() => _BlockPagerState();
}

class _BlockPagerState extends ConsumerState<_BlockPager> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.blocks.length - 1).toInt();
    _controller = PageController(initialPage: _index);
    // حفظ الموضع الابتدائي ينقل الدرس من «لم يبدأ» إلى «قيد التقدم».
    WidgetsBinding.instance.addPostFrameCallback((_) => _savePosition(_index));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _savePosition(int index) async {
    final subjectId = widget.lesson?.subjectId;
    if (subjectId == null) return;

    await ref.read(progressRepositoryProvider).savePosition(
          lessonId: widget.lessonId,
          subjectId: subjectId,
          blockIndex: index,
          blocksTotal: widget.blocks.length,
        );
    if (!mounted) return;
    ref
      ..invalidate(lessonProgressProvider(widget.lessonId))
      ..invalidate(subjectProgressProvider(subjectId));
    // المزامنة تحاول الإرسال فورًا إن كان هناك اتصال.
    unawaited(ref.read(syncServiceProvider).pushPending());
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.blocks.length) return;
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    final subjectId = widget.lesson?.subjectId;
    if (subjectId != null) {
      await ref.read(progressRepositoryProvider).markCompleted(
            lessonId: widget.lessonId,
            subjectId: subjectId,
            blocksTotal: widget.blocks.length,
          );
      if (!mounted) return;
      ref
        ..invalidate(lessonProgressProvider(widget.lessonId))
        ..invalidate(subjectProgressProvider(subjectId))
        ..invalidate(progressSummariesProvider);
      unawaited(ref.read(syncServiceProvider).pushPending());
    }
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == widget.blocks.length - 1;

    return Column(
      children: [
        // شريط تقدم داخل الدرس: الفقرة الحالية من المجموع.
        LinearProgressIndicator(
          value: (_index + 1) / widget.blocks.length,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الفقرة ${_index + 1} من ${widget.blocks.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                widget.blocks[_index].type.label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.blocks.length,
            onPageChanged: (index) {
              setState(() => _index = index);
              _savePosition(index);
            },
            itemBuilder: (context, index) => SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppConstants.maxContentWidth,
                  ),
                  child: _BlockContent(
                    block: widget.blocks[index],
                    attempts: widget.attempts,
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _index == 0 ? null : () => _goTo(_index - 1),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text(S.previous),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: isLast
                      ? FilledButton.icon(
                          onPressed: _finish,
                          icon: const Icon(Icons.check),
                          label: const Text(S.finishLesson),
                        )
                      : FilledButton.icon(
                          onPressed: () => _goTo(_index + 1),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text(S.next),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// يوجّه كل نوع فقرة إلى الودجة المناسبة.
/// `switch` على `sealed class` يضمن أن أي نوع جديد لن يمرّ دون معالجة.
class _BlockContent extends StatelessWidget {
  const _BlockContent({required this.block, required this.attempts});

  final LessonBlock block;
  final Map<String, QuizAttempt> attempts;

  @override
  Widget build(BuildContext context) => switch (block) {
        TextBlock() => TextBlockView(block: block),
        VideoBlock() => VideoBlockView(block: block),
        QuizBlock() => QuizBlockView(
            block: block,
            previousAttempt: attempts[block.id],
          ),
      };
}
