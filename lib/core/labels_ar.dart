/// نصوص وأرقام العرض بالعربية (الأرقام بالصيغة الغربية 9,040 كما في التصميم).

/// تجميع الآلاف بفاصلة: 9040 ← 9,040 ، -86000 ← -86,000.
String formatThousands(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}

/// السطر تحت المجموع الكلي في شاشة الإنتاج.
String productionDiffLabel(int diff) {
  if (diff > 0) {
    return 'إنتاج اليوم زائد عن المفروض بـ ${formatThousands(diff)} عيشة';
  }
  if (diff < 0) {
    return 'إنتاج اليوم ناقص عن المفروض بـ ${formatThousands(-diff)} عيشة';
  }
  return 'إنتاج اليوم مطابق للمفروض';
}

/// تنبيه فرق البنكجي (يظهر فقط إذا اختلفت التوريدة عن المطلوب).
String bankajiDiffLabel(int diff) {
  if (diff == 0) {
    return '';
  }
  if (diff > 0) {
    return 'تنبيه: على البنكجي فرق ${formatThousands(diff)}';
  }
  return 'تنبيه: البنكجي ورَّد زيادة ${formatThousands(-diff)}';
}

/// المتوسط للجوال: عدد صحيح إن لم يكن فيه كسر (904)، وإلا بخانة عشرية واحدة (903.5).
String formatAverage(double value) {
  final rounded = (value * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) {
    return formatThousands(rounded.round());
  }
  return rounded.toStringAsFixed(1);
}

const List<String> _weekdaysAr = [
  'الإثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

const List<String> _monthsAr = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

final RegExp _isoDateParts = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// التاريخ بالعربية كما في التصميم: `2026-11-19` ← «الخميس 19 نوفمبر 2026».
/// الأرقام غربية. نص غير صالح يرجع كما هو.
String arabicDateLabel(String isoDate) {
  final match = _isoDateParts.firstMatch(isoDate);
  if (match == null) {
    return isoDate;
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return isoDate;
  }
  final weekday = DateTime.utc(year, month, day).weekday;
  return '${_weekdaysAr[weekday - 1]} $day ${_monthsAr[month - 1]} $year';
}

/// عدد الجوالات مع المعدود: «1 جوال» «2 جوال» «3 جوالات» … «10 جوالات» «11 جوال».
String sacksCountLabel(int count) {
  final isFew = count >= 3 && count <= 10;
  return '$count ${isFew ? 'جوالات' : 'جوال'}';
}
