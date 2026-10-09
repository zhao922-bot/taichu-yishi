import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taichu_yishi/main.dart';

final _corpus = SourceCorpus({
  for (var number = 1; number <= 64; number++)
    number: const SourceHexagram(judgment: '测试', lines: {}),
});

CastingSession _session(DivinationMethod method) => CastingSession(
  method: method,
  question: '',
  gender: Gender.male,
  corpus: _corpus,
);

Map<String, dynamic> _fullStepArchive(DivinationMethod method) {
  final session = _session(method)..advance();
  final json = session.toJson();
  json['records'] = List.generate(
    session.totalSteps - 1,
    (_) => const CastingStep('分签', '', '').toJson(),
  );
  return json;
}

void main() {
  testWidgets('满步骤无结果存档在恢复入口拒绝，应用清理后正常构建', (tester) async {
    for (final method in DivinationMethod.values) {
      expect(
        () => CastingSession.fromJson(_fullStepArchive(method), _corpus),
        throwsFormatException,
      );
    }
    final preferences = _ControlledPreferences(
      jsonEncode(_fullStepArchive(DivinationMethod.lueShi)),
    );
    await tester.pumpWidget(
      CyberYiApp(corpus: _corpus, preferences: preferences),
    );
    expect(
      tester.widget<DivinationPage>(find.byType(DivinationPage)).initialSession,
      isNull,
    );
    expect(preferences.operations.single.value, isNull);
    preferences.operations.single.completion.complete(true);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('所有方法的每个未完成步骤可以恢复，完成存档拒绝恢复', () {
    for (final method in DivinationMethod.values) {
      final session = _session(method);
      while (!session.isComplete) {
        final json = session.toJson();
        final restored = CastingSession.fromJson(json, _corpus);
        expect(restored.toJson(), json);
        session.advance(leftPile: 1);
      }
      expect(
        () => CastingSession.fromJson(session.toJson(), _corpus),
        throwsFormatException,
      );
    }
  });

  test('拒绝步骤超限、缺少准备、非法爻值及不一致的中间状态', () {
    final traditional = _session(DivinationMethod.traditional)..advance();
    for (var i = 0; i < 3; i++) {
      traditional.advance(leftPile: 1);
    }
    for (final invalidValue in [5, 10]) {
      final json = traditional.toJson();
      json['traditionalValues'] = [invalidValue];
      expect(
        () => CastingSession.fromJson(json, _corpus),
        throwsFormatException,
      );
    }
    final invalidChange = traditional.toJson()..['traditionalChange'] = 2;
    expect(
      () => CastingSession.fromJson(invalidChange, _corpus),
      throwsFormatException,
    );
    final invalidRemaining = traditional.toJson()
      ..['traditionalRemaining'] = 48;
    expect(
      () => CastingSession.fromJson(invalidRemaining, _corpus),
      throwsFormatException,
    );
    final missingPreparation = traditional.toJson()..['preparation'] = null;
    expect(
      () => CastingSession.fromJson(missingPreparation, _corpus),
      throwsFormatException,
    );
    final tooMany = _fullStepArchive(DivinationMethod.lueShi);
    (tooMany['records'] as List).add(const CastingStep('', '', '').toJson());
    expect(
      () => CastingSession.fromJson(tooMany, _corpus),
      throwsFormatException,
    );
    final missingTrigram = _session(DivinationMethod.lueShi)
      ..advance()
      ..advance(leftPile: 1);
    final json = missingTrigram.toJson()..['upper'] = null;
    expect(() => CastingSession.fromJson(json, _corpus), throwsFormatException);
  });

  test('右手仅一策归余为零，第二变文案正确，最终爻值为九', () {
    final session = _session(DivinationMethod.traditional)..advance();
    session.advance(leftPile: 48);
    expect(session.traditionalRemaining, 44);
    expect(session.records.last.detail, contains('归余 5 策'));
    expect(session.records.last.meaning, contains('还需继续 2 变'));
    session.advance(leftPile: 43);
    expect(session.traditionalRemaining, 40);
    expect(session.records.last.detail, contains('归余 4 策'));
    expect(session.records.last.meaning, contains('还需继续 1 变'));
    session.advance(leftPile: 39);
    expect(session.toJson()['traditionalValues'], [9]);
  });

  test('遍历三变的所有可达策数与合法分堆，爻值始终在六至九', () {
    final prepared = _session(DivinationMethod.traditional)..advance();
    var states = {49: prepared.toJson()};
    final values = <int>{};
    for (var change = 0; change < 3; change++) {
      final nextStates = <int, Map<String, dynamic>>{};
      for (final entry in states.entries) {
        for (var left = 1; left < entry.key; left++) {
          final session = CastingSession.fromJson(entry.value, _corpus);
          session.advance(leftPile: left);
          if (change == 2) {
            final value =
                (session.toJson()['traditionalValues'] as List<int>).single;
            expect(value, inInclusiveRange(6, 9));
            values.add(value);
          } else {
            nextStates[session.traditionalRemaining] = session.toJson();
          }
        }
      }
      states = nextStates;
    }
    expect(values, {6, 7, 8, 9});
  });

  testWidgets('自动分签每次换步初始化合法随机分堆，手动默认二十四签', (tester) async {
    final session = _session(DivinationMethod.lueShi)..advance();
    final observed = <int>{};
    for (var step = 0; step < 16; step++) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LueShiPileCard(
              key: ValueKey(step),
              session: session,
              initialMode: SplitMode.automatic,
              onModeChanged: (_) {},
              onConfirm: (_) {},
            ),
          ),
        ),
      );
      final pile = tester
          .widget<SplitQuantityBar>(find.byType(SplitQuantityBar))
          .leftPile;
      expect(pile, inInclusiveRange(1, 48));
      observed.add(pile);
    }
    expect(observed.length, greaterThan(1));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LueShiPileCard(
            key: const ValueKey('manual'),
            session: session,
            initialMode: SplitMode.manual,
            onModeChanged: (_) {},
            onConfirm: (_) {},
          ),
        ),
      ),
    );
    expect(
      tester.widget<SplitQuantityBar>(find.byType(SplitQuantityBar)).leftPile,
      24,
    );
  });

  testWidgets('保存、删除串行执行且保存入队时的快照', (tester) async {
    final preferences = _ControlledPreferences();
    await tester.pumpWidget(
      CyberYiApp(corpus: _corpus, preferences: preferences),
    );
    final page = tester.widget<DivinationPage>(find.byType(DivinationPage));
    final session = _session(DivinationMethod.lueShi)..advance();
    page.onSessionChanged(session);
    session.advance(leftPile: 1);
    page.onSessionChanged(null);
    page.onSessionChanged(session);
    await tester.pump();
    expect(preferences.operations, hasLength(1));
    expect(jsonDecode(preferences.operations[0].value!)['records'], isEmpty);
    preferences.operations[0].completion.complete(true);
    await tester.pump();
    expect(preferences.operations, hasLength(2));
    expect(preferences.operations[1].value, isNull);
    preferences.operations[1].completion.complete(true);
    await tester.pump();
    expect(preferences.operations, hasLength(3));
    expect(
      jsonDecode(preferences.operations[2].value!)['records'],
      hasLength(1),
    );
    preferences.operations[2].completion.complete(true);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('保存返回 false、删除抛异常时捕获错误并继续后续持久化', (tester) async {
    final messages = <String?>[];
    final originalPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => messages.add(message);
    addTearDown(() => debugPrint = originalPrint);
    final preferences = _ControlledPreferences();
    await tester.pumpWidget(
      CyberYiApp(corpus: _corpus, preferences: preferences),
    );
    final page = tester.widget<DivinationPage>(find.byType(DivinationPage));
    page.onSessionChanged(_session(DivinationMethod.lueShi));
    page.onSessionChanged(null);
    page.onAppearanceChanged(AppAppearance.yang);
    await tester.pump();
    preferences.operations[0].completion.complete(false);
    await tester.pump();
    preferences.operations[1].completion.completeError(StateError('测试删除异常'));
    await tester.pump();
    expect(preferences.operations, hasLength(3));
    expect(preferences.operations[2].key, 'appearance');
    preferences.operations[2].completion.complete(true);
    await tester.pump();
    expect(
      messages.where((message) => message?.contains('持久化失败') ?? false),
      hasLength(2),
    );
    debugPrint = originalPrint;
    expect(tester.takeException(), isNull);
  });
}

class _ControlledPreferences implements SharedPreferences {
  _ControlledPreferences([this.initialSession]);
  final String? initialSession;
  final operations =
      <({String key, String? value, Completer<bool> completion})>[];

  @override
  String? getString(String key) =>
      key == 'casting_session' ? initialSession : null;

  @override
  Future<bool> setString(String key, String value) => _enqueue(key, value);

  @override
  Future<bool> remove(String key) => _enqueue(key, null);

  Future<bool> _enqueue(String key, String? value) {
    final completion = Completer<bool>();
    operations.add((key: key, value: value, completion: completion));
    return completion.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
