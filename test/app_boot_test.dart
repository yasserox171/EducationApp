import 'package:education_app/app/app.dart';
import 'package:education_app/core/config/env.dart';
import 'package:education_app/core/l10n/ar_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// اختبارات إقلاع التطبيق: تتحقّق من أن الشجرة تُبنى فعلًا، وأن التحويل
/// حسب الإعداد/الدخول يعمل، وأن الاتجاه RTL.
void main() {
  tearDown(() => Env.setTestValues(null));

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: EducationApp()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('بدون BASE_URL يعرض التطبيق شاشة «الإعداد غير مكتمل»',
      (tester) async {
    Env.setTestValues(const {});

    await pumpApp(tester);

    expect(find.text(S.configMissingTitle), findsOneWidget);
    expect(find.text(S.login), findsNothing);
  });

  testWidgets('مع BASE_URL وبدون جلسة يعرض شاشة تسجيل الدخول',
      (tester) async {
    Env.setTestValues(const {'BASE_URL': 'https://api.test/v1'});

    await pumpApp(tester);

    expect(find.text(S.appName), findsOneWidget);
    expect(find.text(S.email), findsOneWidget);
    expect(find.text(S.password), findsOneWidget);
    expect(find.text(S.noSelfSignup), findsOneWidget);
  });

  testWidgets('اتجاه الواجهة من اليمين إلى اليسار', (tester) async {
    Env.setTestValues(const {'BASE_URL': 'https://api.test/v1'});

    await pumpApp(tester);

    final direction = Directionality.of(
      tester.element(find.text(S.appName)),
    );
    expect(direction, TextDirection.rtl);
  });

  testWidgets('نموذج الدخول يرفض الحقول الفارغة', (tester) async {
    Env.setTestValues(const {'BASE_URL': 'https://api.test/v1'});

    await pumpApp(tester);
    await tester.tap(find.widgetWithText(FilledButton, S.login));
    await tester.pumpAndSettle();

    expect(find.text(S.emailRequired), findsOneWidget);
    expect(find.text(S.passwordRequired), findsOneWidget);
  });

  testWidgets('بريد بصيغة خاطئة يُرفض قبل إرسال أي طلب', (tester) async {
    Env.setTestValues(const {'BASE_URL': 'https://api.test/v1'});

    await pumpApp(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, S.email),
      'not-an-email',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, S.password),
      'secret123',
    );
    await tester.tap(find.widgetWithText(FilledButton, S.login));
    await tester.pumpAndSettle();

    expect(find.text(S.emailInvalid), findsOneWidget);
  });
}
