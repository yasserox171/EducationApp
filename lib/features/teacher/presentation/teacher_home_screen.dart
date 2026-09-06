import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/l10n/ar_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../auth/auth_controller.dart';
import '../../shared/providers/content_providers.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/status_banner.dart';

/// لوحة الأستاذ: قائمة المواد.
///
/// أزرار الإضافة/التعديل/الحذف ومحرّر الدرس تُبنى في المرحلة التالية —
/// المستودع (`TeacherRepository`) جاهز لها بالفعل.
class TeacherHomeScreen extends ConsumerWidget {
  const TeacherHomeScreen({super.key});

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
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () =>
                            context.push(Routes.teacherSubject(subject.id)),
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
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(S.comingSoon)),
        ),
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
