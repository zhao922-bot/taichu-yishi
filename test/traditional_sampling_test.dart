import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:taichu_yishi/session.dart';

final _corpus = SourceCorpus({
  for (var number = 1; number <= 64; number++)
    number: const SourceHexagram(judgment: '测试', lines: {}),
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('经文 JSON 可正常解析，四处修订字段值准确', () async {
    final corpus = await SourceCorpus.load();
    expect(corpus.forHexagram(43).judgment, '夬［33］：扬于王庭，孚号，有厉。告自邑，不利即戎，利有攸往。');
    expect(corpus.forHexagram(47).lines[5]!.title, '九五：劓刖。困于赤绂，乃徐有说。利用祭祀。');
    expect(corpus.forHexagram(52).judgment, '艮［60］：艮其背，不获其身，行其庭，不见其人。无咎。');
    expect(corpus.forHexagram(63).lines[4]!.title, '六四：繻 有衣袽，终日戒。');
  });

  test('所有可达策数均先等概率抽四种余数，再均匀抽该类全部合法堆大小', () {
    for (final total in [49, 44, 40, 36, 32]) {
      for (var remainder = 0; remainder < 4; remainder++) {
        final candidates = [
          for (var left = 1; left < total; left++)
            if (left % 4 == remainder) left,
        ];
        for (var index = 0; index < candidates.length; index++) {
          final random = _ScriptedRandom(
            [4, candidates.length],
            [remainder, index],
          );
          final left = sampleTraditionalLeftPile(total, random);
          expect(left, candidates[index]);
          expect(left, inInclusiveRange(1, total - 1));
          expect(left % 4, remainder);
          expect(random.calls, 2);
        }
      }
    }
  });

  test('固定种子采样经三变成爻，全部爻值在六至九且四种均可达', () {
    final random = Random(20261009);
    final values = <int>{};
    for (var trial = 0; trial < 1024; trial++) {
      final session = CastingSession(
        method: DivinationMethod.traditional,
        question: '',
        gender: Gender.male,
        corpus: _corpus,
      )..advance();
      for (var change = 0; change < 3; change++) {
        session.advance(
          leftPile: sampleTraditionalLeftPile(
            session.traditionalRemaining,
            random,
          ),
        );
      }
      final value = (session.toJson()['traditionalValues'] as List<int>).single;
      expect(value, inInclusiveRange(6, 9));
      values.add(value);
    }
    expect(values, {6, 7, 8, 9});
  });

  test('略筮男女手位、上下卦顺序、小数直取及余零映射符合规范', () {
    for (final gender in Gender.values) {
      for (var chosen = 1; chosen <= 48; chosen++) {
        final session = CastingSession(
          method: DivinationMethod.lueShi,
          question: '',
          gender: gender,
          corpus: _corpus,
        )..advance();
        final hands = gender == Gender.male
            ? [Hand.left, Hand.right, Hand.left]
            : [Hand.right, Hand.left, Hand.right];
        for (var step = 0; step < 3; step++) {
          expect(session.nextInstruction, contains(hands[step].label));
          session.advance(
            leftPile: hands[step] == Hand.left ? chosen : 49 - chosen,
          );
          expect(session.records.last.detail, contains('将 49 签'));
          expect(
            session.records.last.detail,
            contains('${hands[step].label}取 $chosen 签'),
          );
          expect(
            session.records.last.title,
            contains(['上卦', '下卦', '动爻'][step]),
          );
          final divisor = step < 2 ? 8 : 6;
          final expected = chosen % divisor == 0 ? divisor : chosen % divisor;
          if (step < 2) {
            expect(session.toJson()[step == 0 ? 'upper' : 'lower'], expected);
            expect(session.result, isNull);
          } else {
            expect(session.result!.movingLines, [expected]);
          }
        }
      }
    }

    // 上乾下坤，确保“先取上卦”并非只体现在标题中。
    final session =
        CastingSession(
            method: DivinationMethod.lueShi,
            question: '',
            gender: Gender.male,
            corpus: _corpus,
          )
          ..advance()
          ..advance(leftPile: 1)
          ..advance(leftPile: 41)
          ..advance(leftPile: 6);
    expect(session.result!.hexagram.upper.number, 1);
    expect(session.result!.hexagram.lower.number, 8);
    expect(session.result!.movingLines, [6]);
  });
}

class _ScriptedRandom implements Random {
  _ScriptedRandom(this.bounds, this.values);

  final List<int> bounds;
  final List<int> values;
  var calls = 0;

  @override
  int nextInt(int max) {
    expect(max, bounds[calls]);
    return values[calls++];
  }

  @override
  bool nextBool() => throw UnsupportedError('只应使用 nextInt');

  @override
  double nextDouble() => throw UnsupportedError('只应使用 nextInt');
}
