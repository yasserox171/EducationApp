/// تقسيم نص الفقرة إلى مقاطع: نص عادي ومعادلات LaTeX.
///
/// الصيغة المخزَّنة نصّ واحد تُحاط فيه المعادلات بـ `$$`:
///
/// ```
/// مساحة الدائرة هي $$A = \pi r^2$$ حيث r نصف القطر.
/// ```
///
/// هكذا يبقى المحتوى نصًا قابلًا للتحرير والبحث والتخزين كما هو، ولا
/// يحتاج العرض أي اتصال بالإنترنت: التحويل إلى رموز يتم على الجهاز.
library;

/// مقطع واحد: نص عادي أو معادلة.
class LatexSegment {
  const LatexSegment.text(this.content) : isMath = false;
  const LatexSegment.math(this.content) : isMath = true;

  final String content;
  final bool isMath;

  @override
  bool operator ==(Object other) =>
      other is LatexSegment &&
      other.content == content &&
      other.isMath == isMath;

  @override
  int get hashCode => Object.hash(content, isMath);

  @override
  String toString() => isMath ? 'math($content)' : 'text($content)';
}

/// الفاصل المستعمل حول المعادلات.
const String latexDelimiter = r'$$';

/// يقسّم [source] إلى مقاطع بالتناوب بين النص والمعادلة.
///
/// فاصل غير مغلق (يكتبه الأستاذ أثناء الكتابة) يبقى نصًا عاديًا حتى لا
/// يختفي ما كتبه من المعاينة.
List<LatexSegment> parseLatex(String source) {
  if (source.isEmpty) return const <LatexSegment>[];
  if (!source.contains(latexDelimiter)) {
    return [LatexSegment.text(source)];
  }

  final segments = <LatexSegment>[];
  var index = 0;

  while (index < source.length) {
    final open = source.indexOf(latexDelimiter, index);
    if (open < 0) {
      _addText(segments, source.substring(index));
      break;
    }

    final close = source.indexOf(latexDelimiter, open + latexDelimiter.length);
    if (close < 0) {
      // فاصل مفتوح بلا إغلاق: نعرض الباقي نصًا.
      _addText(segments, source.substring(index));
      break;
    }

    _addText(segments, source.substring(index, open));
    final math = source.substring(open + latexDelimiter.length, close).trim();
    if (math.isNotEmpty) segments.add(LatexSegment.math(math));
    index = close + latexDelimiter.length;
  }

  return segments;
}

void _addText(List<LatexSegment> segments, String text) {
  if (text.isEmpty) return;
  segments.add(LatexSegment.text(text));
}

/// هل يحتوي النص معادلة واحدة على الأقل؟
bool hasLatex(String source) =>
    parseLatex(source).any((segment) => segment.isMath);

/// يلفّ [expression] بالفواصل ليُدرج في نص الفقرة.
String wrapLatex(String expression) =>
    '$latexDelimiter$expression$latexDelimiter';
