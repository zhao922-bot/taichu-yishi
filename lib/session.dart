import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

enum AppAppearance { yin, yang, system }

extension AppAppearanceStorage on AppAppearance {
  String get storageKey => name;

  static AppAppearance fromStorage(String? value) => switch (value) {
    'yin' => AppAppearance.yin,
    'yang' => AppAppearance.yang,
    _ => AppAppearance.system,
  };
}

enum DivinationMethod {
  traditional,
  lueShi,
  eightSix,
  sixtyFourSix,
  threeEightyFour,
}

extension MethodCopy on DivinationMethod {
  String get title => switch (this) {
    DivinationMethod.traditional => '周易传统筮法',
    DivinationMethod.lueShi => '49 签略筮法',
    DivinationMethod.eightSix => '八卦签 + 六爻签',
    DivinationMethod.sixtyFourSix => '64 卦签 + 六爻签',
    DivinationMethod.threeEightyFour => '384 爻签',
  };

  String get subtitle => switch (this) {
    DivinationMethod.traditional => '逐爻模拟蓍草概率；可出现多个动爻。',
    DivinationMethod.lueShi => '依高岛略筮法：49 签三次分签，固定一爻动。',
    DivinationMethod.eightSix => '依次抽上卦、下卦、动爻。',
    DivinationMethod.sixtyFourSix => '直接抽本卦，再抽动爻。',
    DivinationMethod.threeEightyFour => '一次抽中“某卦某爻”。',
  };
}

enum Gender { male, female }

enum Hand { left, right }

extension HandLabel on Hand {
  String get label => this == Hand.left ? '左手' : '右手';
}

class DivinationEngine {
  DivinationEngine(this._corpus);

  final SourceCorpus _corpus;
  CastingSession start({
    required DivinationMethod method,
    required String question,
    required Gender gender,
  }) => CastingSession(
    method: method,
    question: question,
    gender: gender,
    corpus: _corpus,
  );
}

class CastingSession {
  CastingSession({
    required this.method,
    required this.question,
    required this.gender,
    required this.corpus,
  });

  final DivinationMethod method;
  final String question;
  final Gender gender;
  final SourceCorpus corpus;
  final Random _random = Random.secure();
  final List<CastingStep> records = [];
  CastingStep? _preparation;
  final List<int> _traditionalValues = [];
  var _traditionalRemaining = 49;
  var _traditionalChange = 0;
  int? _upper;
  int? _lower;
  int? _moving;
  Hexagram? _directHex;
  DivinationResult? result;

  bool get isPrepared => _preparation != null;
  int get methodStepsCompleted => records.length;
  int get completedSteps => methodStepsCompleted + (isPrepared ? 1 : 0);
  int get totalSteps => switch (method) {
    DivinationMethod.traditional => 19,
    DivinationMethod.lueShi || DivinationMethod.eightSix => 4,
    DivinationMethod.sixtyFourSix => 3,
    DivinationMethod.threeEightyFour => 2,
  };
  bool get isComplete => result != null;
  Iterable<CastingStep> get displayRecords sync* {
    if (_preparation != null) yield _preparation!;
    yield* records;
  }

  Map<String, dynamic> toJson() => {
    'method': method.index,
    'question': question,
    'gender': gender.index,
    'preparation': _preparation?.toJson(),
    'records': records.map((record) => record.toJson()).toList(),
    'traditionalValues': _traditionalValues,
    'traditionalRemaining': _traditionalRemaining,
    'traditionalChange': _traditionalChange,
    'upper': _upper,
    'lower': _lower,
    'moving': _moving,
    'directHex': _directHex?.number,
  };

  factory CastingSession.fromJson(
    Map<String, dynamic> json,
    SourceCorpus corpus,
  ) {
    final session = CastingSession(
      method: DivinationMethod.values[json['method'] as int],
      question: json['question'] as String? ?? '',
      gender: Gender.values[json['gender'] as int],
      corpus: corpus,
    );
    final preparation = json['preparation'];
    if (preparation is Map) {
      session._preparation = CastingStep.fromJson(
        Map<String, dynamic>.from(preparation),
      );
    }
    final records = json['records'];
    if (records is List) {
      session.records.addAll(
        records.map(
          (record) => CastingStep.fromJson(Map<String, dynamic>.from(record)),
        ),
      );
    }
    final traditionalValues = json['traditionalValues'];
    if (traditionalValues is List) {
      session._traditionalValues.addAll(
        traditionalValues.map((value) => value as int),
      );
    }
    session._traditionalRemaining = json['traditionalRemaining'] as int? ?? 49;
    session._traditionalChange = json['traditionalChange'] as int? ?? 0;
    session._upper = json['upper'] as int?;
    session._lower = json['lower'] as int?;
    session._moving = json['moving'] as int?;
    final directHex = json['directHex'] as int?;
    if (directHex != null) {
      session._directHex = hexagrams.firstWhere(
        (hexagram) => hexagram.number == directHex,
      );
    }
    return session;
  }

  int get traditionalRemaining => _traditionalRemaining;
  int get traditionalLine => _traditionalValues.length + 1;
  int get traditionalChange => _traditionalChange + 1;
  String get nextInstruction {
    if (isComplete) {
      return '本轮起筮已完成，可查看结果或重新起卦。';
    }
    if (!isPrepared) {
      return switch (method) {
        DivinationMethod.traditional =>
          '请静默专念所占之事；置一策为太极，余四十九策合为一束，准备从初爻第一变开始揲蓍。',
        DivinationMethod.lueShi => '请备五十签，静默专念所占之事；先取一签为太极，余四十九签合为一束。',
        DivinationMethod.eightSix ||
        DivinationMethod.sixtyFourSix ||
        DivinationMethod.threeEightyFour => '请静默专念所占之事；专注既定后，再依下一步所示手位抽签。',
      };
    }
    return switch (method) {
      DivinationMethod.traditional =>
        '${lineName(traditionalLine)}第 $traditionalChange 变：将 $_traditionalRemaining 策分为左右两手。',
      DivinationMethod.lueShi => [
        '第 1 步：以${_handForCurrentStep()!.label}所取签数除八，定上卦。',
        '第 2 步：重新合回 49 签，以${_handForCurrentStep()!.label}所取签数除八，定下卦。',
        '第 3 步：再次合回 49 签，以${_handForCurrentStep()!.label}所取签数除六，定动爻。',
      ][methodStepsCompleted],
      DivinationMethod.eightSix => [
        '第 1 步：请以${_handForCurrentStep()!.label}从八卦签中抽上卦。',
        '第 2 步：请以${_handForCurrentStep()!.label}从八卦签中抽下卦。',
        '第 3 步：请以${_handForCurrentStep()!.label}从六爻签中抽动爻。',
      ][methodStepsCompleted],
      DivinationMethod.sixtyFourSix => [
        '第 1 步：从 64 卦签中抽取本卦。',
        '第 2 步：请以${_handForCurrentStep()!.label}从六爻签中抽取动爻。',
      ][methodStepsCompleted],
      DivinationMethod.threeEightyFour => '一步直抽：从 384 个“卦 × 爻”签位中抽取结果。',
    };
  }

  void advance({int? leftPile}) {
    if (isComplete) return;
    if (!isPrepared) {
      _prepare();
      return;
    }
    switch (method) {
      case DivinationMethod.traditional:
        _advanceTraditional(leftPile);
      case DivinationMethod.lueShi:
        _advanceLueShi(leftPile);
      case DivinationMethod.eightSix:
        _advanceEightSix();
      case DivinationMethod.sixtyFourSix:
        _advanceSixtyFourSix();
      case DivinationMethod.threeEightyFour:
        _advanceThreeEightyFour();
    }
  }

  void _prepare() {
    _preparation = CastingStep('起筮准备', switch (method) {
      DivinationMethod.traditional => '已置一策为太极，余四十九策用于三变成一爻。',
      DivinationMethod.lueShi => '已取一签为太极，余四十九签用于三次分签。',
      _ => '已静默专念所占之事，准备依指定手位抽签。',
    }, '此步使起筮材料与心念先行归一；随后才进入分策或抽签。');
  }

  Hand? _handForCurrentStep() {
    final step = methodStepsCompleted;
    final male = gender == Gender.male;
    return switch (method) {
      DivinationMethod.lueShi || DivinationMethod.eightSix =>
        (male
            ? const [Hand.left, Hand.right, Hand.left]
            : const [Hand.right, Hand.left, Hand.right])[step],
      DivinationMethod.sixtyFourSix =>
        step == 1 ? (male ? Hand.left : Hand.right) : null,
      _ => null,
    };
  }

  void _advanceTraditional(int? leftPile) {
    final left = leftPile ?? _random.nextInt(_traditionalRemaining - 1) + 1;
    if (left < 1 || left >= _traditionalRemaining) {
      throw ArgumentError.value(left, 'leftPile', '分堆必须使左右两手各至少有一策。');
    }
    final right = _traditionalRemaining - left;
    final leftRemainder = left % 4 == 0 ? 4 : left % 4;
    final rightAfterOne = right - 1;
    final rightRemainder = rightAfterOne % 4 == 0 ? 4 : rightAfterOne % 4;
    final removed = 1 + leftRemainder + rightRemainder;
    final next = _traditionalRemaining - removed;
    final line = traditionalLine;
    final change = traditionalChange;
    _traditionalChange++;

    if (_traditionalChange == 3) {
      final value = next ~/ 4;
      _traditionalValues.add(value);
      final label = switch (value) {
        6 => '老阴（变爻）',
        7 => '少阳（不变）',
        8 => '少阴（不变）',
        _ => '老阳（变爻）',
      };
      records.add(
        CastingStep(
          '${lineName(line)} · 第 $change 变成爻',
          '本变左 $left、右 $right；右手取一后，左右各以四数归余，归余 $removed 策，余 $next 策。$next ÷ 4 = $value。',
          '三变完成${lineName(line)}，得 $value：$label。${value == 6 || value == 9 ? '它将作为动爻参与变卦。' : '它在变卦中保持不变。'}',
        ),
      );
      _traditionalChange = 0;
      _traditionalRemaining = 49;
      if (_traditionalValues.length == 6) {
        final lines = _traditionalValues.map((v) => v == 7 || v == 9).toList();
        final moving = <int>[
          for (var i = 0; i < 6; i++)
            if (_traditionalValues[i] == 6 || _traditionalValues[i] == 9) i + 1,
        ];
        _finish(lines, moving);
      }
      return;
    }

    records.add(
      CastingStep(
        '${lineName(line)} · 第 $change 变',
        '本变左 $left、右 $right；右手取一后，左右各以四数归余，归余 $removed 策，余 $next 策。',
        '第 $change 变只记录归余与剩余策数；还需继续两变，才能得到一个爻。',
      ),
    );
    _traditionalRemaining = next;
  }

  void _advanceLueShi(int? leftPile) {
    if (methodStepsCompleted < 2) {
      final hand = _handForCurrentStep()!;
      final draw = _splitRemainder(8, leftPile, hand);
      final trigram = Trigram.fromNumber(draw.result);
      if (methodStepsCompleted == 0) {
        _upper = draw.result;
        records.add(
          CastingStep(
            '第一次分签 · 上卦',
            draw.description,
            '余数 ${draw.result} 对应八卦数 ${trigram.name}（${trigram.symbol}），作为上卦。',
          ),
        );
      } else {
        _lower = draw.result;
        records.add(
          CastingStep(
            '第二次分签 · 下卦',
            draw.description,
            '余数 ${draw.result} 对应八卦数 ${trigram.name}（${trigram.symbol}），作为下卦。',
          ),
        );
      }
      return;
    }
    final hand = _handForCurrentStep()!;
    final draw = _splitRemainder(6, leftPile, hand);
    _moving = draw.result;
    records.add(
      CastingStep(
        '第三次分签 · 动爻',
        draw.description,
        '余数 ${draw.result} 对应${lineName(draw.result)}；略筮法由此固定为一爻动。',
      ),
    );
    final upper = Trigram.fromNumber(_upper!);
    final lower = Trigram.fromNumber(_lower!);
    _finish([...lower.lines, ...upper.lines], [_moving!]);
  }

  void _advanceEightSix() {
    if (methodStepsCompleted < 2) {
      final hand = _handForCurrentStep()!;
      final trigram = Trigram.fromNumber(_random.nextInt(8) + 1);
      if (methodStepsCompleted == 0) {
        _upper = trigram.number;
        records.add(
          CastingStep(
            '抽上卦签',
            '以${hand.label}从 8 根卦象签中抽得 ${trigram.name}（${trigram.symbol}）。',
            '上卦代表外部情境、所临之势。',
          ),
        );
      } else {
        _lower = trigram.number;
        records.add(
          CastingStep(
            '抽下卦签',
            '以${hand.label}从 8 根卦象签中抽得 ${trigram.name}（${trigram.symbol}）。',
            '下卦代表内部基础、事情的起点。',
          ),
        );
      }
      return;
    }
    final hand = _handForCurrentStep()!;
    _moving = _random.nextInt(6) + 1;
    records.add(
      CastingStep(
        '抽动爻签',
        '以${hand.label}从 6 根爻位签中抽得${lineName(_moving!)}。',
        '动爻指定本次要读取的《占断》条目。',
      ),
    );
    final upper = Trigram.fromNumber(_upper!);
    final lower = Trigram.fromNumber(_lower!);
    _finish([...lower.lines, ...upper.lines], [_moving!]);
  }

  void _advanceSixtyFourSix() {
    if (methodStepsCompleted == 0) {
      _directHex = hexagrams[_random.nextInt(64)];
      records.add(
        CastingStep(
          '抽本卦签',
          '从 64 根卦签中抽得第 ${_directHex!.number} 卦《${_directHex!.name}》。',
          '本卦呈现提问时的整体象与卦辞。',
        ),
      );
      return;
    }
    final hand = _handForCurrentStep()!;
    _moving = _random.nextInt(6) + 1;
    records.add(
      CastingStep(
        '抽动爻签',
        '以${hand.label}从 6 根爻位签中抽得${lineName(_moving!)}。',
        '动爻指定本卦六个《占断》中应查看的一个。',
      ),
    );
    _finish(_directHex!.lines, [_moving!]);
  }

  void _advanceThreeEightyFour() {
    final draw = _random.nextInt(384);
    _directHex = hexagrams[draw ~/ 6];
    _moving = draw % 6 + 1;
    records.add(
      CastingStep(
        '直抽 384 爻签',
        '抽得第 ${_directHex!.number} 卦《${_directHex!.name}》${lineName(_moving!)}。',
        '一支签已同时确定本卦与动爻，因此这是该方法唯一的起卦步骤。',
      ),
    );
    _finish(_directHex!.lines, [_moving!]);
  }

  _Remainder _splitRemainder(int divisor, int? leftPile, Hand hand) {
    final left = leftPile ?? _random.nextInt(48) + 1;
    if (left < 1 || left > 48) {
      throw ArgumentError.value(left, 'leftPile', '分签必须使左右两手各至少有一签。');
    }
    final right = 49 - left;
    final chosen = hand == Hand.left ? left : right;
    final result = chosen % divisor == 0 ? divisor : chosen % divisor;
    return _Remainder(
      result,
      '将 49 签分为左右两手：${hand.label}取 $chosen 签（另一手 ${49 - chosen}），以 $chosen 除 $divisor，余数为 $result。',
    );
  }

  void _finish(List<bool> lines, List<int> moving) {
    final hex = findByLines(lines);
    final changedLines = [...lines];
    for (final line in moving) {
      changedLines[line - 1] = !changedLines[line - 1];
    }
    final changed = moving.isEmpty ? null : findByLines(changedLines);
    result = DivinationResult(
      method: method,
      question: question,
      hexagram: hex,
      lines: lines,
      movingLines: moving,
      changedHexagram: changed,
      trace: records
          .map((record) => '${record.title}：${record.detail}')
          .join('\n'),
      source: corpus.forHexagram(hex.number),
    );
  }
}

class CastingStep {
  const CastingStep(this.title, this.detail, this.meaning);
  final String title;
  final String detail;
  final String meaning;

  Map<String, String> toJson() => {
    'title': title,
    'detail': detail,
    'meaning': meaning,
  };

  factory CastingStep.fromJson(Map<String, dynamic> json) => CastingStep(
    json['title'] as String? ?? '',
    json['detail'] as String? ?? '',
    json['meaning'] as String? ?? '',
  );
}

class _Remainder {
  const _Remainder(this.result, this.description);
  final int result;
  final String description;
}

class DivinationResult {
  const DivinationResult({
    required this.method,
    required this.question,
    required this.hexagram,
    required this.lines,
    required this.movingLines,
    required this.changedHexagram,
    required this.trace,
    required this.source,
  });
  final DivinationMethod method;
  final String question;
  final Hexagram hexagram;
  final List<bool> lines;
  final List<int> movingLines;
  final Hexagram? changedHexagram;
  final String trace;
  final SourceHexagram source;
}

String lineName(int line) =>
    const ['初爻', '二爻', '三爻', '四爻', '五爻', '上爻'][line - 1];

class SourceCorpus {
  const SourceCorpus(this._hexagrams);

  final Map<int, SourceHexagram> _hexagrams;

  static Future<SourceCorpus> load() async {
    final raw = await rootBundle.loadString(
      'assets/data/high_island_divinations.json',
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final entries = decoded['hexagrams'] as Map<String, dynamic>;
    final hexagrams = <int, SourceHexagram>{};
    for (final entry in entries.entries) {
      final item = entry.value as Map<String, dynamic>;
      final lines = item['lines'] as Map<String, dynamic>;
      hexagrams[int.parse(entry.key)] = SourceHexagram(
        judgment: item['judgment'] as String,
        lines: {
          for (final line in lines.entries)
            int.parse(line.key): SourceLine.fromJson(
              line.value as Map<String, dynamic>,
            ),
        },
      );
    }
    return SourceCorpus(hexagrams);
  }

  SourceHexagram forHexagram(int number) => _hexagrams[number]!;
}

class SourceHexagram {
  const SourceHexagram({required this.judgment, required this.lines});
  final String judgment;
  final Map<int, SourceLine> lines;
}

class SourceLine {
  const SourceLine({required this.title, required this.divination});
  factory SourceLine.fromJson(Map<String, dynamic> json) => SourceLine(
    title: json['title'] as String,
    divination: json['divination'] as String,
  );
  final String title;
  final String divination;
}

class Trigram {
  const Trigram(this.number, this.name, this.symbol, this.lines);
  final int number;
  final String name;
  final String symbol;
  final List<bool> lines; // bottom to top

  static const all = [
    Trigram(1, '乾', '☰', [true, true, true]),
    Trigram(2, '兑', '☱', [true, true, false]),
    Trigram(3, '离', '☲', [true, false, true]),
    Trigram(4, '震', '☳', [true, false, false]),
    Trigram(5, '巽', '☴', [false, true, true]),
    Trigram(6, '坎', '☵', [false, true, false]),
    Trigram(7, '艮', '☶', [false, false, true]),
    Trigram(8, '坤', '☷', [false, false, false]),
  ];
  static Trigram fromNumber(int number) => all[number - 1];
}

class Hexagram {
  const Hexagram(this.number, this.name, this.upper, this.lower);
  final int number;
  final String name;
  final Trigram upper;
  final Trigram lower;
  List<bool> get lines => [...lower.lines, ...upper.lines];
}

Hexagram findHexagram(Trigram upper, Trigram lower) => hexagrams.firstWhere(
  (h) => h.upper.number == upper.number && h.lower.number == lower.number,
);
Hexagram findByLines(List<bool> lines) =>
    hexagrams.firstWhere((h) => _same(h.lines, lines));
bool _same(List<bool> a, List<bool> b) =>
    a.length == b.length &&
    List.generate(a.length, (i) => a[i] == b[i]).every((same) => same);

const qian = Trigram(1, '乾', '☰', [true, true, true]);
const dui = Trigram(2, '兑', '☱', [true, true, false]);
const li = Trigram(3, '离', '☲', [true, false, true]);
const zhen = Trigram(4, '震', '☳', [true, false, false]);
const xun = Trigram(5, '巽', '☴', [false, true, true]);
const kan = Trigram(6, '坎', '☵', [false, true, false]);
const gen = Trigram(7, '艮', '☶', [false, false, true]);
const kun = Trigram(8, '坤', '☷', [false, false, false]);

// 卦序、卦名与上下卦用于排卦；《占断》原文单独存放在 EPUB 提取的数据文件中。
const hexagrams = <Hexagram>[
  Hexagram(1, '乾为天', qian, qian),
  Hexagram(2, '坤为地', kun, kun),
  Hexagram(3, '水雷屯', kan, zhen),
  Hexagram(4, '山水蒙', gen, kan),
  Hexagram(5, '水天需', kan, qian),
  Hexagram(6, '天水讼', qian, kan),
  Hexagram(7, '地水师', kun, kan),
  Hexagram(8, '水地比', kan, kun),
  Hexagram(9, '风天小畜', xun, qian),
  Hexagram(10, '天泽履', qian, dui),
  Hexagram(11, '地天泰', kun, qian),
  Hexagram(12, '天地否', qian, kun),
  Hexagram(13, '天火同人', qian, li),
  Hexagram(14, '火天大有', li, qian),
  Hexagram(15, '地山谦', kun, gen),
  Hexagram(16, '雷地豫', zhen, kun),
  Hexagram(17, '泽雷随', dui, zhen),
  Hexagram(18, '山风蛊', gen, xun),
  Hexagram(19, '地泽临', kun, dui),
  Hexagram(20, '风地观', xun, kun),
  Hexagram(21, '火雷噬嗑', li, zhen),
  Hexagram(22, '山火贲', gen, li),
  Hexagram(23, '山地剥', gen, kun),
  Hexagram(24, '地雷复', kun, zhen),
  Hexagram(25, '天雷无妄', qian, zhen),
  Hexagram(26, '山天大畜', gen, qian),
  Hexagram(27, '山雷颐', gen, zhen),
  Hexagram(28, '泽风大过', dui, xun),
  Hexagram(29, '坎为水', kan, kan),
  Hexagram(30, '离为火', li, li),
  Hexagram(31, '泽山咸', dui, gen),
  Hexagram(32, '雷风恒', zhen, xun),
  Hexagram(33, '天山遁', qian, gen),
  Hexagram(34, '雷天大壮', zhen, qian),
  Hexagram(35, '火地晋', li, kun),
  Hexagram(36, '地火明夷', kun, li),
  Hexagram(37, '风火家人', xun, li),
  Hexagram(38, '火泽睽', li, dui),
  Hexagram(39, '水山蹇', kan, gen),
  Hexagram(40, '雷水解', zhen, kan),
  Hexagram(41, '山泽损', gen, dui),
  Hexagram(42, '风雷益', xun, zhen),
  Hexagram(43, '泽天夬', dui, qian),
  Hexagram(44, '天风姤', qian, xun),
  Hexagram(45, '泽地萃', dui, kun),
  Hexagram(46, '地风升', kun, xun),
  Hexagram(47, '泽水困', dui, kan),
  Hexagram(48, '水风井', kan, xun),
  Hexagram(49, '泽火革', dui, li),
  Hexagram(50, '火风鼎', li, xun),
  Hexagram(51, '震为雷', zhen, zhen),
  Hexagram(52, '艮为山', gen, gen),
  Hexagram(53, '风山渐', xun, gen),
  Hexagram(54, '雷泽归妹', zhen, dui),
  Hexagram(55, '雷火丰', zhen, li),
  Hexagram(56, '火山旅', li, gen),
  Hexagram(57, '巽为风', xun, xun),
  Hexagram(58, '兑为泽', dui, dui),
  Hexagram(59, '风水涣', xun, kan),
  Hexagram(60, '水泽节', kan, dui),
  Hexagram(61, '风泽中孚', xun, dui),
  Hexagram(62, '雷山小过', zhen, gen),
  Hexagram(63, '水火既济', kan, li),
  Hexagram(64, '火水未济', li, kan),
];