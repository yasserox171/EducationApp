import 'package:education_app/core/utils/latex_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// محلّل نص الفقرة: يفصل النص العربي عن معادلات LaTeX المحاطة بـ `$$`.
void main() {
  group('parseLatex', () {
    test('نص بلا معادلات يبقى مقطعًا واحدًا', () {
      final segments = parseLatex('نص عادي بلا رياضيات');

      expect(segments.length, 1);
      expect(segments.single.isMath, isFalse);
      expect(segments.single.content, 'نص عادي بلا رياضيات');
    });

    test('نص فارغ يعطي قائمة فارغة', () {
      expect(parseLatex(''), isEmpty);
    });

    test('معادلة بين نصّين تُفصل في ثلاثة مقاطع', () {
      final segments = parseLatex(r'المساحة $$A = \pi r^2$$ حيث r نصف القطر');

      expect(segments.length, 3);
      expect(segments[0].isMath, isFalse);
      expect(segments[0].content, 'المساحة ');
      expect(segments[1].isMath, isTrue);
      expect(segments[1].content, r'A = \pi r^2');
      expect(segments[2].isMath, isFalse);
      expect(segments[2].content, ' حيث r نصف القطر');
    });

    test('عدة معادلات في نفس الفقرة', () {
      final segments = parseLatex(r'$$a^2$$ و $$b^2$$ و $$c^2$$');
      final math = segments.where((s) => s.isMath).map((s) => s.content);

      expect(math, [r'a^2', r'b^2', r'c^2']);
    });

    test('معادلة تبدأ الفقرة وتنهيها', () {
      final segments = parseLatex(r'$$x = 1$$');

      expect(segments.length, 1);
      expect(segments.single.isMath, isTrue);
      expect(segments.single.content, 'x = 1');
    });

    test('فاصل غير مغلق يبقى نصًا (الأستاذ ما زال يكتب)', () {
      final segments = parseLatex(r'نبدأ $$x = ');

      expect(segments.every((s) => !s.isMath), isTrue);
      expect(segments.map((s) => s.content).join(), r'نبدأ $$x = ');
    });

    test('معادلة فارغة تُتجاهل ولا تكسر النص', () {
      final segments = parseLatex(r'قبل $$$$ بعد');

      expect(segments.where((s) => s.isMath), isEmpty);
      expect(segments.map((s) => s.content).join(), 'قبل  بعد');
    });

    test('المسافات حول الصيغة تُقلَّم', () {
      final segments = parseLatex(r'$$   x + 1   $$');

      expect(segments.single.content, 'x + 1');
    });

    test('hasLatex يميّز الفقرات التي فيها رياضيات', () {
      expect(hasLatex('نص عادي'), isFalse);
      expect(hasLatex(r'نص فيه $$x$$'), isTrue);
      expect(hasLatex(r'فاصل ناقص $$x'), isFalse);
    });

    test('wrapLatex يلفّ الصيغة بالفواصل', () {
      expect(wrapLatex(r'\sqrt{2}'), r'$$\sqrt{2}$$');
      // ويعود المحلّل فيقرأها معادلة واحدة.
      expect(parseLatex(wrapLatex(r'\sqrt{2}')).single.isMath, isTrue);
    });

    test('الأسطر الجديدة داخل النص تبقى كما هي', () {
      final segments = parseLatex('سطر\n\nسطر آخر');

      expect(segments.single.content, 'سطر\n\nسطر آخر');
    });
  });
}
