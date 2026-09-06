import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/l10n/ar_strings.dart';

/// شريط رفيع أعلى الشاشة يوضّح حالة الاتصال والمزامنة.
/// يختفي تمامًا عندما يكون كل شيء على ما يرام.
class StatusBanner extends ConsumerWidget {
  const StatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;
    final sync = ref.watch(syncStatusProvider).valueOrNull;
    final pending = sync?.pendingCount ?? 0;

    if (isOnline && pending == 0 && !(sync?.isSyncing ?? false)) {
      return const SizedBox.shrink();
    }

    final (message, background, foreground) = switch ((isOnline, pending)) {
      (false, _) => (
          S.offlineBadge,
          theme.colorScheme.errorContainer,
          theme.colorScheme.onErrorContainer,
        ),
      (true, final count) when count > 0 => (
          '${S.pendingSync}: $count',
          theme.colorScheme.tertiaryContainer,
          theme.colorScheme.onTertiaryContainer,
        ),
      _ => (
          S.syncing,
          theme.colorScheme.secondaryContainer,
          theme.colorScheme.onSecondaryContainer,
        ),
    };

    return Material(
      color: background,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (sync?.isSyncing ?? false) ...[
                SizedBox(
                  height: 12,
                  width: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(color: foreground),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
