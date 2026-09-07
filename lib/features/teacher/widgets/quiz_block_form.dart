import 'package:flutter/material.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/l10n/ar_strings.dart';
import '../../../data/models/lesson_block.dart';

/// نتيجة نموذج الكويز: سؤال واحد أو أكثر داخل الفقرة نفسها.
class QuizBlockFormResult {
  const QuizBlockFormResult({required this.questions});

  final List<QuizQuestion> questions;
}

/// نموذج كويز QCM: عدة أسئلة، كل سؤال بعدة اختيارات وإجابة صحيحة واحدة.
class QuizBlockForm extends StatefulWidget {
  const QuizBlockForm({this.block, super.key});

  final QuizBlock? block;

  static Future<QuizBlockFormResult?> show(
    BuildContext context, {
    QuizBlock? block,
  }) =>
      showModalBottomSheet<QuizBlockFormResult>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: QuizBlockForm(block: block),
        ),
      );

  @override
  State<QuizBlockForm> createState() => _QuizBlockFormState();
}

class _QuizBlockFormState extends State<QuizBlockForm> {
  final _formKey = GlobalKey<FormState>();
  final List<_QuestionEntry> _questions = [];

  @override
  void initState() {
    super.initState();
    final existing = widget.block?.questions ?? const <QuizQuestion>[];
    if (existing.isEmpty) {
      _questions.add(_QuestionEntry.empty(_nextQuestionId()));
    } else {
      for (final question in existing) {
        _questions.add(_QuestionEntry.fromQuestion(question));
      }
    }
  }

  @override
  void dispose() {
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  /// معرّفات ثابتة (`q1`, `q2`…) لا تتصادم مع أسئلة محذوفة، حتى تبقى
  /// محاولات التلاميذ مرتبطة بأسئلتها بعد أي تعديل.
  String _nextQuestionId() {
    var max = 0;
    for (final entry in _questions) {
      final numeric = int.tryParse(entry.id.replaceAll(RegExp(r'\D'), ''));
      if (numeric != null && numeric > max) max = numeric;
    }
    return 'q${max + 1}';
  }

  void _addQuestion() {
    setState(() => _questions.add(_QuestionEntry.empty(_nextQuestionId())));
  }

  void _removeQuestion(int index) {
    if (_questions.length <= 1) return;
    setState(() => _questions.removeAt(index).dispose());
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    for (final entry in _questions) {
      if (entry.correctOptionId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدّد الإجابة الصحيحة لكل سؤال.')),
        );
        return;
      }
    }

    Navigator.of(context).pop(
      QuizBlockFormResult(
        questions:
            _questions.map((entry) => entry.toQuestion()).toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.block == null ? S.addQuizBlock : S.edit,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  S.quizFormHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (var i = 0; i < _questions.length; i++)
                          _QuestionCard(
                            key: ValueKey(_questions[i].id),
                            index: i,
                            entry: _questions[i],
                            canRemove: _questions.length > 1,
                            onRemove: () => _removeQuestion(i),
                            onChanged: () => setState(() {}),
                          ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            onPressed: _addQuestion,
                            icon: const Icon(Icons.add),
                            label: const Text(S.addQuestion),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: _submit, child: const Text(S.save)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.entry,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
    super.key,
  });

  final int index;
  final _QuestionEntry entry;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '${S.question} ${index + 1}',
                  style: theme.textTheme.labelLarge,
                ),
                const Spacer(),
                if (canRemove)
                  IconButton(
                    tooltip: S.delete,
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: entry.questionController,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(labelText: S.question),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'نص السؤال مطلوب.' : null,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${S.options} — اضغط الدائرة لتحديد الصحيحة',
                style: theme.textTheme.labelMedium,
              ),
            ),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: entry.correctOptionId,
              onChanged: (value) {
                entry.correctOptionId = value;
                onChanged();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < entry.options.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Radio<String>(value: entry.options[i].id),
                          Expanded(
                            child: TextFormField(
                              controller: entry.options[i].controller,
                              decoration: InputDecoration(
                                labelText: 'الخيار ${i + 1}',
                                isDense: true,
                              ),
                              validator: (value) => (value ?? '').trim().isEmpty
                                  ? 'لا يمكن ترك خيار فارغًا.'
                                  : null,
                            ),
                          ),
                          IconButton(
                            onPressed:
                                entry.options.length <= AppConstants.quizMinOptions
                                    ? null
                                    : () {
                                        entry.removeOption(i);
                                        onChanged();
                                      },
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (entry.options.length < AppConstants.quizMaxOptions)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () {
                    entry.addOption();
                    onChanged();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('إضافة خيار'),
                ),
              ),
            const SizedBox(height: 8),
            TextFormField(
              controller: entry.explanationController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: S.explanation,
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// حالة تحرير سؤال واحد.
class _QuestionEntry {
  _QuestionEntry({
    required this.id,
    required String question,
    required String explanation,
    required this.options,
    this.correctOptionId,
  })  : questionController = TextEditingController(text: question),
        explanationController = TextEditingController(text: explanation);

  factory _QuestionEntry.empty(String id) => _QuestionEntry(
        id: id,
        question: '',
        explanation: '',
        options: [_OptionEntry(id: 'o1'), _OptionEntry(id: 'o2')],
      );

  factory _QuestionEntry.fromQuestion(QuizQuestion question) => _QuestionEntry(
        id: question.id,
        question: question.question,
        explanation: question.explanation ?? '',
        options: question.options
            .map((option) => _OptionEntry(id: option.id, text: option.text))
            .toList(),
        correctOptionId: question.correctOptionId,
      );

  final String id;
  final TextEditingController questionController;
  final TextEditingController explanationController;
  final List<_OptionEntry> options;
  String? correctOptionId;

  void addOption() {
    if (options.length >= AppConstants.quizMaxOptions) return;
    var max = 0;
    for (final option in options) {
      final numeric = int.tryParse(option.id.replaceAll(RegExp(r'\D'), ''));
      if (numeric != null && numeric > max) max = numeric;
    }
    options.add(_OptionEntry(id: 'o${max + 1}'));
  }

  void removeOption(int index) {
    if (options.length <= AppConstants.quizMinOptions) return;
    final removed = options.removeAt(index);
    if (correctOptionId == removed.id) correctOptionId = null;
    removed.controller.dispose();
  }

  QuizQuestion toQuestion() {
    final explanation = explanationController.text.trim();
    return QuizQuestion(
      id: id,
      question: questionController.text.trim(),
      options: options
          .map(
            (option) => QuizOption(
              id: option.id,
              text: option.controller.text.trim(),
            ),
          )
          .toList(growable: false),
      correctOptionId: correctOptionId,
      explanation: explanation.isEmpty ? null : explanation,
    );
  }

  void dispose() {
    questionController.dispose();
    explanationController.dispose();
    for (final option in options) {
      option.controller.dispose();
    }
  }
}

class _OptionEntry {
  _OptionEntry({required this.id, String text = ''})
      : controller = TextEditingController(text: text);

  final String id;
  final TextEditingController controller;
}
