import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taichu_yishi/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SourceCorpus corpus;

  setUpAll(() async {
    // Layout regressions depend on the shipped Chinese font's real metrics.
    final loader = FontLoader(kAppFont)
      ..addFont(rootBundle.load('assets/fonts/NotoSerifCJKsc-Regular.otf'));
    await loader.load();
    corpus = await SourceCorpus.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  for (final method in DivinationMethod.values) {
    for (final gender in Gender.values) {
      test('A001: ${method.name}/${gender.name} 每一步恢复后都能读取提示', () {
        var session = CastingSession(
          method: method,
          question: '逐步恢复',
          gender: gender,
          corpus: corpus,
        );
        while (!session.isComplete) {
          session = CastingSession.fromJson(
            jsonDecode(jsonEncode(session.toJson())) as Map<String, dynamic>,
            corpus,
          );
          expect(session.nextInstruction, isNotEmpty);
          if (method == DivinationMethod.sixtyFourSix && session.isPrepared) {
            if (session.methodStepsCompleted == 0) {
              expect(session.nextInstruction, '第 1 步：从 64 卦签中抽取本卦。');
            } else {
              expect(session.nextInstruction, contains('抽取动爻'));
              expect(
                session.nextInstruction,
                contains(gender == Gender.male ? '左手' : '右手'),
              );
            }
          }
          session.advance(leftPile: 1);
        }
        expect(session.completedSteps, session.totalSteps);
        expect(session.nextInstruction, contains('已完成'));
      });
    }
  }

  for (final gender in Gender.values) {
    testWidgets('A001: 64 卦签 ${gender.name} 从准备存档恢复并完成两次抽签', (tester) async {
      _setViewport(tester, const Size(360, 640));
      final session = CastingSession(
        method: DivinationMethod.sixtyFourSix,
        question: '恢复后抽签',
        gender: gender,
        corpus: corpus,
      )..advance();
      SharedPreferences.setMockInitialValues({
        'casting_session': jsonEncode(session.toJson()),
      });
      final preferences = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        CyberYiApp(corpus: corpus, preferences: preferences),
      );

      for (final label in ['抽取本卦签', '抽取动爻签']) {
        final button = find.widgetWithText(FilledButton, label);
        await tester.scrollUntilVisible(
          button,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(button.hitTestable(), findsOneWidget);
        await tester.tap(button);
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        if (label == '抽取本卦签') {
          final restored = CastingSession.fromJson(
            jsonDecode(preferences.getString('casting_session')!)
                as Map<String, dynamic>,
            corpus,
          );
          expect(restored.completedSteps, 2);
          expect(restored.result, isNull);
        }
      }
      expect(preferences.getString('casting_session'), isNull);
      await tester.scrollUntilVisible(
        find.byType(ResultCard),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      final result = tester.widget<ResultCard>(find.byType(ResultCard)).result;
      expect(result.question, '恢复后抽签');
      expect(result.movingLines, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  for (final key in ['appearance', 'casting_session']) {
    for (final invalid in <Object>[
      123,
      <String>['旧数据'],
    ]) {
      testWidgets('A002: $key 为 ${invalid.runtimeType} 时清理坏值并保留另一项偏好', (
        tester,
      ) async {
        final savedSession = jsonEncode(
          (CastingSession(
            method: DivinationMethod.lueShi,
            question: '有效存档',
            gender: Gender.female,
            corpus: corpus,
          )..advance()).toJson(),
        );
        SharedPreferences.setMockInitialValues({
          'appearance': 'yang',
          'casting_session': savedSession,
          'unrelated': '保留',
          key: invalid,
        });
        final preferences = await SharedPreferences.getInstance();
        await tester.pumpWidget(
          CyberYiApp(corpus: corpus, preferences: preferences),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(DivinationPage), findsOneWidget);
        expect(preferences.containsKey(key), isFalse);
        expect(preferences.getString('unrelated'), '保留');
        if (key == 'appearance') {
          expect(
            tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
            ThemeMode.system,
          );
          expect(preferences.getString('casting_session'), savedSession);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            '有效存档',
          );
        } else {
          expect(
            tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
            ThemeMode.light,
          );
          expect(preferences.getString('appearance'), 'yang');
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            isEmpty,
          );
        }
      });
    }
  }

  testWidgets('A002: 两个偏好同时损坏时仍正常启动且都被清理', (tester) async {
    SharedPreferences.setMockInitialValues({
      'appearance': true,
      'casting_session': 1.5,
    });
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      CyberYiApp(corpus: corpus, preferences: preferences),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DivinationPage), findsOneWidget);
    expect(preferences.getKeys(), isEmpty);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
  });

  for (final size in [const Size(360, 640), const Size(640, 360)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('A003: 方法说明在 $size、字体 $scale 下能滚动到末尾', (tester) async {
        _setViewport(tester, size, scale: scale);
        await tester.pumpWidget(CyberYiApp(corpus: corpus));
        await tester.tap(find.byTooltip('方法说明'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final lastParagraph = find.textContaining('八卦签、64 卦签、384 爻签');
        await Scrollable.ensureVisible(
          tester.element(lastParagraph),
          alignment: 1,
        );
        await tester.pumpAndSettle();
        expect(
          tester.getRect(lastParagraph).bottom,
          lessThanOrEqualTo(tester.getRect(find.byType(BottomSheet)).bottom),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final method in [
    DivinationMethod.lueShi,
    DivinationMethod.traditional,
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('A004: ${method.name} 在窄屏字体 $scale 下数量可读且端点不能确认', (
        tester,
      ) async {
        _setViewport(tester, const Size(360, 640), scale: scale);
        final session = CastingSession(
          method: method,
          question: '分堆数量',
          gender: Gender.male,
          corpus: corpus,
        )..advance();
        final card = method == DivinationMethod.lueShi
            ? LueShiPileCard(
                session: session,
                initialMode: SplitMode.manual,
                onModeChanged: (_) {},
                onConfirm: (_) {},
              )
            : TraditionalYarrowCard(
                session: session,
                initialMode: SplitMode.manual,
                onModeChanged: (_) {},
                onConfirm: (_) {},
              );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: kAppFont),
            home: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(18),
                children: [card],
              ),
            ),
          ),
        );
        for (final value in [0, 49, 24]) {
          tester.widget<Slider>(find.byType(Slider)).onChanged!(
            value.toDouble(),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final bar = tester.getRect(find.byType(SplitQuantityBar));
          for (final label in ['左 $value', '分签刻度 · 共 49', '右 ${49 - value}']) {
            final rect = tester.getRect(find.text(label));
            expect(rect.left, greaterThanOrEqualTo(bar.left));
            expect(rect.right, lessThanOrEqualTo(bar.right + 0.1));
          }
          final button = tester.widget<FilledButton>(
            find.widgetWithText(
              FilledButton,
              method == DivinationMethod.lueShi ? '确认本次分堆' : '确认本变并计算归余',
            ),
          );
          expect(button.onPressed == null, value == 0 || value == 49);
        }
      });
    }
  }
}

void _setViewport(WidgetTester tester, Size size, {double scale = 1}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}
