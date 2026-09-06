import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// حالة الاتصال بالشبكة.
///
/// ملاحظة: `connectivity_plus` يخبرنا بوجود *واجهة شبكة* لا بوجود إنترنت
/// فعلي. لذلك تبقى كل عمليات الشبكة محميّة بمعالجة أخطاء، وهذه الفئة تُستعمل
/// فقط لتفادي محاولات عبثية وتشغيل المزامنة عند عودة الاتصال.
class NetworkInfo {
  NetworkInfo({Connectivity? connectivity, this.alwaysOnline = false})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// في وضع التجربة «الخادم» داخل التطبيق نفسه، فاشتراط وجود شبكة يمنع
  /// عرض الدروس بلا سبب. تبقى الأخطاء الحقيقية (تحميل الفيديو مثلًا)
  /// معالَجة عند حدوثها.
  final bool alwaysOnline;

  Future<bool> get isOnline async {
    if (alwaysOnline) return true;
    final result = await _connectivity.checkConnectivity();
    return _isOnline(result);
  }

  Stream<bool> get onStatusChange => alwaysOnline
      ? Stream<bool>.value(true)
      : _connectivity.onConnectivityChanged.map(_isOnline).distinct();

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
