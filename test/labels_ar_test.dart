import 'package:flutter_test/flutter_test.dart';
import 'package:makhbazak/core/labels_ar.dart';

void main() {
  group('arabicDateLabel', () {
    test('يطابق التصميم: الخميس 19 نوفمبر 2026', () {
      expect(arabicDateLabel('2026-11-19'), 'الخميس 19 نوفمبر 2026');
    });

    test('أيام الأسبوع والأشهر الأخرى، وتُحذف الصفر من اليوم', () {
      expect(arabicDateLabel('2026-11-24'), 'الثلاثاء 24 نوفمبر 2026');
      expect(arabicDateLabel('2026-11-21'), 'السبت 21 نوفمبر 2026');
      expect(arabicDateLabel('2026-01-05'), 'الإثنين 5 يناير 2026');
      expect(arabicDateLabel('2026-12-31'), 'الخميس 31 ديسمبر 2026');
    });

    test('نص غير صالح يرجع كما هو', () {
      expect(arabicDateLabel('بلا تاريخ'), 'بلا تاريخ');
      expect(arabicDateLabel('2026-13-01'), '2026-13-01');
      expect(arabicDateLabel('2026-11-00'), '2026-11-00');
    });
  });

  test('sacksCountLabel', () {
    expect(sacksCountLabel(1), '1 جوال');
    expect(sacksCountLabel(2), '2 جوال');
    expect(sacksCountLabel(3), '3 جوالات');
    expect(sacksCountLabel(10), '10 جوالات');
    expect(sacksCountLabel(11), '11 جوال');
  });
}
