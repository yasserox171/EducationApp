import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/l10n/ar_strings.dart';
import '../../../data/models/lesson_block.dart';
import '../../../data/models/progress.dart';
import '../../shared/providers/content_providers.dart';

/// عرض فقرة كويز: سؤال تلو الآخر **بلا أي تقييم فوري**، ثم بطاقة نتيجة
/// واحدة بعد إجابة كل الأسئلة.
///
/// كل إجابة تُخزَّن محليًا فور اختيارها وتُرسل للخادم عبر طابور الإرسال،
/// فإن خرج التلميذ قبل الإكمال يستأنف من أول سؤال لم يُجب عنه، ولا يرى
/// أي نتيجة قبل إتمام الفقرة كاملة.
class QuizBlockView extends ConsumerStatefulWidget {
  const QuizBlockView({
    required this.block,
    this.previousAttempts = const {},
    super.key,
  });

  final QuizBlock block;

  /// آخر إجابة لكل سؤال في هذه الفقرة، مفهرسة بمعرّف السؤال.
  final Map<String, QuizAttempt> previousAttempts;

  @override
  ConsumerState<QuizBlockView> createState() => _QuizBlockViewState();
}

class _QuizBlockViewState extends ConsumerState<QuizBlockView> {
  /// الإجابات المختارة في هذه الجولة (معرّف السؤال → معرّف الخيار).
  final Map<String, String> _answers = {};

  int _index = 0;
  bool _isSubmitting = false;

  /// تصبح `true` عند الضغط على «إعادة الكويز»: نتجاهل الإجابات المحفوظة
  /// ونبدأ جولة جديدة دون حذف المحاولات السابقة من قاعدة البيانات.
  bool _restarted = false;

  @override
  void initState() {
    super.initState();
    _restoreProgress();
  }

  @override
  void didUpdateWidget(QuizBlockView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.id != widget.block.id) {
      _answers.clear();
      _index = 0;
      _restarted = false;
      _restoreProgress();
    }
  }

  /// يستعيد الإجابات السابقة ويضع المؤشّر على أول سؤال لم يُجب عنه.
  void _restoreProgress() {
    for (final question in widget.block.questions) {
      final attempt = widget.previousAttempts[question.id];
      if (attempt != null) _answers[question.id] = attempt.selectedOptionId;
    }
    _index = _firstUnansweredIndex();
  }

  int _firstUnansweredIndex() {
    for (var i = 0; i < widget.block.questions.length; i++) {
      if (!_answers.containsKey(widget.block.questions[i].id)) return i;
    }
    return widget.block.questions.length - 1;
  }

  bool get _isComplete =>
      widget.block.questions.every((q) => _answers.containsKey(q.id));

  Future<void> _select(QuizQuestion question, String optionId) async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _answers[question.id] = optionId;
    });

    await ref.read(progressRepositoryProvider).answerQuiz(
          block: widget.block,
          question: question,
          selectedOptionId: optionId,
        );

    if (!mounted) return;
    ref.invalidate(lessonAttemptsProvider(widget.block.lessonId));

    // انتقال عادي للسؤال التالي: لا صح ولا خطأ في هذه المرحلة.
    final isLast = _index >= widget.block.questions.length - 1;
    setState(() {
      _isSubmitting = false;
      if (!isLast) _index += 1;
    });
  }

  void _restart() {
    setState(() {
      _answers.clear();
      _index = 0;
      _restarted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questions = widget.block.questions;

    if (questions.isEmpty) {
      return Text(
        'هذه الفقرة لا تحتوي أسئلة.',
        style: theme.textTheme.bodyMedium,
      );
    }

    // النتيجة تظهر فقط بعد إجابة كل الأسئلة.
    if (_isComplete) {
      return _QuizResultCard(
        block: widget.block,
        answers: Map.unmodifiable(_answers),
        onRestart: _restart,
      );
    }

    final question = questions[_index];
    final answeredCount = _answers.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.quiz_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(S.quiz, style: theme.textTheme.labelLarge),
            const Spacer(),
            if (questions.length > 1)
              Text(
                'السؤال ${_index + 1} من ${questions.length}',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        if (questions.length > 1) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: answeredCount / questions.length,
              minHeight: 4,
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          question.question,
          style: theme.textTheme.titleLarge?.copyWith(height: 1.6),
        ),
        const SizedBox(height: 24),
        for (final option in question.options) ...[
          _OptionTile(
            text: option.text,
            isSelected: _answers[question.id] == option.id,
            onTap: _isSubmitting ? null : () => _select(question, option.id),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            if (_index > 0)
              TextButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () => setState(() => _index -= 1),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text(S.previousQuestion),
              ),
            const Spacer(),
            if (_answers.containsKey(question.id) &&
                _index < questions.length - 1)
              TextButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () => setState(() => _index += 1),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text(S.nextQuestion),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _restarted ? S.quizRestarted : S.quizNoFeedbackHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// بطاقة النتيجة: العدد الصحيح من المجموع، ثم تفصيل كل سؤال.
class _QuizResultCard extends StatelessWidget {
  const _QuizResultCard({
    required this.block,
    required this.answers,
    required this.onRestart,
  });

  final QuizBlock block;
  final Map<String, String> answers;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questions = block.questions;
    final correctCount = questions
        .where((q) => q.isCorrect(answers[q.id] ?? ''))
        .length;
    final ratio = questions.isEmpty ? 0.0 : correctCount / questions.length;
    final tone = ratio >= 0.5 ? Colors.green : theme.colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.08),
            border: Border.all(color: tone),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(S.quizResult, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Text(
                '$correctCount / ${questions.length}',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: tone,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'إجابات صحيحة من ${questions.length}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(S.quizReview, style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        for (var i = 0; i < questions.length; i++) ...[
          _QuestionReview(
            index: i,
            question: questions[i],
            selectedOptionId: answers[questions[i].id],
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        Center(
          child: OutlinedButton.icon(
            onPressed: onRestart,
            icon: const Icon(Icons.refresh),
            label: const Text(S.quizRestart),
          ),
        ),
      ],
    );
  }
}

class _QuestionReview extends StatelessWidget {
  const _QuestionReview({
    required this.index,
    required this.question,
    required this.selectedOptionId,
  });

  final int index;
  final QuizQuestion question;
  final String? selectedOptionId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrect = question.isCorrect(selectedOptionId ?? '');
    final tone = isCorrect ? Colors.green : theme.colorScheme.error;

    String selectedText = '—';
    for (final option in question.options) {
      if (option.id == selectedOptionId) selectedText = option.text;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: tone,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${index + 1}. ${question.question}',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ReviewRow(label: S.yourAnswer, value: selectedText, color: tone),
          if (!isCorrect && question.correctOptionText != null) ...[
            const SizedBox(height: 6),
            _ReviewRow(
              label: S.correctAnswer,
              value: question.correctOptionText!,
              color: Colors.green,
            ),
          ],
          if (question.explanation != null &&
              question.explanation!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              question.explanation!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// خيار أثناء الإجابة: يُبرز الاختيار فقط، دون أي دلالة على صحّته.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  final String text;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: borderColor,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
          ],
        ),
      ),
    );
  }
}
