import 'package:flutter/material.dart';

import '../../core/l10n/ar_strings.dart';

/// شاشة مؤقّتة للمسارات التي لم تُبنَ بعد.
///
/// كل شاشة من هذه ستُستبدل بشاشتها الحقيقية في المرحلة التالية
/// (بعد تأكيد الهيكلة).
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({required this.title, this.note, super.key});

  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.construction_outlined,
                size: 56,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(S.comingSoon, style: theme.textTheme.titleMedium),
              if (note != null) ...[
                const SizedBox(height: 8),
                Text(
                  note!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
