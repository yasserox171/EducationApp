import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../../core/utils/latex_parser.dart';

/// نصّ عربي تتخلّله معادلات رياضية مرسومة.
///
/// المعادلات تُرسم على الجهاز بـ `flutter_math_fork`، فلا حاجة لإنترنت
/// ولا لصور جاهزة — وهو شرط عمل الدروس المحمَّلة أوفلاين.
///
/// كل معادلة تُلفّ باتجاه LTR داخل النص العربي: الرموز الرياضية تُقرأ من
/// اليسار إلى اليمين حتى داخل فقرة RTL.
class MathText extends StatelessWidget {
  const MathText(
    this.data, {
    this.style,
    this.textAlign,
    super.key,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    final segments = parseLatex(data);

    if (segments.isEmpty) {
      return Text('', style: effectiveStyle, textAlign: textAlign);
    }

    // لا معادلات: نصّ عادي قابل للتحديد.
    if (!segments.any((segment) => segment.isMath)) {
      return SelectableText(
        data,
        style: effectiveStyle,
        textAlign: textAlign,
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          for (final segment in segments)
            if (segment.isMath)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Math.tex(
                    segment.content,
                    textStyle: effectiveStyle,
                    // معادلة بها خطأ إملائي لا يجوز أن تُسقط الشاشة:
                    // نعرض نصّها الخام ليصلحه الأستاذ.
                    onErrorFallback: (error) => Text(
                      segment.content,
                      style: effectiveStyle.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              )
            else
              TextSpan(text: segment.content),
        ],
      ),
      style: effectiveStyle,
      textAlign: textAlign,
    );
  }
}
