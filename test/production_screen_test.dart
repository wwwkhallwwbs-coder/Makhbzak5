import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makhbazak/data/app_database.dart';
import 'package:makhbazak/data/day_repository.dart';
import 'package:makhbazak/data/device_repository.dart';
import 'package:makhbazak/data/settings_repository.dart';
import 'package:makhbazak/features/production/production_controller.dart';
import 'package:makhbazak/features/production/production_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const List<int> _specSacks = [905, 900, 910, 895, 902, 908, 899, 905, 903, 913];

const ValueKey<String> _countKey = ValueKey<String>('sack-count');

/// اختبارات عرض الشاشة. قراءة القاعدة الحقيقية (ffi) تجري داخل runAsync لأنها
/// دخل/خرج فعلي لا يعمل داخل الزمن المزيَّف، ثم تُعرض الحالة المحمّلة. أما
/// كتابة عدد الجوالات فلا تلمس القاعدة، فيمكن تجربتها بالنقر والكتابة.
void main() {
  sqfliteFfiInit();

  late String schemaSql;
  final List<Database> opened = <Database>[];

  setUpAll(() {
    schemaSql = File('assets/db/schema.sql').readAsStringSync();
  });

  // الإغلاق دخل/خرج فعلي، فيجري داخل runAsync في آخر كل اختبار.
  Future<void> closeDatabases(WidgetTester tester) async {
    await tester.runAsync<void>(() async {
      for (final db in opened) {
        await db.close();
      }
      opened.clear();
    });
  }

  // شاشة طويلة ليُبنى كل الصف دفعة واحدة (القائمة تبني الظاهر فقط).
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<ProductionController> prepare(
    WidgetTester tester, {
    required Future<void> Function(Database db, DayRepository days, String dayId)
        fill,
    bool openDay = true,
    int planned = 0,
  }) async {
    final controller = await tester.runAsync<ProductionController>(() async {
      final db = await openAppDatabase(
        schemaSql: schemaSql,
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      opened.add(db);
      final device = await DeviceRepository(db).activateAsAgent(
        codeHash: 'a' * 64,
        bakeryName: 'مخبز التجربة',
        agentName: 'وكيل التجربة',
        startedAt: '2026-11-01',
      );
      final settings = SettingsRepository(
        db,
        bakeryId: device.bakeryId!,
        deviceId: device.id,
      );
      await settings.set(SettingKeys.windowPrice, 100);
      await settings.set(SettingKeys.distributionPrice, 90);
      final days = DayRepository(
        db,
        bakeryId: device.bakeryId!,
        agentId: device.agentId!,
        deviceId: device.id,
      );
      final production = ProductionController(
        days: days,
        clock: () => DateTime(2026, 11, 24, 10),
      );
      await production.load();
      if (openDay) {
        await production.openDay();
        if (planned > 0) {
          await production.setSackCount(planned);
        }
        await fill(db, days, production.day!.id);
        await production.load();
      }
      return production;
    });
    return controller!;
  }

  Future<void> show(WidgetTester tester, ProductionController controller) {
    return tester.pumpWidget(
      MaterialApp(
        home: ProductionScreen(
          controller: controller,
          onOpenSettings: () async {},
        ),
      ),
    );
  }

  testWidgets('يعرض أرقام المواصفة كما في التصميم', (tester) async {
    useTallScreen(tester);
    final controller = await prepare(
      tester,
      fill: (db, days, dayId) async {
        for (var i = 0; i < _specSacks.length; i++) {
          await days.setSack(dayId, i + 1, _specSacks[i]);
        }
      },
    );
    await show(tester, controller);

    // الترويسة: العنوان والتاريخ بالعربية.
    expect(find.text('الإنتاج اليومي'), findsOneWidget);
    expect(find.text('الثلاثاء 24 نوفمبر 2026 · اليوم'), findsOneWidget);

    // ثلاث خانات: المجموع والمتوسط والمستهدف.
    expect(find.text('المجموع الكلي'), findsOneWidget);
    expect(find.text('9,040'), findsOneWidget);
    expect(find.text('المتوسط'), findsOneWidget);
    expect(find.text('904'), findsOneWidget);
    expect(find.text('المستهدف'), findsOneWidget);

    // سطر الفرق والمفروض والشارة.
    expect(
      find.text('إنتاج اليوم زائد عن المفروض بـ 40 عيشة'),
      findsOneWidget,
    );
    expect(find.text('المفروض 9,000 (10 جوالات × 900)'), findsOneWidget);
    expect(find.text('+40'), findsOneWidget);

    // العنوان «القطعيات» وعدد الجوالات وعشر خانات مرقمة.
    expect(find.text('القطعيات'), findsOneWidget);
    expect(find.text('عدد الجوالات'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(_countKey)).controller!.text, '10');
    expect(find.byType(TextField), findsNWidgets(11));
    expect(find.text('إضافة جوال'), findsOneWidget);
    expect(find.textContaining('سُجّل'), findsNothing);
    await closeDatabases(tester);
  });

  testWidgets('يوم مفتوح بلا جوالات: يُطلب العدد أولاً ولا خانات ولا سطر فرق', (tester) async {
    useTallScreen(tester);
    final controller = await prepare(tester, fill: (db, days, dayId) async {});
    await show(tester, controller);

    expect(find.text('اكتب عدد الجوالات لتظهر خانات القطعيات'), findsOneWidget);
    expect(find.text('عدد الجوالات'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('عن المفروض'), findsNothing);
    expect(find.textContaining('مطابق للمفروض'), findsNothing);
    expect(find.text('إضافة جوال'), findsNothing);
    await closeDatabases(tester);
  });

  testWidgets('كتابة العدد تُظهر خانات مرقمة، و«إضافة جوال» تزيد خانة', (tester) async {
    useTallScreen(tester);
    final controller = await prepare(tester, fill: (db, days, dayId) async {});
    await show(tester, controller);

    await tester.enterText(find.byKey(_countKey), '3');
    await tester.pump();
    await tester.pump();

    // خانة العدد + ثلاث خانات، وكلها فارغة.
    expect(find.byType(TextField), findsNWidgets(4));
    expect(find.text('سُجّل 0 من 3'), findsOneWidget);
    expect(find.text('اكتب عدد الجوالات لتظهر خانات القطعيات'), findsNothing);

    await tester.tap(find.text('إضافة جوال'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(TextField), findsNWidgets(5));
    expect(find.text('سُجّل 0 من 4'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(_countKey)).controller!.text, '4');
    await closeDatabases(tester);
  });

  testWidgets('بعض الخانات معبأة: يظهر «سُجّل 2 من 5» والحساب على المعبأ فقط', (tester) async {
    useTallScreen(tester);
    final controller = await prepare(
      tester,
      planned: 5,
      fill: (db, days, dayId) async {
        await days.setSack(dayId, 1, 905);
        await days.setSack(dayId, 2, 895);
      },
    );
    await show(tester, controller);

    expect(find.text('سُجّل 2 من 5'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(6));
    expect(find.text('1,800'), findsOneWidget);
    expect(find.text('المفروض 1,800 (2 جوال × 900)'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    await closeDatabases(tester);
  });

  testWidgets('اليوم غير المفتوح: زر فتح اليوم', (tester) async {
    useTallScreen(tester);
    final controller = await prepare(
      tester,
      openDay: false,
      fill: (db, days, dayId) async {},
    );
    await show(tester, controller);

    expect(find.text('لم يُفتح هذا اليوم بعد'), findsOneWidget);
    expect(find.text('فتح اليوم'), findsOneWidget);
    expect(find.text('عدد الجوالات'), findsNothing);
    expect(find.text('إضافة جوال'), findsNothing);
    await closeDatabases(tester);
  });

  testWidgets('اليوم المقفل: شريط القفل بلا حقول إدخال ولا عدد ولا إضافة', (tester) async {
    useTallScreen(tester);
    final controller = await prepare(
      tester,
      fill: (db, days, dayId) async {
        await days.setSack(dayId, 1, 905);
        await db.rawUpdate(
          "UPDATE days SET status = 'locked', locked_at = '2026-11-24T20:00:00Z' WHERE id = ?",
          [dayId],
        );
      },
    );
    await show(tester, controller);

    expect(find.text(lockedDayMessage), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('عدد الجوالات'), findsNothing);
    expect(find.text('إضافة جوال'), findsNothing);
    expect(find.text('القطعيات'), findsOneWidget);
    expect(find.text('905'), findsWidgets);
    await closeDatabases(tester);
  });
}
