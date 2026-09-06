import 'package:flutter/material.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/l10n/ar_strings.dart';
import '../../../data/models/lesson_block.dart';

/// نتيجة نموذج الكويز.
class QuizBlockFormResult {
  const QuizBlockFormResult({
    required this.question,
    required this.options,
    required this.correctOptionId,
    this.explanation,
  });

  final String question;
  final List<QuizOption> options;
  final String correctOptionId;
  final String? explanation;
}

/// نموذج كويز QCM: سؤال + عدة اختيارات، إجابة واحدة صحيحة.
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
  late final TextEditingController _questionController;
  late final TextEditingController _explanationController;

  /// المعرّفات ثابتة داخل النموذج (`o1`, `o2`, …) ليبقى ربط الإجابة الصحيحة
  /// صحيحًا حتى بعد حذف خيار من الوسط.
  final List<_OptionEntry> _options = [];
  String? _correctOptionId;

  @override
  void initState() {
    super.initState();
    _questionController =
        TextEditingController(text: widget.block?.question ?? '');
    _explanationController =
        TextEditingController(text: widget.block?.explanation ?? '');

    final existing = widget.block?.options ?? const <QuizOption>[];
    if (existing.isEmpty) {
      _options
        ..add(_OptionEntry(id: 'o1'))
        ..add(_OptionEntry(id: 'o2'));
    } else {
      for (final option in existing) {
        _options.add(_OptionEntry(id: option.id, text: option.text));
      }
      _correctOptionId = widget.block?.correctOptionId;
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _explanationController.dispose();
    for (final option in _options) {
      option.controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_options.length >= AppConstants.quizMaxOptions) return;
    setState(() {
      // معرّف لا يتصادم مع أي خيار قائم أو محذوف.
      final maxId = _options
          .map((option) => int.tryParse(option.id.replaceAll('o', '')) ?? 0)
          .fold<int>(0, (a, b) => a > b ? a : b);
      _options.add(_OptionEntry(id: 'o${maxId + 1}'));
    });
  }

  void _removeOption(int index) {
    if (_options.length <= AppConstants.quizMinOptions) return;
    setState(() {
      final removed = _options.removeAt(index);
      if (_correctOptionId == removed.id) _correctOptionId = null;
      removed.controller.dispose();
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_correctOptionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدّد الإجابة الصحيحة.')),
      );
      return;
    }

    Navigator.of(context).pop(
      QuizBlockFormResult(
        question: _questionController.text.trim(),
        options: _options
            .map(
              (option) => QuizOption(
                id: option.id,
                text: option.controller.text.trim(),
              ),
            )
            .toList(growable: false),
        correctOptionId: _correctOptionId!,
        explanation: _explanationController.text.trim().isEmpty
            ? null
            : _explanationController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
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
                const SizedBox(height: 24),
                TextFormField(
                  controller: _questionController,
                  autofocus: true,
                  maxLines: 3,
                  minLines: 1,
                  decoration: const InputDecoration(labelText: S.question),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'نص السؤال مطلوب.' : null,
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '${S.options} — اضغط الدائرة لتحديد الصحيحة',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < _options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Radio<String>(
                          value: _options[i].id,
                          groupValue: _correctOptionId,
                          onChanged: (value) =>
                              setState(() => _correctOptionId = value),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: _options[i].controller,
                            decoration: InputDecoration(
                              labelText: 'الخيار ${i + 1}',
                            ),
                            validator: (value) => (value ?? '').trim().isEmpty
                                ? 'لا يمكن ترك خيار فارغًا.'
                                : null,
                          ),
                        ),
                        IconButton(
                          onPressed:
                              _options.length <= AppConstants.quizMinOptions
                                  ? null
                                  : () => _removeOption(i),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                  ),
                if (_options.length < AppConstants.quizMaxOptions)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: _addOption,
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة خيار'),
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _explanationController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: S.explanation),
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: _submit, child: const Text(S.save)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionEntry {
  _OptionEntry({required this.id, String text = ''})
      : controller = TextEditingController(text: text);

  final String id;
  final TextEditingController controller;
}
