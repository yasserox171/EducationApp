import 'package:intl/intl.dart';

/// تنسيقات عربية للأحجام والمدد والنسب.
class Formatters {
  const Formatters._();

  static final NumberFormat _percent = NumberFormat.percentPattern('ar');
  static final DateFormat _date = DateFormat('d MMMM y', 'ar');

  static String bytes(int value) {
    if (value <= 0) return '0 م.ب';
    const units = ['بايت', 'ك.ب', 'م.ب', 'غ.ب'];
    var size = value.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    final text = unit == 0 ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
    return '$text ${units[unit]}';
  }

  static String duration(int seconds) {
    if (seconds <= 0) return '00:00';
    final d = Duration(seconds: seconds);
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$secs';
    }
    return '$minutes:$secs';
  }

  /// نسبة من 0.0 إلى 1.0 → «٪٤٥».
  static String percent(double ratio) =>
      _percent.format(ratio.clamp(0.0, 1.0).toDouble());

  static String date(DateTime value) => _date.format(value);
}
