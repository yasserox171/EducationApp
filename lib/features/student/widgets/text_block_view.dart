import 'package:flutter/material.dart';

import '../../../data/models/lesson_block.dart';
import '../../shared/widgets/math_text.dart';

/// عرض فقرة نصية: عنوان اختياري + نص قد يتخلّله معادلات رياضية.
class TextBlockView extends StatelessWidget {
  const TextBlockView({required this.block, super.key});

  final TextBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (block.heading != null && block.heading!.trim().isNotEmpty) ...[
          MathText(
            block.heading!,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
        ],
        MathText(
          block.body,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.8),
        ),
      ],
    );
  }
}
