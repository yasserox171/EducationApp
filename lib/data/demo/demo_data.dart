/// بيانات وضع التجربة (الديمو).
///
/// تُستعمل عندما يكون `DEMO_MODE=true` في `.env`: عندها لا يتصل التطبيق بأي
/// خادم، ويعمل بخادم وهمي في الذاكرة (`DemoApiClient`) مصدره هذا الملف.
///
/// الفيديوهات روابط عيّنات عامة من Google (ملفات اختبار معروفة)، وليست
/// دروسًا حقيقية — الغرض منها تجربة التشغيل والتحميل للاستعمال دون إنترنت.
library;

class DemoUsers {
  const DemoUsers._();

  static const String teacherEmail = 'prof@demo.dz';
  static const String studentEmail = 'eleve@demo.dz';
  static const String password = 'demo1234';

  static const Map<String, dynamic> teacher = {
    'id': 'u-teacher',
    'full_name': 'الأستاذ ياسر بلقاسم',
    'email': teacherEmail,
    'role': 'teacher',
  };

  static const Map<String, dynamic> student = {
    'id': 'u-student',
    'full_name': 'أمين بن عمر',
    'email': studentEmail,
    'role': 'student',
  };
}

/// عيّنات فيديو عامة صغيرة الحجم (لتجربة التشغيل وزر التحميل).
class _Videos {
  const _Videos._();

  static const String _base =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample';

  static const String blazes = '$_base/ForBiggerBlazes.mp4';
  static const String escapes = '$_base/ForBiggerEscapes.mp4';
  static const String joyrides = '$_base/ForBiggerJoyrides.mp4';
  static const String meltdowns = '$_base/ForBiggerMeltdowns.mp4';

  // أحجام تقريبية بالبايت — تُستعمل لتقدير المساحة قبل التحميل فقط،
  // والحجم الحقيقي يُقرأ من ترويسة الرد أثناء التحميل.
  static const int blazesBytes = 2498125;
  static const int escapesBytes = 2299653;
  static const int joyridesBytes = 2415262;
  static const int meltdownsBytes = 2493355;
}

String _now() => DateTime.now().toUtc().toIso8601String();

/// المواد. تُبنى في كل نداء حتى لا يعدّل الخادم الوهمي ثوابت مشتركة.
List<Map<String, dynamic>> demoSubjects() => [
      {
        'id': 's-math',
        'title': 'الرياضيات',
        'description': 'الجبر والدوال والهندسة — للطورين المتوسط والثانوي.',
        'position': 0,
        'lessons_count': 4,
        'updated_at': _now(),
      },
      {
        'id': 's-physics',
        'title': 'الفيزياء',
        'description': 'الكهرباء والحركة مع تجارب مصوّرة.',
        'position': 1,
        'lessons_count': 3,
        'updated_at': _now(),
      },
      {
        'id': 's-arabic',
        'title': 'اللغة العربية',
        'description': 'النحو والبلاغة وتحليل النصوص.',
        'position': 2,
        'lessons_count': 2,
        'updated_at': _now(),
      },
    ];

/// الدروس موزّعة على الطورين: متوسط (middle) وثانوي (secondary).
List<Map<String, dynamic>> demoLessons() => [
      // ------------------------------------------------------- الرياضيات
      {
        'id': 'l-math-1',
        'subject_id': 's-math',
        'title': 'المعادلات من الدرجة الأولى',
        'summary': 'كيف نحلّ معادلة بمجهول واحد خطوة بخطوة.',
        'level': 'middle',
        'position': 0,
        'blocks_count': 5,
        'is_published': true,
        'updated_at': _now(),
      },
      {
        'id': 'l-math-2',
        'subject_id': 's-math',
        'title': 'النسب المئوية',
        'summary': 'الحساب على النسب وتطبيقاتها في الحياة اليومية.',
        'level': 'middle',
        'position': 1,
        'blocks_count': 4,
        'is_published': true,
        'updated_at': _now(),
      },
      {
        'id': 'l-math-3',
        'subject_id': 's-math',
        'title': 'الدوال العددية',
        'summary': 'مفهوم الدالة، مجموعة التعريف، والتمثيل البياني.',
        'level': 'secondary',
        'position': 2,
        'blocks_count': 4,
        'is_published': true,
        'updated_at': _now(),
      },
      {
        'id': 'l-math-4',
        'subject_id': 's-math',
        'title': 'الاشتقاق وتطبيقاته',
        'summary': 'العدد المشتق، دراسة اتجاه التغيّر، والقيم الحدّية.',
        'level': 'secondary',
        'position': 3,
        'blocks_count': 3,
        'is_published': true,
        'updated_at': _now(),
      },

      // --------------------------------------------------------- الفيزياء
      {
        'id': 'l-phy-1',
        'subject_id': 's-physics',
        'title': 'الدارة الكهربائية البسيطة',
        'summary': 'المولّد، الناقل، والمصباح — وكيف يمرّ التيار.',
        'level': 'middle',
        'position': 0,
        'blocks_count': 4,
        'is_published': true,
        'updated_at': _now(),
      },
      {
        'id': 'l-phy-2',
        'subject_id': 's-physics',
        'title': 'قانون أوم',
        'summary': 'العلاقة بين التوتر والشدّة والمقاومة.',
        'level': 'middle',
        'position': 1,
        'blocks_count': 3,
        'is_published': true,
        'updated_at': _now(),
      },
      {
        'id': 'l-phy-3',
        'subject_id': 's-physics',
        'title': 'الحركة والسرعة المتوسطة',
        'summary': 'المرجع، المسار، وحساب السرعة.',
        'level': 'secondary',
        'position': 2,
        'blocks_count': 3,
        'is_published': true,
        'updated_at': _now(),
      },

      // ---------------------------------------------------- اللغة العربية
      {
        'id': 'l-ar-1',
        'subject_id': 's-arabic',
        'title': 'الجملة الاسمية والجملة الفعلية',
        'summary': 'التمييز بينهما وإعراب كل منهما.',
        'level': 'middle',
        'position': 0,
        'blocks_count': 4,
        'is_published': true,
        'updated_at': _now(),
      },
      {
        'id': 'l-ar-2',
        'subject_id': 's-arabic',
        'title': 'التشبيه والاستعارة',
        'summary': 'أركان التشبيه، وكيف تتحوّل إلى استعارة.',
        'level': 'secondary',
        'position': 1,
        'blocks_count': 3,
        'is_published': true,
        'updated_at': _now(),
      },
    ];

Map<String, dynamic> _text(
  String id,
  String lessonId,
  int position, {
  String? heading,
  required String body,
}) =>
    {
      'id': id,
      'lesson_id': lessonId,
      'position': position,
      'type': 'text',
      'data': {'heading': heading, 'body': body},
      'updated_at': _now(),
    };

/// ملف PDF عام صغير (~١٣ ك.ب) يُستعمل كمرفق في بيانات التجربة.
const String _demoPdfUrl =
    'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf';

Map<String, dynamic> _pdf({
  required String id,
  required String fileName,
  int sizeBytes = 13264,
}) =>
    {
      'id': id,
      'file_name': fileName,
      'url': _demoPdfUrl,
      'file_size': sizeBytes,
      'created_at': _now(),
    };

Map<String, dynamic> _video(
  String id,
  String lessonId,
  int position, {
  required String title,
  required String url,
  required int sizeBytes,
  int durationSeconds = 15,
  List<Map<String, dynamic>> attachments = const [],
}) =>
    {
      'id': id,
      'lesson_id': lessonId,
      'position': position,
      'type': 'video',
      'data': {
        'title': title,
        'url': url,
        'duration_seconds': durationSeconds,
        'size_bytes': sizeBytes,
        'attachments': attachments,
      },
      'updated_at': _now(),
    };

/// سؤال واحد داخل فقرة كويز.
Map<String, dynamic> _question({
  required String id,
  required String question,
  required List<List<String>> options,
  required String correct,
  String? explanation,
}) =>
    {
      'id': id,
      'question': question,
      'options': [
        for (final option in options) {'id': option[0], 'text': option[1]},
      ],
      'correct_option_id': correct,
      'explanation': explanation,
    };

/// فقرة كويز بسؤال واحد (الشكل الشائع في هذه البيانات).
Map<String, dynamic> _quiz(
  String id,
  String lessonId,
  int position, {
  required String question,
  required List<List<String>> options,
  required String correct,
  String? explanation,
}) =>
    _quizSet(
      id,
      lessonId,
      position,
      questions: [
        _question(
          id: 'q1',
          question: question,
          options: options,
          correct: correct,
          explanation: explanation,
        ),
      ],
    );

/// فقرة كويز بعدة أسئلة: النتيجة لا تظهر للتلميذ إلا بعد إتمامها كلها.
Map<String, dynamic> _quizSet(
  String id,
  String lessonId,
  int position, {
  required List<Map<String, dynamic>> questions,
}) =>
    {
      'id': id,
      'lesson_id': lessonId,
      'position': position,
      'type': 'quiz',
      'data': {'questions': questions},
      'updated_at': _now(),
    };

/// فقرات كل درس، مرتّبة. مفتاح الخريطة هو معرّف الدرس.
Map<String, List<Map<String, dynamic>>> demoBlocks() => {
      'l-math-1': [
        _text(
          'b-m1-1',
          'l-math-1',
          0,
          heading: 'ما هي المعادلة؟',
          body: 'المعادلة تساوٍ بين طرفين يحتوي على مجهول، ونرمز له عادة '
              'بالحرف س. حلّ المعادلة يعني إيجاد قيمة المجهول التي تجعل '
              'الطرفين متساويين.\n\n'
              'مثال: س + ٣ = ٧\n'
              'نطرح ٣ من الطرفين فنجد: س = ٤.',
        ),
        _text(
          'b-m1-2',
          'l-math-1',
          1,
          heading: 'القاعدة الأساسية',
          body: 'كل ما نفعله بطرف يجب أن نفعله بالطرف الآخر:\n\n'
              '• الجمع والطرح: نضيف أو نطرح نفس العدد من الطرفين.\n'
              '• الضرب والقسمة: نضرب أو نقسم الطرفين على نفس العدد '
              '(بشرط ألا يكون صفرًا).\n\n'
              'هكذا يبقى التساوي صحيحًا حتى نعزل المجهول في طرف وحده.',
        ),
        _video(
          'b-m1-3',
          'l-math-1',
          2,
          title: 'شرح مرئي: خطوات الحلّ',
          url: _Videos.blazes,
          sizeBytes: _Videos.blazesBytes,
          attachments: [
            _pdf(id: 'att-m1-1', fileName: 'ملخص المعادلات.pdf'),
            _pdf(id: 'att-m1-2', fileName: 'تمارين تطبيقية.pdf'),
          ],
        ),
        _quiz(
          'b-m1-4',
          'l-math-1',
          3,
          question: 'ما هو حلّ المعادلة: ٢ س = ١٠ ؟',
          options: [
            ['a', 'س = ٢'],
            ['b', 'س = ٥'],
            ['c', 'س = ١٠'],
            ['d', 'س = ٢٠'],
          ],
          correct: 'b',
          explanation: 'نقسم الطرفين على ٢ فنجد س = ٥.',
        ),
        // فقرة بثلاثة أسئلة: نموذج لاختبار قصير في نهاية الدرس.
        _quizSet(
          'b-m1-5',
          'l-math-1',
          4,
          questions: [
            _question(
              id: 'q1',
              question: 'في المعادلة س − ٤ = ٦ ، ماذا نفعل أولًا؟',
              options: [
                ['a', 'نضيف ٤ إلى الطرفين'],
                ['b', 'نطرح ٦ من الطرفين'],
                ['c', 'نضرب الطرفين في ٤'],
              ],
              correct: 'a',
              explanation: 'إضافة ٤ تعزل س في الطرف الأيسر: س = ١٠.',
            ),
            _question(
              id: 'q2',
              question: 'ما هو حلّ المعادلة: ٣ س + ٦ = ٠ ؟',
              options: [
                ['a', 'س = ٢'],
                ['b', 'س = −٢'],
                ['c', 'س = ٦'],
              ],
              correct: 'b',
              explanation: 'نطرح ٦ ثم نقسم على ٣ فنجد س = −٢.',
            ),
            _question(
              id: 'q3',
              question: 'أيّ العبارات التالية معادلة من الدرجة الأولى؟',
              options: [
                ['a', 'س² + ١ = ٠'],
                ['b', '٥ س − ٣ = ٧'],
                ['c', '١ ÷ س = ٢'],
              ],
              correct: 'b',
              explanation: 'الدرجة الأولى تعني أن أعلى أُسّ للمجهول هو ١.',
            ),
          ],
        ),
      ],
      'l-math-2': [
        _text(
          'b-m2-1',
          'l-math-2',
          0,
          heading: 'معنى النسبة المئوية',
          body: 'النسبة المئوية كسر مقامه ١٠٠. فالقول «٢٥٪» يعني ٢٥ من كل '
              '١٠٠، أي ربع الكمية.',
        ),
        _text(
          'b-m2-2',
          'l-math-2',
          1,
          heading: 'حساب نسبة من عدد',
          body: 'لحساب ٢٠٪ من ٨٠:\n'
              'نضرب ٨٠ × ٢٠ ÷ ١٠٠ = ١٦.\n\n'
              'وللزيادة بنسبة ٢٠٪ نضيف الناتج: ٨٠ + ١٦ = ٩٦.',
        ),
        _video(
          'b-m2-3',
          'l-math-2',
          2,
          title: 'تطبيقات على التخفيضات',
          url: _Videos.escapes,
          sizeBytes: _Videos.escapesBytes,
        ),
        _quiz(
          'b-m2-4',
          'l-math-2',
          3,
          question: 'قميص ثمنه ٢٠٠٠ دج، خُفّض بنسبة ١٠٪. كم صار ثمنه؟',
          options: [
            ['a', '١٩٠٠ دج'],
            ['b', '١٨٠٠ دج'],
            ['c', '١٧٠٠ دج'],
          ],
          correct: 'b',
          explanation: '١٠٪ من ٢٠٠٠ هي ٢٠٠، والثمن الجديد ٢٠٠٠ − ٢٠٠ = ١٨٠٠.',
        ),
      ],
      'l-math-3': [
        _text(
          'b-m3-1',
          'l-math-3',
          0,
          heading: 'مفهوم الدالة',
          body: 'الدالة علاقة تربط كل عنصر من مجموعة الانطلاق بعنصر واحد على '
              'الأكثر من مجموعة الوصول. نكتب f(س) للدلالة على صورة س.',
        ),
        _text(
          'b-m3-2',
          'l-math-3',
          1,
          heading: 'مجموعة التعريف',
          body: r'هي مجموعة القيم التي تقبل الدالة حسابها. مثلًا الدالة '
              r'$$f(x) = \frac{1}{x}$$ غير معرّفة عند $$x = 0$$ لأن القسمة '
              r'على صفر مستحيلة.'
              '\n\n'
              r'أما $$g(x) = \sqrt{x}$$ فمجموعة تعريفها $$x \geq 0$$ لأن '
              r'الجذر التربيعي لا يُحسب لعدد سالب.',
        ),
        _video(
          'b-m3-3',
          'l-math-3',
          2,
          title: 'قراءة التمثيل البياني',
          url: _Videos.joyrides,
          sizeBytes: _Videos.joyridesBytes,
        ),
        _quiz(
          'b-m3-4',
          'l-math-3',
          3,
          question: 'ما هي مجموعة تعريف الدالة f(س) = ١ ÷ (س − ٢) ؟',
          options: [
            ['a', 'كل الأعداد الحقيقية'],
            ['b', 'كل الأعداد الحقيقية عدا ٠'],
            ['c', 'كل الأعداد الحقيقية عدا ٢'],
          ],
          correct: 'c',
          explanation: 'المقام ينعدم عند س = ٢، لذا تُستثنى هذه القيمة.',
        ),
      ],
      'l-math-4': [
        _text(
          'b-m4-1',
          'l-math-4',
          0,
          heading: 'العدد المشتق',
          body: r'المشتق يقيس سرعة تغيّر الدالة، ويُعرَّف بالنهاية:'
              '\n\n'
              r"$$f'(a) = \lim_{h \to 0} \frac{f(a+h) - f(a)}{h}$$"
              '\n\n'
              r'هندسيًا هو معامل توجيه المماس للمنحنى عند النقطة. '
              r"مثال: مشتق $$f(x) = x^{2}$$ هو $$f'(x) = 2x$$.",
        ),
        _text(
          'b-m4-2',
          'l-math-4',
          1,
          heading: 'اتجاه التغيّر',
          body: r"إذا كان $$f'(x) > 0$$ على مجال فالدالة متزايدة عليه، "
              r"وإذا كان $$f'(x) < 0$$ فالدالة متناقصة. وانعدام المشتق مع "
              r'تغيّر إشارته يدلّ على قيمة حدّية (قصوى أو دنيا).'
              '\n\n'
              r'ومن التطبيقات حساب المساحة تحت المنحنى بالتكامل: '
              r'$$\int_{0}^{1} x^{2} \, dx = \frac{1}{3}$$',
        ),
        _quiz(
          'b-m4-3',
          'l-math-4',
          2,
          question: 'إذا كان مشتق دالة سالبًا على مجال، فالدالة عليه:',
          options: [
            ['a', 'متزايدة'],
            ['b', 'متناقصة'],
            ['c', 'ثابتة'],
          ],
          correct: 'b',
          explanation: 'إشارة المشتق السالبة تعني تناقص الدالة.',
        ),
      ],
      'l-phy-1': [
        _text(
          'b-p1-1',
          'l-phy-1',
          0,
          heading: 'مكوّنات الدارة',
          body: 'الدارة الكهربائية البسيطة تتكوّن من مولّد (بطارية)، وأسلاك '
              'ناقلة، وجهاز استقبال (مصباح مثلًا)، وقاطعة للتحكّم.',
        ),
        _text(
          'b-p1-2',
          'l-phy-1',
          1,
          heading: 'شرط مرور التيار',
          body: 'لا يمرّ التيار إلا إذا كانت الدارة مغلقة، أي أن كل عناصرها '
              'موصولة ولا يوجد انقطاع. القاطعة المفتوحة تقطع المسار فينطفئ '
              'المصباح.',
        ),
        _video(
          'b-p1-3',
          'l-phy-1',
          2,
          title: 'تجربة: تركيب دارة',
          url: _Videos.meltdowns,
          sizeBytes: _Videos.meltdownsBytes,
          attachments: [
            _pdf(id: 'att-p1-1', fileName: 'ورقة التجربة.pdf'),
          ],
        ),
        _quiz(
          'b-p1-4',
          'l-phy-1',
          3,
          question: 'متى يضيء المصباح في الدارة؟',
          options: [
            ['a', 'عندما تكون الدارة مفتوحة'],
            ['b', 'عندما تكون الدارة مغلقة'],
            ['c', 'في الحالتين'],
          ],
          correct: 'b',
          explanation: 'التيار يحتاج مسارًا مغلقًا ليمرّ.',
        ),
      ],
      'l-phy-2': [
        _text(
          'b-p2-1',
          'l-phy-2',
          0,
          heading: 'نصّ القانون',
          body: 'ينصّ قانون أوم على أن التوتر بين طرفي ناقل أومي يساوي جداء '
              'مقاومته في شدّة التيار المارّ فيه:\n\n'
              'U = R × I',
        ),
        _text(
          'b-p2-2',
          'l-phy-2',
          1,
          heading: 'الوحدات',
          body: 'U بالفولط (V)، و R بالأوم (Ω)، و I بالأمبير (A).\n'
              'مثال: ناقل مقاومته ١٠ أوم يمرّ فيه تيار شدّته ٠٫٥ أمبير، '
              'فالتوتر بين طرفيه: ١٠ × ٠٫٥ = ٥ فولط.',
        ),
        _quiz(
          'b-p2-3',
          'l-phy-2',
          2,
          question: 'ناقل مقاومته ٢٠ أوم وشدّة التيار فيه ٢ أمبير. ما التوتر؟',
          options: [
            ['a', '١٠ فولط'],
            ['b', '٢٢ فولط'],
            ['c', '٤٠ فولط'],
          ],
          correct: 'c',
          explanation: 'U = R × I = ٢٠ × ٢ = ٤٠ فولط.',
        ),
      ],
      'l-phy-3': [
        _text(
          'b-p3-1',
          'l-phy-3',
          0,
          heading: 'نسبية الحركة',
          body: 'الحركة والسكون مفهومان نسبيان: الجسم يكون متحرّكًا بالنسبة '
              'لمرجع وساكنًا بالنسبة لمرجع آخر. لذلك نحدّد المرجع دائمًا قبل '
              'وصف الحركة.',
        ),
        _text(
          'b-p3-2',
          'l-phy-3',
          1,
          heading: 'السرعة المتوسطة',
          body: 'السرعة المتوسطة = المسافة المقطوعة ÷ المدة الزمنية.\n\n'
              'مثال: قطع متسابق ١٠٠ متر في ١٠ ثوانٍ، فسرعته المتوسطة '
              '١٠ أمتار في الثانية.',
        ),
        _quiz(
          'b-p3-3',
          'l-phy-3',
          2,
          question: 'سيارة قطعت ١٢٠ كلم في ساعتين. ما سرعتها المتوسطة؟',
          options: [
            ['a', '٤٠ كلم/سا'],
            ['b', '٦٠ كلم/سا'],
            ['c', '١٢٠ كلم/سا'],
          ],
          correct: 'b',
          explanation: '١٢٠ ÷ ٢ = ٦٠ كلم في الساعة.',
        ),
      ],
      'l-ar-1': [
        _text(
          'b-a1-1',
          'l-ar-1',
          0,
          heading: 'الجملة الاسمية',
          body: 'هي ما بدأت باسم، وتتكوّن من مبتدأ وخبر.\n\n'
              'مثال: العلمُ نورٌ.\n'
              '«العلم» مبتدأ مرفوع، و«نور» خبر مرفوع.',
        ),
        _text(
          'b-a1-2',
          'l-ar-1',
          1,
          heading: 'الجملة الفعلية',
          body: 'هي ما بدأت بفعل، وتتكوّن من فعل وفاعل وقد يليها مفعول به.\n\n'
              'مثال: كتبَ التلميذُ الدرسَ.\n'
              '«كتب» فعل، و«التلميذ» فاعل مرفوع، و«الدرس» مفعول به منصوب.',
        ),
        _quiz(
          'b-a1-3',
          'l-ar-1',
          2,
          question: 'أيّ الجمل التالية جملة اسمية؟',
          options: [
            ['a', 'ذهب الولدُ إلى المدرسة'],
            ['b', 'السماءُ صافيةٌ'],
            ['c', 'اقرأ الدرسَ'],
          ],
          correct: 'b',
          explanation: 'بدأت باسم «السماء»، فهي اسمية: مبتدأ وخبر.',
        ),
        _quiz(
          'b-a1-4',
          'l-ar-1',
          3,
          question: 'في جملة «شربَ الطفلُ الحليبَ»، ما إعراب «الطفل»؟',
          options: [
            ['a', 'مبتدأ مرفوع'],
            ['b', 'فاعل مرفوع'],
            ['c', 'مفعول به منصوب'],
          ],
          correct: 'b',
          explanation: 'الجملة فعلية، و«الطفل» هو من قام بالفعل: فاعل مرفوع.',
        ),
      ],
      'l-ar-2': [
        _text(
          'b-a2-1',
          'l-ar-2',
          0,
          heading: 'أركان التشبيه',
          body: 'التشبيه أربعة أركان: المشبَّه، والمشبَّه به، وأداة التشبيه، '
              'ووجه الشبه.\n\n'
              'مثال: العلمُ كالنورِ في الهداية.\n'
              'المشبَّه: العلم — المشبَّه به: النور — الأداة: الكاف — '
              'وجه الشبه: الهداية.',
        ),
        _text(
          'b-a2-2',
          'l-ar-2',
          1,
          heading: 'من التشبيه إلى الاستعارة',
          body: 'إذا حُذف أحد الطرفين (المشبَّه أو المشبَّه به) صار التشبيه '
              'استعارة.\n\n'
              'مثال: «رأيتُ أسدًا يخطبُ» — حُذف المشبَّه (الرجل الشجاع) '
              'وبقي المشبَّه به (أسد)، فهي استعارة تصريحية.',
        ),
        _quiz(
          'b-a2-3',
          'l-ar-2',
          2,
          question: 'في قولنا «رأيت بحرًا يعطي»، ما نوع الصورة البيانية؟',
          options: [
            ['a', 'تشبيه تامّ الأركان'],
            ['b', 'استعارة تصريحية'],
            ['c', 'كناية'],
          ],
          correct: 'b',
          explanation:
              'حُذف المشبَّه (الرجل الكريم) وصُرّح بالمشبَّه به (بحر).',
        ),
      ],
    };

/// أرقام أساسية لإحصائيات الأستاذ في الديمو (قبل إضافة تقدّم التلميذ الحقيقي).
const Map<String, List<int>> demoLessonStatsBaseline = {
  // معرّف الدرس: [بدأوا، أكملوا]
  'l-math-1': [22, 14],
  'l-math-2': [19, 9],
  'l-math-3': [12, 5],
  'l-math-4': [8, 2],
  'l-phy-1': [17, 11],
  'l-phy-2': [15, 7],
  'l-phy-3': [9, 3],
  'l-ar-1': [20, 13],
  'l-ar-2': [11, 4],
};

/// عدد تلاميذ المركز في الديمو.
const int demoStudentsCount = 24;
