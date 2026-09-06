/// ثوابت واجهة وسلوك لا علاقة لها بالخادم (لا تُوضع في `.env`).
class AppConstants {
  const AppConstants._();

  // ---------------------------------------------------------------- الوسائط
  /// أقصى ارتفاع لصندوق الفيديو أثناء التشغيل داخل الدرس.
  /// يمنع الفيديوهات العمودية من ابتلاع الشاشة كاملة.
  static const double maxVideoPlayerHeight = 320;

  /// نسبة العرض/الارتفاع الافتراضية عند عدم معرفة أبعاد الفيديو بعد.
  static const double defaultVideoAspectRatio = 16 / 9;

  /// أقصى عرض للمحتوى على الشاشات العريضة (لوحة، ويب لاحقًا).
  static const double maxContentWidth = 720;

  // ---------------------------------------------------------------- المزامنة
  /// المدة الدنيا بين محاولتي مزامنة تلقائية.
  static const Duration minSyncInterval = Duration(minutes: 2);

  /// أقصى عدد محاولات لعملية واحدة في طابور الإرسال قبل وسمها كفاشلة.
  static const int maxOutboxAttempts = 8;

  /// التأخير الأساسي في التراجع الأسّي (exponential backoff).
  static const Duration outboxBaseBackoff = Duration(seconds: 15);

  /// أقصى تأخير بين محاولتين لعملية واحدة.
  static const Duration outboxMaxBackoff = Duration(hours: 2);

  /// صلاحية البيانات المخزّنة محليًا قبل محاولة تحديثها من الخادم.
  static const Duration contentStaleAfter = Duration(hours: 6);

  // ---------------------------------------------------------------- التحميل
  /// عدد الملفات التي تُحمَّل بالتوازي داخل الدرس الواحد.
  static const int parallelDownloads = 1;

  // ---------------------------------------------------------------- عام
  static const int quizMinOptions = 2;
  static const int quizMaxOptions = 6;
  static const int minPasswordLength = 6;
}
