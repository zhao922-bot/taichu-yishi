import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taichu_yishi/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> divinationData;

  setUpAll(() async {
    divinationData = await _loadDivinationData();
  });

  test('384 条占断逐项解析，首项有标记且后续项均为圆圈', () {
    final sourceHexagrams = divinationData['hexagrams'] as Map<String, dynamic>;
    var lineCount = 0;

    expect(sourceHexagrams, hasLength(64));
    for (final hexagramEntry in sourceHexagrams.entries) {
      final hexagram = hexagramEntry.value as Map<String, dynamic>;
      final lines = hexagram['lines'] as Map<String, dynamic>;
      expect(lines, hasLength(6), reason: '第 ${hexagramEntry.key} 卦应包含六爻');

      for (final lineEntry in lines.entries) {
        lineCount++;
        final source =
            (lineEntry.value as Map<String, dynamic>)['divination'] as String;
        final questions = parseDivinationQuestions(source);
        final expectedTexts = source
            .split('○')
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList();
        expectedTexts[0] = expectedTexts[0]
            .replaceFirst(RegExp(r'^【占】\s*'), '')
            .replaceFirst(RegExp(r'^[：:]\s*'), '');

        final reason = '第 ${hexagramEntry.key} 卦第 ${lineEntry.key} 爻';
        expect(questions, isNotEmpty, reason: reason);
        expect(questions.first.marker, '占', reason: reason);
        expect(
          questions.skip(1).map((question) => question.marker),
          everyElement('○'),
          reason: reason,
        );
        expect(
          questions.map((question) => question.text).toList(),
          expectedTexts,
          reason: reason,
        );
        expect(
          questions.length,
          '○'.allMatches(source).length + 1,
          reason: reason,
        );
      }
    }

    expect(lineCount, 384);
  });

  testWidgets('第 10 卦五爻按原文顺序逐项显示占断', (tester) async {
    final sourceHexagrams = divinationData['hexagrams'] as Map<String, dynamic>;
    final hexagramData = sourceHexagrams['10'] as Map<String, dynamic>;
    final lineData =
        (hexagramData['lines'] as Map<String, dynamic>)['5']
            as Map<String, dynamic>;
    final reading = SourceLine.fromJson(lineData);
    final questions = parseDivinationQuestions(reading.divination);
    final hexagram = hexagrams.firstWhere((item) => item.number == 10);
    final result = DivinationResult(
      method: DivinationMethod.threeEightyFour,
      question: '界面回归测试',
      hexagram: hexagram,
      lines: hexagram.lines,
      movingLines: const [5],
      changedHexagram: null,
      trace: '测试起卦记录',
      source: SourceHexagram(
        judgment: hexagramData['judgment'] as String,
        lines: {5: reading},
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ResultCard(result: result)),
        ),
      ),
    );

    expect(questions, hasLength(5));
    expect(find.text(reading.title), findsOneWidget);
    for (var index = 0; index < questions.length; index++) {
      final marker = tester.widget<Text>(
        find.byKey(ValueKey('divination-marker-${reading.title}-$index')),
      );
      expect(marker.data, index == 0 ? '占' : '○');
      expect(find.text(questions[index].text), findsOneWidget);
    }
  });
}

Future<Map<String, dynamic>> _loadDivinationData() async {
  final raw = await rootBundle.loadString(
    'assets/data/high_island_divinations.json',
  );
  return jsonDecode(raw) as Map<String, dynamic>;
}
