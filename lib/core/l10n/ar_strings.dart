/// نصوص الواجهة بالعربية.
///
/// التطبيق عربي فقط في هذه النسخة، لذا نستعمل ثوابت بدل توليد ملفات
/// الترجمة (`gen_l10n`). عند إضافة لغة ثانية لاحقًا يمكن تحويل هذا الملف
/// إلى `AppLocalizations` دون تغيير مواضع الاستدعاء كثيرًا.
class S {
  const S._();

  // ------------------------------------------------------------------ عام
  static const appName = 'تطبيق المركز التعليمي';
  static const retry = 'إعادة المحاولة';
  static const cancel = 'إلغاء';
  static const confirm = 'تأكيد';
  static const save = 'حفظ';
  static const delete = 'حذف';
  static const edit = 'تعديل';
  static const add = 'إضافة';
  static const close = 'إغلاق';
  static const loading = 'جارٍ التحميل…';
  static const emptyState = 'لا يوجد شيء لعرضه بعد.';
  static const offlineBadge = 'أنت غير متصل بالإنترنت';
  static const comingSoon = 'هذه الشاشة قيد الإنشاء.';

  // -------------------------------------------------------------- المصادقة
  static const login = 'تسجيل الدخول';
  static const logout = 'تسجيل الخروج';
  static const email = 'البريد الإلكتروني';
  static const password = 'كلمة السر';
  static const loginSubtitle = 'أدخل البيانات التي زوّدك بها الأستاذ.';
  static const emailRequired = 'أدخل البريد الإلكتروني.';
  static const emailInvalid = 'صيغة البريد الإلكتروني غير صحيحة.';
  static const passwordRequired = 'أدخل كلمة السر.';
  static const sessionExpired = 'انتهت الجلسة. سجّل الدخول من جديد.';
  static const noSelfSignup =
      'لا يوجد تسجيل ذاتي: الحسابات ينشئها الأستاذ.';

  // ------------------------------------------------------------ وضع التجربة
  static const demoBadge = 'نسخة تجريبية';
  static const demoAccounts = 'حسابات التجربة — اضغط لملء البيانات:';
  static const demoTeacherAccount = 'حساب أستاذ';
  static const demoStudentAccount = 'حساب تلميذ';
  static const demoNotice =
      'هذه نسخة تجريبية تعمل ببيانات محليّة دون خادم. تعديلات الأستاذ '
      'تعود إلى حالتها الأصلية عند إعادة تشغيل التطبيق، أما تقدّم التلميذ '
      'والدروس المحمَّلة فتبقى محفوظة على الجهاز.';
  static const logoutConfirm =
      'سيتم حذف الدروس المحمَّلة على الجهاز عند الخروج. هل تريد المتابعة؟';

  // ---------------------------------------------------------------- الإعداد
  static const configMissingTitle = 'الإعداد غير مكتمل';
  static const configMissingBody =
      'لم يُضبط عنوان الخادم (BASE_URL). انسخ ملف .env.example إلى .env '
      'وضع فيه عنوان الـ API ثم أعد تشغيل التطبيق.';

  // ------------------------------------------------------------ فضاء الأستاذ
  static const teacherDashboard = 'لوحة الأستاذ';
  static const subjects = 'المواد';
  static const addSubject = 'إضافة مادة';
  static const editSubject = 'تعديل المادة';
  static const deleteSubject = 'حذف المادة';
  static const subjectTitle = 'اسم المادة';
  static const subjectDescription = 'وصف المادة (اختياري)';
  static const lessons = 'الدروس';
  static const addLesson = 'إضافة درس';
  static const lessonTitle = 'عنوان الدرس';
  static const lessonSummary = 'ملخّص الدرس (اختياري)';
  static const reorderLessons = 'إعادة ترتيب الدروس';
  static const lessonEditor = 'محرّر الدرس';
  static const addTextBlock = 'إضافة فقرة نصية';
  static const addVideoBlock = 'إضافة فيديو';
  static const addQuizBlock = 'إضافة كويز';
  static const uploading = 'جارٍ الرفع…';
  static const pickVideo = 'اختيار فيديو من الجهاز';
  static const question = 'السؤال';
  static const options = 'الاختيارات';
  static const correctAnswer = 'الإجابة الصحيحة';
  static const explanation = 'شرح الإجابة (اختياري)';
  static const stats = 'الإحصائيات';
  static const studentsCount = 'عدد التلاميذ';
  static const completionRate = 'نسبة الإكمال';
  static const averageQuizScore = 'متوسط نتائج الكويزات';
  static const publish = 'نشر';
  static const unpublish = 'إخفاء';

  // ------------------------------------------------------------ فضاء التلميذ
  static const myLessons = 'دروسي';
  static const myProgress = 'تقدّمي';
  static const settings = 'الإعدادات';
  static const chooseLevel = 'اختر طورك الدراسي في هذه المادة';
  static const changeLevel = 'تغيير الطور';
  static const level = 'الطور';
  static const levelMiddle = 'متوسط';
  static const levelSecondary = 'ثانوي';
  static const levelHint =
      'ستظهر لك دروس هذا الطور فقط. يمكنك تغييره لاحقًا من الإعدادات.';
  static const next = 'التالي';
  static const previous = 'السابق';
  static const finishLesson = 'إنهاء الدرس';
  static const resumeLesson = 'متابعة من حيث توقّفت';
  static const correctAnswerFeedback = 'إجابة صحيحة ✅';
  static const wrongAnswerFeedback = 'إجابة خاطئة ❌';
  static const lessonsCompleted = 'دروس مكتملة';

  // ------------------------------------------------------------- التحميل
  static const download = 'تحميل';
  static const downloaded = 'محمّل';
  static const downloading = 'جارٍ التحميل';
  static const deleteDownload = 'حذف التحميل';
  static const deleteDownloadConfirm =
      'سيتم حذف ملفات هذا الدرس من الجهاز لتوفير المساحة. النصوص تبقى متاحة.';
  static const downloadNeedsInternet = 'التحميل يحتاج اتصالًا بالإنترنت.';
  static const storageUsed = 'المساحة المستعملة';
  static const deleteAllDownloads = 'حذف كل الدروس المحمَّلة';

  // ------------------------------------------------------------- المزامنة
  static const syncing = 'جارٍ المزامنة…';
  static const pendingSync = 'بانتظار الإرسال';
  static const lastSync = 'آخر مزامنة';
  static const syncNow = 'مزامنة الآن';
  static const syncFailed = 'تعذّرت المزامنة، سيُعاد المحاولة تلقائيًا.';
}
