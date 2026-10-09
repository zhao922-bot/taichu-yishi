import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taichu_yishi/main.dart' as app;

void main() {
  testWidgets('偏好初始化抛异常时仍以空偏好启动并记录错误', (tester) async {
    const channel = MethodChannel('plugins.flutter.io/shared_preferences');
    final messages = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) messages.add(message);
    };
    var preferenceReads = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      expect(call.method, 'getAll');
      preferenceReads++;
      throw PlatformException(code: 'read_failed', message: '测试偏好读取失败');
    });
    addTearDown(() {
      debugPrint = originalDebugPrint;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      SharedPreferences.setMockInitialValues({});
    });

    try {
      await tester.runAsync(app.main);
    } finally {
      debugPrint = originalDebugPrint;
    }
    await tester.pumpAndSettle();

    expect(preferenceReads, 1);
    expect(find.text('太初易筮'), findsOneWidget);
    expect(
      tester.widget<app.CyberYiApp>(find.byType(app.CyberYiApp)).preferences,
      isNull,
    );
    expect(messages, contains(contains('偏好初始化失败')));
    expect(messages, contains(contains('read_failed')));
    expect(tester.takeException(), isNull);
  });

  for (final method in [
    app.DivinationMethod.lueShi,
    app.DivinationMethod.traditional,
  ]) {
    testWidgets('${method.name}：按住签列后纵向滚动不改变分堆', (tester) async {
      await _pumpPileCard(tester, method);
      final scene = find.byType(app.RitualSplitScene);
      final rect = tester.getRect(scene);
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      final initialOffset = scrollable.position.pixels;
      final initialPile = tester.widget<app.RitualSplitScene>(scene).leftPile;
      final gesture = await tester.startGesture(
        Offset(rect.left + rect.width * .2, rect.center.dy),
      );
      // 超过 tap-down 超时后再纵向拖动，复现旧逻辑提前修改分堆。
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<app.RitualSplitScene>(scene).leftPile, initialPile);
      await gesture.moveBy(const Offset(0, -80));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(scrollable.position.pixels, greaterThan(initialOffset));
      expect(tester.widget<app.RitualSplitScene>(scene).leftPile, initialPile);
      expect(
        tester
            .widget<app.SplitQuantityBar>(find.byType(app.SplitQuantityBar))
            .leftPile,
        initialPile,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('${method.name}：确认点击和横向拖动仍能调整分堆', (tester) async {
      await _pumpPileCard(tester, method);
      final scene = find.byType(app.RitualSplitScene);
      final rect = tester.getRect(scene);
      final total = tester.widget<app.RitualSplitScene>(scene).total;
      final gesture = await tester.startGesture(
        Offset(rect.left + rect.width * .2, rect.center.dy),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<app.RitualSplitScene>(scene).leftPile, total ~/ 2);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        tester.widget<app.RitualSplitScene>(scene).leftPile,
        (total * .2).round(),
      );

      final drag = await tester.startGesture(
        Offset(rect.left + rect.width * .4, rect.center.dy),
      );
      await drag.moveBy(Offset(rect.width * .2, 0));
      await tester.pump();
      expect(
        tester.widget<app.RitualSplitScene>(scene).leftPile,
        (total * .6).round(),
      );
      await drag.moveBy(Offset(rect.width * .2, 0));
      await tester.pump();
      expect(
        tester.widget<app.RitualSplitScene>(scene).leftPile,
        (total * .8).round(),
      );
      await drag.up();
      await tester.pumpAndSettle();
      expect(
        tester.widget<app.RitualSplitScene>(scene).leftPile,
        (total * .8).round(),
      );
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpPileCard(
  WidgetTester tester,
  app.DivinationMethod method,
) async {
  final session = app.CastingSession(
    method: method,
    question: '手势回归测试',
    gender: app.Gender.male,
    corpus: const app.SourceCorpus({}),
  )..advance();
  final card = method == app.DivinationMethod.lueShi
      ? app.LueShiPileCard(
          session: session,
          initialMode: app.SplitMode.manual,
          onModeChanged: (_) {},
          onConfirm: (_) {},
        )
      : app.TraditionalYarrowCard(
          session: session,
          initialMode: app.SplitMode.manual,
          onModeChanged: (_) {},
          onConfirm: (_) {},
        );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(children: [card, const SizedBox(height: 1000)]),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
