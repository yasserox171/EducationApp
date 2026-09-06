import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/l10n/ar_strings.dart';
import '../../../data/models/lesson_block.dart';
import '../../../data/models/progress.dart';
import '../../shared/providers/content_providers.dart';

/// عرض فقرة كويز مع تصحيح فوري.
///
/// التصحيح محلي بالكامل (`block.isCorrect`) فيعمل بدون إنترنت، والمحاولة
/// تُخزَّن محليًا وتُرسل للخادم لاحقًا عبر طابور الإرسال.
class QuizBlockView extends ConsumerStatefulWidget {
  const QuizBlockView({required this.block, this.previousAttempt, super.key});

  final QuizBlock block;
  final QuizAttempt? previousAttempt;

  @override
  ConsumerState<QuizBlockView> createState() => _QuizBlockViewState();
}

class _QuizBlockViewState extends ConsumerState<QuizBlockView> {
  String? _selectedOptionId;
  bool? _isCorrect;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // عند العودة لفقرة سبق الإجابة عنها نعرض النتيجة السابقة.
    final previous = widget.previousAttempt;
    if (previous != null) {
      _selectedOptionId = previous.selectedOptionId;
      _isCorrect = previous.isCorrect;
    }
  }

  Future<void> _answer(String optionId) async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _selectedOptionId = optionId;
    });

    final attempt = await ref.read(progressRepositoryProvider).answerQuiz(
          block: widget.block,
          selectedOptionId: optionId,
        );

    if (!mounted) return;
    setState(() {
      _isCorrect = attempt.isCorrect;
      _isSubmitting = false;
    });
    ref.invalidate(lessonAttemptsProvider(widget.block.lessonId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final answered = _isCorrect != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.quiz_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('كويز', style: theme.textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          widget.block.question,
          style: theme.textTheme.titleLarge?.copyWith(height: 1.6),
        ),
        const SizedBox(height: 24),
        for (final option in widget.block.options) ...[
          _OptionTile(
            text: option.text,
            isSelected: _selectedOptionId == option.id,
            // بعد الإجابة نُبرز الخيار الصحيح حتى لو اختار التلميذ غيره.
            isCorrectAnswer: answered && widget.block.isCorrect(option.id),
            isWrongChoice:
                answered && _selectedOptionId == option.id && _isCorrect == false,
            onTap: _isSubmitting ? null : () => _answer(option.id),
          ),
          const SizedBox(height: 12),
        ],
        if (answered) ...[
          const SizedBox(height: 8),
          _FeedbackCard(
            isCorrect: _isCorrect!,
            explanation: widget.block.explanation,
          ),
        ],
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.text,
    required this.isSelected,
    required this.isCorrectAnswer,
    required this.isWrongChoice,
    required this.onTap,
  });

  final String text;
  final bool isSelected;
  final bool isCorrectAnswer;
  final bool isWrongChoice;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (borderColor, background, icon) = switch ((
      isCorrectAnswer,
      isWrongChoice,
      isSelected,
    )) {
      (true, _, _) => (
          Colors.green,
          Colors.green.withValues(alpha: 0.08),
          Icons.check_circle,
        ),
      (_, true, _) => (
          theme.colorScheme.error,
          theme.colorScheme.errorContainer,
          Icons.cancel,
        ),
      (_, _, true) => (
          theme.colorScheme.primary,
          theme.colorScheme.primaryContainer,
          Icons.radio_button_checked,
        ),
      _ => (
          theme.colorScheme.outlineVariant,
          Colors.transparent,
          Icons.radio_button_unchecked,
        ),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: borderColor, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
          ],
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.isCorrect, this.explanation});

  final bool isCorrect;
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isCorrect ? Colors.green : theme.colorScheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCorrect ? S.correctAnswerFeedback : S.wrongAnswerFeedback,
            style: theme.textTheme.titleMedium?.copyWith(color: color),
          ),
          if (explanation != null && explanation!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(explanation!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
