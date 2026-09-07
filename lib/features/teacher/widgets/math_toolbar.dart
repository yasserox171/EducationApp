import 'package:flutter/material.dart';

import '../../../core/l10n/ar_strings.dart';
import '../../../core/utils/latex_parser.dart';

/// رمز جاهز للإدراج: التسمية المعروضة وصيغة LaTeX وموضع المؤشّر بعدها.
class MathSnippet {
  const MathSnippet({
    required this.label,
    required this.latex,
    this.cursorOffsetFromEnd = 0,
  });

  final String label;
  final String latex;

  /// كم خانة يرجع المؤشّر من نهاية النص المُدرج (ليقف داخل الأقواس).
  final int cursorOffsetFromEnd;

  static const List<MathSnippet> common = [
    MathSnippet(label: '√', latex: r'\sqrt{}', cursorOffsetFromEnd: 1),
    MathSnippet(label: 'كسر', latex: r'\frac{}{}', cursorOffsetFromEnd: 3),
    MathSnippet(label: 'أُسّ', latex: r'x^{}', cursorOffsetFromEnd: 1),
    MathSnippet(label: '∫', latex: r'\int_{}^{}', cursorOffsetFromEnd: 3),
    MathSnippet(label: 'مشتق', latex: r"f'(x)"),
    MathSnippet(label: 'نهاية', latex: r'\lim_{x \to 0}'),
    MathSnippet(label: '∑', latex: r'\sum_{i=1}^{n}', cursorOffsetFromEnd: 0),
    MathSnippet(label: 'π', latex: r'\pi'),
    MathSnippet(label: '≤', latex: r'\leq'),
    MathSnippet(label: '≠', latex: r'\neq'),
  ];
}

/// شريط أدوات فوق حقل النص: إدراج معادلة ورموز رياضية شائعة.
class MathToolbar extends StatelessWidget {
  const MathToolbar({required this.controller, super.key});

  final TextEditingController controller;

  /// يُدرج نصًا في موضع المؤشّر (أو يلفّ التحديد إن وُجد).
  void _insert(String snippet, {int cursorOffsetFromEnd = 0}) {
    final value = controller.value;
    final selection = value.selection;
    final text = value.text;

    // تحديد غير صالح (الحقل لم يُلمس بعد): نضيف في النهاية.
    if (!selection.isValid) {
      controller.value = TextEditingValue(
        text: text + snippet,
        selection: TextSelection.collapsed(
          offset: text.length + snippet.length - cursorOffsetFromEnd,
        ),
      );
      return;
    }

    final start = selection.start;
    final end = selection.end;
    final updated = text.replaceRange(start, end, snippet);

    controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(
        offset: start + snippet.length - cursorOffsetFromEnd,
      ),
    );
  }

  /// يلفّ التحديد بفواصل المعادلة، أو يُدرج فاصلين فارغين والمؤشّر بينهما.
  void _insertEquation() {
    final selection = controller.value.selection;
    final text = controller.value.text;

    if (selection.isValid && !selection.isCollapsed) {
      final selected = text.substring(selection.start, selection.end);
      _insert(wrapLatex(selected));
      return;
    }
    _insert(wrapLatex(''), cursorOffsetFromEnd: latexDelimiter.length);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _insertEquation,
              icon: const Icon(Icons.functions, size: 18),
              label: const Text(S.insertEquation),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                S.equationHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: MathSnippet.common.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final snippet = MathSnippet.common[index];
              return ActionChip(
                label: Text(snippet.label),
                onPressed: () => _insert(
                  snippet.latex,
                  cursorOffsetFromEnd: snippet.cursorOffsetFromEnd,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
