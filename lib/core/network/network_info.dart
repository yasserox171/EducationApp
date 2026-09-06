import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// حالة الاتصال بالشبكة.
///
/// ملاحظة: `connectivity_plus` يخبرنا بوجود *واجهة شبكة* لا بوجود إنترنت
/// فعلي. لذلك تبقى كل عمليات الشبكة محميّة بمعالجة أخطاء، وهذه الفئة تُستعمل
/// فقط لتفادي محاولات عبثية وتشغيل المزامنة عند عودة الاتصال.
class NetworkInfo {
  NetworkInfo([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Future<bool> get isOnline async {
    final result = await _connectivity.checkConnectivity();
    return _isOnline(result);
  }

  Stream<bool> get onStatusChange => _connectivity.onConnectivityChanged
      .map(_isOnline)
      .distinct();

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
