import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/l10n/ar_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/auth_controller.dart';
import '../../shared/providers/content_providers.dart';
import '../../shared/providers/download_providers.dart';
import '../../shared/widgets/async_view.dart';
import 'level_picker.dart';

/// الإعدادات: تغيير الطور لكل مادة، إدارة المساحة، حالة المزامنة، الخروج.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final subjects = ref.watch(subjectsProvider);
    final levels = ref.watch(allLevelsProvider).valueOrNull ?? const {};
    final sync = ref.watch(syncStatusProvider).valueOrNull;
    final usedStorage = ref.watch(usedStorageProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text(S.settings)),
      body: ListView(
        children: [
          if (auth.user != null)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(auth.user!.fullName),
              subtitle: Text(auth.user!.email, textDirection: TextDirection.ltr),
            ),
          const Divider(),

          // ------------------------------------------------ الطور لكل مادة
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(S.changeLevel, style: theme.textTheme.titleSmall),
          ),
          AsyncView(
            value: subjects,
            isEmpty: (list) => list.isEmpty,
            emptyMessage: 'لا توجد مواد.',
            builder: (list) => Column(
              children: [
                for (final subject in list)
                  ListTile(
                    title: Text(subject.title),
                    subtitle: Text(
                      levels[subject.id]?.label ?? 'لم تختر الطور بعد',
                    ),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      await LevelPicker.show(
                        context,
                        subjectId: subject.id,
                        currentLevel: levels[subject.id],
                      );
                      ref.invalidate(allLevelsProvider);
                    },
                  ),
              ],
            ),
          ),
          const Divider(),

          // -------------------------------------------------------- المساحة
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(S.storageUsed, style: theme.textTheme.titleSmall),
          ),
          ListTile(
            leading: const Icon(Icons.sd_storage_outlined),
            title: Text(Formatters.bytes(usedStorage)),
            subtitle: const Text('الدروس المحمَّلة على الجهاز'),
          ),
          ListTile(
            leading: Icon(
              Icons.delete_sweep_outlined,
              color: theme.colorScheme.error,
            ),
            title: const Text(S.deleteAllDownloads),
            onTap: () => _confirmDeleteDownloads(context, ref),
          ),
          const Divider(),

          // ------------------------------------------------------- المزامنة
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(S.syncing, style: theme.textTheme.titleSmall),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: Text(
              sync?.lastSyncAt == null
                  ? 'لم تتم أي مزامنة بعد'
                  : '${S.lastSync}: ${Formatters.date(sync!.lastSyncAt!.toLocal())}',
            ),
            subtitle: sync == null || !sync.hasPendingWork
                ? null
                : Text('${S.pendingSync}: ${sync.pendingCount + sync.failedCount}'),
            trailing: TextButton(
              onPressed: () => ref.read(syncServiceProvider).syncAll(),
              child: const Text(S.syncNow),
            ),
          ),
          if ((sync?.failedCount ?? 0) > 0)
            ListTile(
              leading: Icon(Icons.error_outline, color: theme.colorScheme.error),
              title: Text('${sync!.failedCount} عملية فشل إرسالها'),
              trailing: TextButton(
                onPressed: () => ref.read(syncServiceProvider).retryFailed(),
                child: const Text(S.retry),
              ),
            ),
          const Divider(),

          // --------------------------------------------------------- الخروج
          ListTile(
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text(
              S.logout,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () => _confirmLogout(context, ref),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteDownloads(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(S.deleteAllDownloads),
        content: const Text(
          'ستُحذف كل ملفات الفيديو المحمَّلة. يمكنك تحميلها مجددًا لاحقًا.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(S.delete),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;

    await ref.read(downloadRepositoryProvider).deleteAllDownloads();
    ref.invalidate(usedStorageProvider);
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(S.logout),
        content: const Text(S.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(S.confirm),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;

    await ref.read(authControllerProvider.notifier).logout();
  }
}
