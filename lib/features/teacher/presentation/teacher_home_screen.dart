import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/l10n/ar_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../../data/models/subject.dart';
import '../../auth/auth_controller.dart';
import '../../shared/providers/content_providers.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/status_banner.dart';
import '../widgets/subject_form_sheet.dart';

/// لوحة الأستاذ: قائمة المواد مع الإضافة والتعديل والحذف.
class TeacherHomeScreen extends ConsumerWidget {
  const TeacherHomeScreen({super.key});

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      ref.invalidate(subjectsProvider);
    } on AppException catch (error) {
      ref.invalidate(subjectsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final result = await SubjectFormSheet.show(context);
    if (result == null) return;
    await _run(context, ref, () async {
      await ref.read(teacherRepositoryProvider).createSubject(
            title: result.title,
            description: result.description,
          );
    });
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Subject subject,
  ) async {
    final result = await SubjectFormSheet.show(context, subject: subject);
    if (result == null) return;
    await _run(context, ref, () async {
      await ref.read(teacherRepositoryProvider).updateSubject(
            id: subject.id,
            title: result.title,
            description: result.description,
          );
    });
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Subject subject,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(S.deleteSubject),
        content: Text(
          'سيُحذف «${subject.title}» بكل دروسه وفقراته نهائيًا.',
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

    await _run(context, ref, () async {
      await ref.read(teacherRepositoryProvider).deleteSubject(subject.id);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsProvider);
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text(S.teacherDashboard),
        actions: [
          IconButton(
            tooltip: S.stats,
            onPressed: () => context.push(Routes.teacherStats),
            icon: const Icon(Icons.bar_chart),
          ),
          IconButton(
            tooltip: S.logout,
            onPressed: () => _confirmLogout(context, ref),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          const StatusBanner(),
          if (user != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'مرحبًا، ${user.fullName}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(contentRepositoryProvider).refreshCatalog();
                ref.invalidate(subjectsProvider);
              },
              child: AsyncView(
                value: subjects,
                onRetry: () => ref.invalidate(subjectsProvider),
                isEmpty: (list) => list.isEmpty,
                emptyMessage: 'لم تُضِف أي مادة بعد.',
                builder: (list) => ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final subject = list[index];
                    return Card(
                      child: ListTile(
                        title: Text(subject.title),
                        subtitle: Text('${subject.lessonsCount} درسًا'),
                        onTap: () =>
                            context.push(Routes.teacherSubject(subject.id)),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) => switch (value) {
                            'edit' => _edit(context, ref, subject),
                            'delete' => _delete(context, ref, subject),
                            _ => null,
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text(S.edit)),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(S.delete),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text(S.addSubject),
      ),
    );
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
    if (confirmed ?? false) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }
}
