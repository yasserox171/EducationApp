import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/l10n/ar_strings.dart';
import '../../../data/models/enums.dart';
import '../../shared/providers/content_providers.dart';

/// اختيار الطور الدراسي لمادة.
///
/// يظهر عند أول دخول للمادة، ويمكن استدعاؤه لاحقًا من الإعدادات لتغييره.
class LevelPicker extends ConsumerWidget {
  const LevelPicker({
    required this.subjectId,
    this.currentLevel,
    this.onSelected,
    super.key,
  });

  final String subjectId;
  final LessonLevel? currentLevel;
  final void Function(LessonLevel level)? onSelected;

  /// يعرض المنتقي في ورقة سفلية ويعيد الطور المختار (أو `null` عند الإلغاء).
  static Future<LessonLevel?> show(
    BuildContext context, {
    required String subjectId,
    LessonLevel? currentLevel,
  }) =>
      showModalBottomSheet<LessonLevel>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: LevelPicker(
            subjectId: subjectId,
            currentLevel: currentLevel,
            onSelected: (level) => Navigator.of(sheetContext).pop(level),
          ),
        ),
      );

  Future<void> _select(WidgetRef ref, LessonLevel level) async {
    await ref
        .read(progressRepositoryProvider)
        .setLevel(subjectId: subjectId, level: level);
    ref.invalidate(subjectLevelProvider(subjectId));
    // الطور يغيّر قائمة الدروس المعروضة.
    ref.invalidate(lessonsProvider);
    onSelected?.call(level);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              S.chooseLevel,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              S.levelHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            for (final level in LessonLevel.values) ...[
              _LevelCard(
                level: level,
                isSelected: level == currentLevel,
                onTap: () => _select(ref, level),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.isSelected,
    required this.onTap,
  });

  final LessonLevel level;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              level == LessonLevel.middle
                  ? Icons.school_outlined
                  : Icons.auto_stories_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                level.label,
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
