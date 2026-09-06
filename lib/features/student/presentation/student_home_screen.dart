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

/// الشاشة الأولى للتلميذ: قائمة المواد.
///
/// شريحة رأسية مبكّرة تُثبت أن السلسلة كاملة تعمل:
/// API → قاعدة البيانات المحلية → المستودع → Riverpod → الواجهة.
/// شاشات الدروس والعارض والكويز تأتي في المرحلة التالية.
class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsProvider);
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text(S.myLessons),
        actions: [
          IconButton(
            tooltip: S.syncNow,
            onPressed: () {
              ref.read(syncServiceProvider).syncAll();
              ref.invalidate(subjectsProvider);
            },
            icon: const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: S.settings,
            onPressed: () => context.push(Routes.settings),
            icon: const Icon(Icons.settings_outlined),
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
                emptyMessage: 'لا توجد مواد متاحة بعد.',
                builder: (list) => ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final subject = list[index];
                    return Card(
                      child: ListTile(
                        title: Text(subject.title),
                        subtitle: subject.description == null
                            ? Text('${subject.lessonsCount} درسًا')
                            : Text(subject.description!),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () =>
                            context.push(Routes.subjectLessons(subject.id)),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) context.push(Routes.studentProgress);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: S.myLessons,
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: S.myProgress,
          ),
        ],
      ),
    );
  }
}
