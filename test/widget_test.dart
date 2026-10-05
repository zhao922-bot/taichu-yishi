import 'package:flutter_test/flutter_test.dart';

import 'package:taichu_yishi/main.dart';

void main() {
  testWidgets('renders the five-method divination interface', (tester) async {
    await tester.pumpWidget(const CyberYiApp(corpus: SourceCorpus({})));

    expect(find.text('太初易筮'), findsOneWidget);
    expect(find.text('周易传统筮法'), findsOneWidget);
    expect(find.text('49 签略筮法'), findsOneWidget);
    expect(find.text('384 爻签'), findsOneWidget);
  });

  test('略筮依左右手次序完成三次分签', () {
    final session = DivinationEngine(_testCorpus()).start(
      method: DivinationMethod.lueShi,
      question: '测试',
      gender: Gender.male,
    );
    expect(session.totalSteps, 4);
    session.advance();
    expect(session.isPrepared, isTrue);
    expect(session.displayRecords.single.title, '起筮准备');
    expect(() => session.advance(leftPile: 0), throwsArgumentError);
    session.advance(leftPile: 1);
    expect(session.result, isNull);
    expect(session.records.single.title, contains('上卦'));
    expect(session.records.single.detail, contains('左手取 1 签'));
    session.advance(leftPile: 1);
    expect(session.result, isNull);
    expect(session.records[1].title, contains('下卦'));
    expect(session.records[1].detail, contains('右手取 48 签'));
    session.advance(leftPile: 1);
    expect(session.result, isNotNull);
    expect(session.records[2].title, contains('动爻'));
    expect(session.records[2].detail, contains('左手取 1 签'));
  });

  test('传统筮法以十八变完成六爻', () {
    final session = DivinationEngine(_testCorpus()).start(
      method: DivinationMethod.traditional,
      question: '测试',
      gender: Gender.male,
    );
    session.advance();
    expect(session.isPrepared, isTrue);
    for (var step = 1; step <= 17; step++) {
      session.advance();
      expect(session.result, isNull, reason: '第 $step 步不应提前成卦');
    }
    session.advance();
    expect(session.result, isNotNull);
    expect(session.records.length, 18);
  });

  test('八卦签法记录男女反向的取手顺序', () {
    final session = DivinationEngine(_testCorpus()).start(
      method: DivinationMethod.eightSix,
      question: '测试',
      gender: Gender.female,
    );
    session.advance();
    session.advance();
    session.advance();
    session.advance();
    expect(session.records[0].detail, contains('右手'));
    expect(session.records[1].detail, contains('左手'));
    expect(session.records[2].detail, contains('右手'));
  });

  test('未完成起筮可以序列化并恢复', () {
    final session = DivinationEngine(_testCorpus()).start(
      method: DivinationMethod.lueShi,
      question: '恢复测试',
      gender: Gender.female,
    );
    session.advance();
    session.advance(leftPile: 12);

    final restored = CastingSession.fromJson(session.toJson(), _testCorpus());
    expect(restored.question, '恢复测试');
    expect(restored.gender, Gender.female);
    expect(restored.method, DivinationMethod.lueShi);
    expect(restored.isPrepared, isTrue);
    expect(restored.records.length, 1);
    expect(restored.records.single.detail, contains('右手取 37 签'));
  });

  test('64 卦签完整两步后生成结果', () {
    final session = DivinationEngine(_testCorpus()).start(
      method: DivinationMethod.sixtyFourSix,
      question: '64 卦签测试',
      gender: Gender.male,
    );
    session.advance();
    expect(session.isPrepared, isTrue);
    session.advance();
    expect(session.result, isNull);
    expect(session.records.last.title, contains('本卦'));
    session.advance();
    expect(session.result, isNotNull);
    expect(session.records.last.title, contains('动爻'));
  });

  test('384 爻签准备后一步生成结果', () {
    final session = DivinationEngine(_testCorpus()).start(
      method: DivinationMethod.threeEightyFour,
      question: '384 爻签测试',
      gender: Gender.male,
    );
    expect(session.totalSteps, 2);
    session.advance();
    expect(session.isPrepared, isTrue);
    session.advance();
    expect(session.result, isNotNull);
    expect(session.records.single.title, '直抽 384 爻签');
    expect(session.result!.movingLines, hasLength(1));
    expect(session.result!.movingLines.single, inInclusiveRange(1, 6));
  });

  test('传统筮法拒绝空分堆与整堆', () {
    final session = DivinationEngine(_testCorpus()).start(
      method: DivinationMethod.traditional,
      question: '边界测试',
      gender: Gender.male,
    );
    session.advance();
    expect(() => session.advance(leftPile: 0), throwsArgumentError);
    expect(() => session.advance(leftPile: 49), throwsArgumentError);
  });

  test('会话恢复会带回问题文本', () {
    final session = DivinationEngine(_testCorpus()).start(
      method: DivinationMethod.sixtyFourSix,
      question: '续问此题',
      gender: Gender.female,
    );
    session.advance();
    final restored = CastingSession.fromJson(session.toJson(), _testCorpus());
    expect(restored.question, '续问此题');
    expect(restored.method, DivinationMethod.sixtyFourSix);
    expect(restored.gender, Gender.female);
    expect(restored.isPrepared, isTrue);
  });
}

SourceCorpus _testCorpus() => SourceCorpus({
  for (var number = 1; number <= 64; number++)
    number: const SourceHexagram(
      judgment: '测试卦辞',
      lines: {
        1: SourceLine(title: '初爻', divination: '测试占断'),
        2: SourceLine(title: '二爻', divination: '测试占断'),
        3: SourceLine(title: '三爻', divination: '测试占断'),
        4: SourceLine(title: '四爻', divination: '测试占断'),
        5: SourceLine(title: '五爻', divination: '测试占断'),
        6: SourceLine(title: '上爻', divination: '测试占断'),
      },
    ),
});
