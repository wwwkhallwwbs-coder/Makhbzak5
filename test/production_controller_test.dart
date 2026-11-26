import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:makhbazak/data/app_database.dart';
import 'package:makhbazak/data/day_repository.dart';
import 'package:makhbazak/data/device_repository.dart';
import 'package:makhbazak/data/models.dart';
import 'package:makhbazak/data/settings_repository.dart';
import 'package:makhbazak/features/production/production_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// أرقام المواصفة §4.1: المجموع 9,040، المفروض 9,000، الفرق +40، المتوسط 904.
const List<int> _specSacks = [905, 900, 910, 895, 902, 908, 899, 905, 903, 913];

void main() {
  sqfliteFfiInit();

  late Database db;
  late DeviceInfo device;
  late DayRepository days;
  late SettingsRepository settings;
  late ProductionController controller;
  late String schemaSql;

  // «اليوم» ثابت في الاختبارات: 2026-11-24، وبداية الوكيل 2026-11-23.
  final DateTime today = DateTime(2026, 11, 24, 10);

  setUpAll(() {
    schemaSql = File('assets/db/schema.sql').readAsStringSync();
  });

  setUp(() async {
    db = await openAppDatabase(
      schemaSql: schemaSql,
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    device = await DeviceRepository(db).activateAsAgent(
      codeHash: 'a' * 64,
      bakeryName: 'مخبز التجربة',
      agentName: 'وكيل التجربة',
      startedAt: '2026-11-23',
    );
    settings = SettingsRepository(
      db,
      bakeryId: device.bakeryId!,
      deviceId: device.id,
    );
    days = DayRepository(
      db,
      bakeryId: device.bakeryId!,
      agentId: device.agentId!,
      deviceId: device.id,
    );
    controller = ProductionController(days: days, clock: () => today);
  });

  tearDown(() async {
    controller.dispose();
    await db.close();
  });

  Future<void> setPrices() async {
    await settings.set(SettingKeys.windowPrice, 100);
    await settings.set(SettingKeys.distributionPrice, 90);
  }

  Future<void> openToday() async {
    await setPrices();
    await controller.load();
    await controller.openDay();
  }

  group('التحميل وفتح اليوم', () {
    test('يبدأ بتاريخ اليوم ويوم غير مفتوح', () async {
      await setPrices();
      await controller.load();

      expect(controller.loading, isFalse);
      expect(controller.loadFailed, isFalse);
      expect(controller.date, '2026-11-24');
      expect(controller.isToday, isTrue);
      expect(controller.day, isNull);
      expect(controller.summary, isNull);
      expect(controller.sacks, isEmpty);
      expect(controller.startDate, '2026-11-23');
    });

    test('فتح اليوم بلا أسعار لا ينشئ يوماً ويطلب الإعدادات', () async {
      await controller.load();
      await controller.openDay();

      expect(controller.needsSettings, isTrue);
      expect(controller.day, isNull);
      expect(controller.error, isNull);
      final rows = await db.query('days');
      expect(rows, isEmpty);
    });

    test('بعد إدخال الأسعار يُفتح اليوم بنسخها ومستهدف الإعدادات', () async {
      await controller.load();
      await controller.openDay();
      expect(controller.needsSettings, isTrue);

      await setPrices();
      await controller.openDay();

      expect(controller.needsSettings, isFalse);
      final day = controller.day;
      expect(day, isNotNull);
      expect(day!.date, '2026-11-24');
      expect(day.windowPrice, 100);
      expect(day.distributionPrice, 90);
      expect(day.targetPerSack, 900);
      expect(day.status, 'open');
      expect(controller.summary!.sacks, 0);
      expect(controller.rowCount, 0);
    });

    test('فتح اليوم مرتين لا ينشئ يومين', () async {
      await openToday();
      final first = controller.day!.id;
      await controller.openDay();

      expect(controller.day!.id, first);
      final rows = await db.query('days');
      expect(rows.length, 1);
    });

    test('ensureLoaded لا يعيد التحميل بعد نجاحه', () async {
      await setPrices();
      await controller.ensureLoaded();
      await controller.openDay();
      await controller.ensureLoaded();

      expect(controller.day, isNotNull);
    });
  });

  group('عدد الجوالات والخانات', () {
    test('كتابة العدد تُظهر خانات فارغة ولا تكتب شيئاً في القاعدة', () async {
      await openToday();
      await controller.setSackCount(10);

      expect(controller.rowCount, 10);
      expect(controller.filledCount, 0);
      expect(controller.loavesOf(3), isNull);
      expect(controller.summary!.sacks, 0);
      expect(controller.summary!.total, 0);
      expect(controller.error, isNull);
      expect(await db.query('sack_entries'), isEmpty);
    });

    test('تعبئة جوال في الوسط لا تنشئ الباقي، والخانات تبقى', () async {
      await openToday();
      await controller.setSackCount(5);
      await controller.setLoaves(3, 900);

      expect(controller.rowCount, 5);
      expect(controller.filledCount, 1);
      expect(controller.sacks.single.seq, 3);
      expect(controller.loavesOf(3), 900);
      expect(controller.loavesOf(1), isNull);
      // الحساب على المعبّأ فقط.
      expect(controller.summary!.sacks, 1);
      expect(controller.summary!.expected, 900);
    });

    test('تعبئة جوال أكبر من العدد المكتوب يوسّع الخانات تلقائياً', () async {
      await openToday();
      await controller.setSackCount(2);
      await controller.setLoaves(4, 880);

      expect(controller.rowCount, 4);
    });

    test('تقليل العدد دون آخر جوال معبّأ مرفوض، وبعد المسح يُقبل', () async {
      await openToday();
      await controller.setSackCount(5);
      await controller.setLoaves(4, 900);
      await controller.setSackCount(3);

      expect(controller.error, contains('4'));
      expect(controller.rowCount, 5);

      await controller.clearSack(4);
      await controller.setSackCount(3);
      expect(controller.error, isNull);
      expect(controller.rowCount, 3);
    });

    test('الحد الأعلى 100 والعدد السالب مرفوضان', () async {
      await openToday();
      await controller.setSackCount(101);
      expect(controller.error, isNotNull);
      expect(controller.rowCount, 0);

      await controller.setSackCount(-1);
      expect(controller.error, isNotNull);

      await controller.setSackCount(maxSacksPerDay);
      expect(controller.error, isNull);
      expect(controller.rowCount, maxSacksPerDay);
    });

    test('إضافة جوال تضيف خانة فارغة، ونقرتان سريعتان تضيفان خانتين', () async {
      await openToday();
      await controller.setSackCount(2);
      await controller.addRow();
      expect(controller.rowCount, 3);

      await Future.wait(<Future<void>>[controller.addRow(), controller.addRow()]);
      expect(controller.rowCount, 5);
      expect(await db.query('sack_entries'), isEmpty);
    });

    test('العدد يبقى عند فتح الشاشة من جديد إذا مُرّرت الخريطة نفسها', () async {
      await setPrices();
      final shared = <String, int>{};
      final first = ProductionController(
        days: days,
        clock: () => today,
        plannedCounts: shared,
      );
      await first.load();
      await first.openDay();
      await first.setSackCount(8);
      first.dispose();

      final second = ProductionController(
        days: days,
        clock: () => today,
        plannedCounts: shared,
      );
      await second.load();
      expect(second.rowCount, 8);
      second.dispose();

      // بلا الخريطة المشتركة يُستنتج العدد من آخر جوال معبّأ فقط.
      final third = ProductionController(days: days, clock: () => today);
      await third.load();
      expect(third.rowCount, 0);
      third.dispose();
    });

    test('الكتابة والعدد قبل فتح اليوم يُرفضان برسالة', () async {
      await setPrices();
      await controller.load();

      await controller.setLoaves(1, 900);
      expect(controller.error, 'افتح اليوم أولاً');
      controller.dismissError();
      expect(controller.error, isNull);

      await controller.setSackCount(5);
      expect(controller.error, 'افتح اليوم أولاً');
      expect(await db.query('sack_entries'), isEmpty);
    });
  });

  group('قطعيات الجوالات والملخص', () {
    test('أرقام المواصفة: 9,040 والمفروض 9,000 والفرق +40 والمتوسط 904', () async {
      await openToday();
      await controller.setSackCount(10);
      for (var i = 0; i < _specSacks.length; i++) {
        await controller.setLoaves(i + 1, _specSacks[i]);
      }

      final summary = controller.summary!;
      expect(controller.rowCount, 10);
      expect(controller.filledCount, 10);
      expect(controller.sacks.first.seq, 1);
      expect(controller.sacks.last.seq, 10);
      expect(summary.sacks, 10);
      expect(summary.total, 9040);
      expect(summary.expected, 9000);
      expect(summary.diff, 40);
      expect(summary.average, 904.0);
      expect(controller.error, isNull);
    });

    test('تعديل جوال موجود لا يضيف جوالاً', () async {
      await openToday();
      await controller.setLoaves(1, 900);
      await controller.setLoaves(2, 910);
      await controller.setLoaves(1, 930);

      expect(controller.sacks.length, 2);
      expect(controller.loavesOf(1), 930);
      expect(controller.summary!.total, 1840);
    });

    test('مسح خانة يُخرج الجوال من الحساب ويُبقي الخانة ويبقي الصف في القاعدة', () async {
      await openToday();
      await controller.setLoaves(1, 900);
      await controller.setLoaves(2, 880);
      await controller.clearSack(2);

      expect(controller.rowCount, 2);
      expect(controller.filledCount, 1);
      expect(controller.loavesOf(2), isNull);
      expect(controller.summary!.total, 900);
      expect((await db.query('sack_entries')).length, 2);

      await controller.setLoaves(2, 895);
      expect(controller.filledCount, 2);
      expect(controller.loavesOf(2), 895);
      expect((await db.query('sack_entries')).length, 2);
    });

    test('مسح خانة فارغة لا يفعل شيئاً ولا يخطئ', () async {
      await openToday();
      await controller.setSackCount(3);
      await controller.clearSack(2);

      expect(controller.filledCount, 0);
      expect(controller.error, isNull);
    });

    test('كتابات سريعة متتابعة بلا انتظار تُنفَّذ بترتيبها', () async {
      await openToday();
      final writes = <Future<void>>[
        for (var i = 0; i < 6; i++) controller.setLoaves(i + 1, 900 + i),
      ];
      await Future.wait(writes);

      expect(controller.sacks.map((e) => e.seq).toList(), [1, 2, 3, 4, 5, 6]);
      expect(
        controller.sacks.map((e) => e.loaves).toList(),
        [900, 901, 902, 903, 904, 905],
      );
      expect(controller.rowCount, 6);
      expect(controller.error, isNull);
    });

    test('عدد سالب أو رقم جوال خارج النطاق يُرفض برسالة ولا يغيّر شيئاً', () async {
      await openToday();
      await controller.setLoaves(1, 900);

      await controller.setLoaves(1, -5);
      expect(controller.error, isNotNull);
      expect(controller.loavesOf(1), 900);

      controller.dismissError();
      await controller.setLoaves(0, 5);
      expect(controller.error, isNotNull);
      controller.dismissError();
      await controller.setLoaves(maxSacksPerDay + 1, 5);
      expect(controller.error, isNotNull);
      expect(controller.filledCount, 1);
    });

    test('المتحكم يُبلغ المستمعين عند كل تغيير', () async {
      await openToday();
      var calls = 0;
      controller.addListener(() => calls++);
      await controller.setLoaves(1, 900);

      expect(calls, greaterThan(0));
    });
  });

  group('اليوم المقفل', () {
    Future<void> lockToday() async {
      await db.rawUpdate(
        "UPDATE days SET status = 'locked', locked_at = '2026-11-24T20:00:00Z' WHERE id = ?",
        [controller.day!.id],
      );
    }

    test('يوم مقفل عند التحميل: يظهر مقفلاً وكل كتابة عليه مرفوضة', () async {
      await openToday();
      await controller.setLoaves(1, 900);
      await lockToday();
      await controller.load();

      expect(controller.isLocked, isTrue);
      await controller.setLoaves(1, 1000);
      expect(controller.error, lockedDayMessage);
      controller.dismissError();
      await controller.setLoaves(2, 1000);
      expect(controller.error, lockedDayMessage);
      controller.dismissError();
      await controller.clearSack(1);
      expect(controller.error, lockedDayMessage);
      controller.dismissError();
      await controller.setSackCount(5);
      expect(controller.error, lockedDayMessage);

      expect(controller.sacks.single.loaves, 900);
      expect(controller.summary!.total, 900);
    });

    test('قُفل اليوم بعد التحميل: القاعدة نفسها ترفض والرسالة واحدة', () async {
      await openToday();
      await controller.setLoaves(1, 900);
      // المتحكم ما زال يظن اليوم مفتوحاً، فيصل الرفض من trigger القاعدة.
      await lockToday();
      await controller.setLoaves(1, 1000);

      expect(controller.error, lockedDayMessage);
      final rows = await db.query('sack_entries');
      expect(rows.single['loaves'], 900);
    });
  });

  group('التنقل بين التواريخ', () {
    test('لا بعد اليوم ولا قبل بداية الوكيل', () async {
      await setPrices();
      await controller.load();

      expect(controller.canGoNext, isFalse);
      expect(controller.canGoPrevious, isTrue);

      await controller.goToNext();
      expect(controller.date, '2026-11-24');

      await controller.goToPrevious();
      expect(controller.date, '2026-11-23');
      expect(controller.isToday, isFalse);
      expect(controller.canGoPrevious, isFalse);
      expect(controller.canGoNext, isTrue);

      await controller.goToPrevious();
      expect(controller.date, '2026-11-23');

      await controller.goToNext();
      expect(controller.date, '2026-11-24');
    });

    test('تاريخ خارج النطاق يُقيَّد إلى اليوم أو بداية الوكيل', () async {
      await setPrices();
      await controller.load('2026-12-31');
      expect(controller.date, '2026-11-24');

      await controller.load('2020-01-01');
      expect(controller.date, '2026-11-23');
    });

    test('لكل يوم جوالاته وعدده، وفتح يوم سابق لا يمس اليوم الحالي', () async {
      await openToday();
      await controller.setSackCount(5);
      await controller.setLoaves(1, 900);
      await controller.goToPrevious();

      expect(controller.date, '2026-11-23');
      expect(controller.day, isNull);
      expect(controller.sacks, isEmpty);
      expect(controller.rowCount, 0);

      await controller.openDay();
      await controller.setLoaves(1, 870);
      await controller.setLoaves(2, 880);
      expect(controller.summary!.total, 1750);
      expect(controller.rowCount, 2);

      await controller.goToNext();
      expect(controller.date, '2026-11-24');
      expect(controller.sacks.single.loaves, 900);
      expect(controller.summary!.total, 900);
      expect(controller.rowCount, 5);
      expect((await db.query('days')).length, 2);
    });

    test('يوم سابق يُنسخ إليه سعر الإعدادات الحالي عند فتحه، لا أسعار يوم آخر', () async {
      await openToday();
      await settings.set(SettingKeys.windowPrice, 120);
      await controller.goToPrevious();
      await controller.openDay();

      expect(controller.day!.windowPrice, 120);
      final todayDay = await days.find('2026-11-24');
      expect(todayDay!.windowPrice, 100);
    });
  });
}
