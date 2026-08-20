import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final corpus = await SourceCorpus.load();
  final preferences = await SharedPreferences.getInstance();
  runApp(CyberYiApp(corpus: corpus, preferences: preferences));
}

const _ink = Color(0xff19130f);
const _panel = Color(0xff292016);
const _jade = Color(0xff8eb49a);
const _gold = Color(0xffd2a65d);
const _vermilion = Color(0xffbd4b3f);
const _paper = Color(0xfff0e0bb);
const _cyan = _jade;
const _appFont = 'NotoSerifSC';

Color _adaptiveAccent(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
    ? const Color(0xff416f55)
    : _cyan;

bool _isYangTheme(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light;

Color _ritualCardColor(BuildContext context, {required Color yin}) =>
    _isYangTheme(context) ? const Color(0xfffff7e5) : yin;

Color _ritualSurfaceColor(BuildContext context, {required Color yin}) =>
    _isYangTheme(context) ? const Color(0xfffff9ea) : yin;

Color _ritualBorderColor(BuildContext context, {required Color yin}) =>
    _isYangTheme(context) ? const Color(0xffb68b4f) : yin;

Color _ritualBodyColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface.withValues(alpha: .78);

Color _ritualMutedColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface.withValues(alpha: .58);

Color _ritualTitleColor(BuildContext context, {required Color yin}) =>
    _isYangTheme(context) ? const Color(0xff8a3d34) : yin;

enum AppAppearance { yin, yang, system }

extension AppAppearanceStorage on AppAppearance {
  String get storageKey => name;

  static AppAppearance fromStorage(String? value) => switch (value) {
    'yin' => AppAppearance.yin,
    'yang' => AppAppearance.yang,
    _ => AppAppearance.system,
  };
}

class CyberYiApp extends StatefulWidget {
  const CyberYiApp({super.key, required this.corpus, this.preferences});
  final SourceCorpus corpus;
  final SharedPreferences? preferences;

  @override
  State<CyberYiApp> createState() => _CyberYiAppState();
}

class _CyberYiAppState extends State<CyberYiApp> {
  late AppAppearance _appearance;
  CastingSession? _restoredSession;

  @override
  void initState() {
    super.initState();
    final preferences = widget.preferences;
    _appearance = AppAppearanceStorage.fromStorage(
      preferences?.getString(_appearanceStorageKey),
    );
    final rawSession = preferences?.getString(_sessionStorageKey);
    if (rawSession != null) {
      try {
        _restoredSession = CastingSession.fromJson(
          jsonDecode(rawSession) as Map<String, dynamic>,
          widget.corpus,
        );
      } on Object {
        preferences?.remove(_sessionStorageKey);
      }
    }
  }

  void _setAppearance(AppAppearance value) {
    setState(() => _appearance = value);
    widget.preferences?.setString(_appearanceStorageKey, value.storageKey);
  }

  void _persistSession(CastingSession? session) {
    if (session == null || session.isComplete) {
      widget.preferences?.remove(_sessionStorageKey);
    } else {
      widget.preferences?.setString(
        _sessionStorageKey,
        jsonEncode(session.toJson()),
      );
    }
  }

  ThemeData _theme(Brightness brightness) {
    final isYang = brightness == Brightness.light;
    final foreground = isYang ? const Color(0xff332317) : _paper;
    final baseTextTheme = ThemeData(
      brightness: brightness,
      fontFamily: _appFont,
    ).textTheme;
    return ThemeData(
      fontFamily: _appFont,
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: isYang ? const Color(0xfff4ead2) : _ink,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _gold,
        brightness: brightness,
        surface: isYang ? const Color(0xfffff7e5) : _panel,
      ).copyWith(onSurface: foreground, onSurfaceVariant: foreground),
      textTheme: baseTextTheme.apply(
        bodyColor: foreground,
        displayColor: foreground,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isYang ? const Color(0xfff4ead2) : _ink,
        foregroundColor: isYang ? const Color(0xff382617) : _paper,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: isYang ? const Color(0xfffff7e5) : _panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isYang ? const Color(0xffb68b4f) : const Color(0xff85673e),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isYang ? const Color(0xfffff9ea) : const Color(0xff211912),
        labelStyle: const TextStyle(color: _gold),
        hintStyle: TextStyle(
          color: isYang ? const Color(0xff836b49) : const Color(0xffb9a98d),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xff85673e)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xff85673e)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _gold, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _vermilion,
          foregroundColor: _paper,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '太初易筮',
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    themeMode: switch (_appearance) {
      AppAppearance.yin => ThemeMode.dark,
      AppAppearance.yang => ThemeMode.light,
      AppAppearance.system => ThemeMode.system,
    },
    home: DivinationPage(
      corpus: widget.corpus,
      initialSession: _restoredSession,
      appearance: _appearance,
      onAppearanceChanged: _setAppearance,
      onSessionChanged: _persistSession,
    ),
  );
}

const _appearanceStorageKey = 'appearance';
const _sessionStorageKey = 'casting_session';

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

class DivinationPage extends StatefulWidget {
  const DivinationPage({
    super.key,
    required this.corpus,
    this.initialSession,
    required this.appearance,
    required this.onAppearanceChanged,
    required this.onSessionChanged,
  });
  final SourceCorpus corpus;
  final CastingSession? initialSession;
  final AppAppearance appearance;
  final ValueChanged<AppAppearance> onAppearanceChanged;
  final ValueChanged<CastingSession?> onSessionChanged;

  @override
  State<DivinationPage> createState() => _DivinationPageState();
}

class _DivinationPageState extends State<DivinationPage> {
  final _question = TextEditingController();
  late final DivinationEngine _engine;
  DivinationMethod _method = DivinationMethod.lueShi;
  Gender _gender = Gender.male;
  late CastingSession? _session = widget.initialSession;
  DivinationResult? get _result => _session?.result;

  @override
  void initState() {
    super.initState();
    _engine = DivinationEngine(widget.corpus);
    final initial = widget.initialSession;
    if (initial != null) {
      _method = initial.method;
      _gender = initial.gender;
      _question.text = initial.question;
    }
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      _session = _engine.start(
        method: _method,
        question: _question.text.trim(),
        gender: _gender,
      );
    });
    widget.onSessionChanged(_session);
  }

  void _advance({int? leftPile}) {
    setState(() {
      _session!.advance(leftPile: leftPile);
    });
    widget.onSessionChanged(_session!.isComplete ? null : _session);
  }

  Future<void> _abandonSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃本次起筮？'),
        content: const Text('当前步骤不会保存，可重新选择方法后再次起卦。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续本次'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认放弃'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _session = null);
    widget.onSessionChanged(null);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Row(
        children: [
          _SealMark(),
          SizedBox(width: 10),
          Text(
            '太初易筮',
            style: TextStyle(letterSpacing: 5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<AppAppearance>(
          tooltip: '界面样式',
          icon: Icon(switch (widget.appearance) {
            AppAppearance.yin => Icons.dark_mode_outlined,
            AppAppearance.yang => Icons.light_mode_outlined,
            AppAppearance.system => Icons.brightness_auto_outlined,
          }),
          onSelected: widget.onAppearanceChanged,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: AppAppearance.yin,
              child: Text('阴 · 夜色漆金'),
            ),
            const PopupMenuItem(
              value: AppAppearance.yang,
              child: Text('阳 · 宣纸日光'),
            ),
            const PopupMenuItem(
              value: AppAppearance.system,
              child: Text('随系统'),
            ),
          ],
        ),
        IconButton(
          tooltip: '方法说明',
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (_) => const _MethodNotes(),
          ),
          icon: const Icon(Icons.info_outline),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: Container(height: 1, color: _gold.withValues(alpha: .7)),
      ),
    ),
    body: SafeArea(
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ChinesePatternPainter()),
            ),
          ),
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
            children: [
              const Text(
                '以问立意，以卦观变',
                style: TextStyle(color: _gold, fontSize: 13, letterSpacing: 3),
              ),
              const SizedBox(height: 8),
              Text(
                '持诚问事，静候卦成',
                style: TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _question,
                maxLines: 2,
                enabled: _session == null || _session!.isComplete,
                decoration: const InputDecoration(
                  labelText: '此刻想问什么？（可留空）',
                  hintText: '例如：是否该接受这份工作机会？',
                ),
              ),
              const SizedBox(height: 16),
              ...DivinationMethod.values.map(
                (method) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _MethodCard(
                    method: method,
                    selected: _method == method,
                    onTap: _session == null || _session!.isComplete
                        ? () => setState(() => _method = method)
                        : null,
                  ),
                ),
              ),
              if (_method == DivinationMethod.lueShi ||
                  _method == DivinationMethod.eightSix ||
                  _method == DivinationMethod.sixtyFourSix) ...[
                const SizedBox(height: 7),
                Text(
                  '取手顺序',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: .78),
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<Gender>(
                  segments: const [
                    ButtonSegment(value: Gender.male, label: Text('男：左手优先')),
                    ButtonSegment(value: Gender.female, label: Text('女：右手优先')),
                  ],
                  selected: {_gender},
                  onSelectionChanged: _session == null || _session!.isComplete
                      ? (v) => setState(() => _gender = v.first)
                      : null,
                ),
              ],
              const SizedBox(height: 20),
              if (_session == null || _session!.isComplete)
                FilledButton.icon(
                  onPressed: _session == null || _session!.isComplete
                      ? _start
                      : _advance,
                  style: FilledButton.styleFrom(
                    backgroundColor: _vermilion,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                  ),
                  icon: Icon(
                    _session == null || _session!.isComplete
                        ? Icons.auto_awesome
                        : Icons.touch_app,
                  ),
                  label: Text(
                    _session == null || _session!.isComplete
                        ? '开始分步起卦 · ${_method.title}'
                        : _session!.actionLabel,
                  ),
                ),
              if (_session != null && !_session!.isComplete) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _abandonSession,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('放弃本次起筮'),
                ),
              ],
              if (_session != null &&
                  !_session!.isComplete &&
                  !_session!.isPrepared) ...[
                const SizedBox(height: 16),
                RitualPreparationCard(session: _session!, onConfirm: _advance),
              ],
              if (_session != null &&
                  !_session!.isComplete &&
                  _session!.isPrepared &&
                  _session!.method == DivinationMethod.lueShi) ...[
                const SizedBox(height: 16),
                LueShiPileCard(
                  key: ValueKey(_session!.completedSteps),
                  session: _session!,
                  onConfirm: (leftPile) => _advance(leftPile: leftPile),
                ),
              ],
              if (_session != null &&
                  !_session!.isComplete &&
                  _session!.isPrepared &&
                  _session!.method == DivinationMethod.traditional) ...[
                const SizedBox(height: 16),
                TraditionalYarrowCard(
                  key: ValueKey(_session!.completedSteps),
                  session: _session!,
                  onConfirm: (leftPile) => _advance(leftPile: leftPile),
                ),
              ],
              if (_session != null &&
                  !_session!.isComplete &&
                  _session!.isPrepared &&
                  (_session!.method == DivinationMethod.eightSix ||
                      _session!.method == DivinationMethod.sixtyFourSix ||
                      _session!.method ==
                          DivinationMethod.threeEightyFour)) ...[
                const SizedBox(height: 16),
                FortuneDrawCard(
                  key: ValueKey(
                    '${_session!.method}-${_session!.completedSteps}',
                  ),
                  session: _session!,
                  onDraw: _advance,
                ),
              ],
              if (_session != null) ...[
                const SizedBox(height: 16),
                CastingProgress(session: _session!),
              ],
              if (_result != null) ...[
                const SizedBox(height: 22),
                ResultCard(result: _result!),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.method,
    required this.selected,
    required this.onTap,
  });
  final DivinationMethod method;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isYang = theme.brightness == Brightness.light;
    final foreground = theme.colorScheme.onSurface;
    return Card(
      color: selected
          ? (isYang ? const Color(0xffecd9b4) : const Color(0xff3a2a1d))
          : theme.cardTheme.color,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected
                    ? _vermilion
                    : foreground.withValues(alpha: .56),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      method.subtitle,
                      style: TextStyle(
                        color: foreground.withValues(alpha: .72),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SealMark extends StatelessWidget {
  const _SealMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 31,
    height: 31,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: _vermilion,
      border: Border.all(color: _gold, width: 1.2),
      borderRadius: BorderRadius.circular(3),
    ),
    child: const Text(
      '易',
      style: TextStyle(
        color: _paper,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ChinesePatternPainter extends CustomPainter {
  const _ChinesePatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cloud = Paint()
      ..color = _gold.withValues(alpha: .055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final origin in [
      Offset(size.width * .04, 76),
      Offset(size.width * .66, size.height * .32),
      Offset(size.width * .12, size.height * .73),
    ]) {
      final path = Path()
        ..moveTo(origin.dx, origin.dy)
        ..cubicTo(
          origin.dx + 18,
          origin.dy - 18,
          origin.dx + 42,
          origin.dy + 17,
          origin.dx + 60,
          origin.dy,
        )
        ..cubicTo(
          origin.dx + 75,
          origin.dy - 12,
          origin.dx + 91,
          origin.dy + 5,
          origin.dx + 105,
          origin.dy - 5,
        );
      canvas.drawPath(path, cloud);
      canvas.drawCircle(Offset(origin.dx + 38, origin.dy), 13, cloud);
      canvas.drawCircle(Offset(origin.dx + 67, origin.dy - 2), 10, cloud);
    }
    final lattice = Paint()
      ..color = _gold.withValues(alpha: .035)
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width; x += 42) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        lattice,
      );
      canvas.drawLine(
        Offset(x + 20, 0),
        Offset(x - size.height + 20, size.height),
        lattice,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChinesePatternPainter oldDelegate) => false;
}

enum SplitMode { manual, automatic }

class LueShiPileCard extends StatefulWidget {
  const LueShiPileCard({
    super.key,
    required this.session,
    required this.onConfirm,
  });
  final CastingSession session;
  final ValueChanged<int> onConfirm;

  @override
  State<LueShiPileCard> createState() => _LueShiPileCardState();
}

class _LueShiPileCardState extends State<LueShiPileCard> {
  final Random _random = Random.secure();
  var _leftPile = 24;
  var _mode = SplitMode.manual;

  bool get _hasTwoPiles => _leftPile > 0 && _leftPile < 49;

  void _setMode(SplitMode mode) {
    setState(() {
      _mode = mode;
      if (mode == SplitMode.automatic) {
        _leftPile = _random.nextInt(48) + 1;
      }
    });
  }

  void _setFromPosition(double x, double width) {
    final fraction = (x / width).clamp(0.0, 1.0);
    setState(() => _leftPile = (fraction * 49).round().clamp(0, 49));
  }

  @override
  Widget build(BuildContext context) {
    final stepLabel = ['上卦', '下卦', '动爻'][widget.session.methodStepsCompleted];
    return Card(
      color: _ritualCardColor(context, yin: const Color(0xff202b22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '第 ${widget.session.methodStepsCompleted + 1} 步 · 分签定$stepLabel',
              style: TextStyle(
                fontSize: 17,
                color: _ritualTitleColor(context, yin: _cyan),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.session.nextInstruction,
              style: TextStyle(color: _ritualBodyColor(context)),
            ),
            const SizedBox(height: 12),
            SegmentedButton<SplitMode>(
              segments: const [
                ButtonSegment(
                  value: SplitMode.manual,
                  icon: Icon(Icons.pan_tool_alt_outlined),
                  label: Text('亲自分堆'),
                ),
                ButtonSegment(
                  value: SplitMode.automatic,
                  icon: Icon(Icons.shuffle),
                  label: Text('自动分堆'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (value) => _setMode(value.first),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onHorizontalDragStart: _mode == SplitMode.manual
                      ? (details) => _setFromPosition(
                          details.localPosition.dx,
                          constraints.maxWidth,
                        )
                      : null,
                  onHorizontalDragUpdate: _mode == SplitMode.manual
                      ? (details) => _setFromPosition(
                          details.localPosition.dx,
                          constraints.maxWidth,
                        )
                      : null,
                  onTapDown: _mode == SplitMode.manual
                      ? (details) => _setFromPosition(
                          details.localPosition.dx,
                          constraints.maxWidth,
                        )
                      : null,
                  child: Container(
                    height: 166,
                    decoration: BoxDecoration(
                      color: _ritualSurfaceColor(
                        context,
                        yin: const Color(0xff171c15),
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _ritualBorderColor(
                          context,
                          yin: const Color(0xff607359),
                        ),
                      ),
                    ),
                    child: RitualSplitScene(
                      total: 49,
                      leftPile: _leftPile,
                      accent: _cyan,
                      material: RitualMaterial.bamboo,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            SplitQuantityBar(
              total: 49,
              leftPile: _leftPile,
              accent: _jade,
              enabled: _mode == SplitMode.manual,
              onChanged: (value) => setState(() => _leftPile = value),
            ),
            if (_mode == SplitMode.manual) ...[
              const SizedBox(height: 8),
              if (_hasTwoPiles)
                Text(
                  '在签列上横向划动，或拖动下方数量滑轨，确定分签位置。',
                  style: TextStyle(
                    color: _ritualMutedColor(context),
                    fontSize: 12,
                  ),
                )
              else
                const _InvalidSplitNotice(),
            ] else ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _leftPile = _random.nextInt(48) + 1),
                icon: const Icon(Icons.casino_outlined),
                label: const Text('自动分签'),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _hasTwoPiles
                  ? () => widget.onConfirm(_leftPile)
                  : null,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('确认本次分堆'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvalidSplitNotice extends StatelessWidget {
  const _InvalidSplitNotice();

  @override
  Widget build(BuildContext context) {
    final warning = _ritualTitleColor(context, yin: const Color(0xffffc1b8));
    return Row(
      children: [
        Icon(Icons.replay_outlined, color: warning, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '未成两堆，请重新分签后再确认。',
            style: TextStyle(color: warning, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class SplitQuantityBar extends StatelessWidget {
  const SplitQuantityBar({
    super.key,
    required this.total,
    required this.leftPile,
    required this.accent,
    required this.enabled,
    required this.onChanged,
  });

  final int total;
  final int leftPile;
  final Color accent;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '左 $leftPile',
            style: TextStyle(color: accent, fontWeight: FontWeight.w700),
          ),
          Text(
            '分签刻度 · 共 $total',
            style: TextStyle(color: _ritualMutedColor(context), fontSize: 12),
          ),
          Text(
            '右 ${total - leftPile}',
            style: TextStyle(color: _gold, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 7,
          activeTrackColor: accent,
          inactiveTrackColor: _gold.withValues(alpha: .32),
          thumbColor: _gold,
          overlayColor: _gold.withValues(alpha: .15),
          tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 1.2),
          activeTickMarkColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: .75),
          inactiveTickMarkColor: _gold.withValues(alpha: .45),
        ),
        child: Slider(
          min: 0,
          max: total.toDouble(),
          divisions: total,
          value: leftPile.toDouble(),
          onChanged: enabled ? (value) => onChanged(value.round()) : null,
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '0',
            style: TextStyle(color: _ritualMutedColor(context), fontSize: 11),
          ),
          Text(
            '全数',
            style: TextStyle(color: _ritualMutedColor(context), fontSize: 11),
          ),
        ],
      ),
    ],
  );
}

enum RitualMaterial { yarrow, bamboo, fortune }

class RitualSplitScene extends StatelessWidget {
  const RitualSplitScene({
    super.key,
    required this.total,
    required this.leftPile,
    required this.accent,
    required this.material,
  });

  final int total;
  final int leftPile;
  final Color accent;
  final RitualMaterial material;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.hasBoundedWidth
          ? constraints.maxWidth
          : MediaQuery.sizeOf(context).width - 64;
      final height = constraints.hasBoundedHeight
          ? constraints.maxHeight
          : 150.0;
      const side = 14.0;
      final innerWidth = (width - side * 2).clamp(1.0, double.infinity);
      final hasSplit = leftPile > 0 && leftPile < total;
      final gap = hasSplit ? (innerWidth * .065).clamp(10.0, 22.0) : 0.0;
      final stickWidth = (innerWidth / (total * 1.35)).clamp(2.4, 6.0);
      final split = side + innerWidth * leftPile / total;

      double positionFor(int index) {
        final inLeft = index < leftPile;
        final count = inLeft ? leftPile : total - leftPile;
        final start = inLeft ? side : split + gap / 2;
        final end = inLeft ? split - gap / 2 : width - side;
        if (count == 0) return start;
        if (count == 1) return (start + end) / 2 - stickWidth / 2;
        return start +
            (end - start) * (inLeft ? index : index - leftPile) / (count - 1) -
            stickWidth / 2;
      }

      return SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              top: 8,
              left: 0,
              width: width / 2,
              child: Center(
                child: Text(
                  '左手 $leftPile',
                  style: TextStyle(
                    color: _ritualMutedColor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 0,
              width: width / 2,
              child: Center(
                child: Text(
                  '右手 ${total - leftPile}',
                  style: TextStyle(
                    color: _ritualMutedColor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 33,
              bottom: 7,
              left: split,
              child: Container(width: 1, color: _gold.withValues(alpha: .75)),
            ),
            ...List.generate(total, (index) {
              final inLeft = index < leftPile;
              final x = positionFor(index);
              return AnimatedPositioned(
                key: ValueKey('stalk-$index'),
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeInOutCubic,
                left: x,
                bottom: 9,
                child: Transform.rotate(
                  angle: ((index % 5) - 2) * .018,
                  child: CustomPaint(
                    size: Size(stickWidth, 105),
                    painter: _RitualStalkPainter(
                      material: material,
                      accent: inLeft ? accent : _gold,
                      seed: index,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      );
    },
  );
}

class _RitualStalkPainter extends CustomPainter {
  const _RitualStalkPainter({
    required this.material,
    required this.accent,
    required this.seed,
  });
  final RitualMaterial material;
  final Color accent;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (material == RitualMaterial.bamboo) {
      final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(1.1, 3, size.width - 2.2, size.height - 4),
        const Radius.circular(2),
      );
      canvas.drawRRect(body, Paint()..color = const Color(0xffc98a36));
      canvas.drawRRect(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7
          ..color = const Color(0xff70451e),
      );
      final joints = Paint()
        ..color = const Color(0xff7b4a20)
        ..strokeWidth = 1;
      for (var y = 20.0; y < size.height - 4; y += 19) {
        canvas.drawLine(Offset(1.2, y), Offset(size.width - 1.2, y), joints);
      }
      canvas.drawCircle(
        Offset(size.width / 2, 7),
        1.8,
        Paint()..color = const Color(0xff9e392c),
      );
      return;
    }
    if (material == RitualMaterial.fortune) {
      final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(.4, 3, size.width - .8, size.height - 4),
        const Radius.circular(3),
      );
      canvas.drawRRect(body, Paint()..color = const Color(0xff8a4a28));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(.4, 3, size.width - .8, 17),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xffa92f2e),
      );
      return;
    }
    final stem = Paint()
      ..color = const Color(0xffb99d66)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final bend = ((seed % 5) - 2) * .65;
    final path = Path()
      ..moveTo(size.width / 2, size.height - 2)
      ..quadraticBezierTo(
        size.width / 2 + bend,
        size.height * .45,
        size.width / 2 - bend,
        11,
      );
    canvas.drawPath(path, stem);
    final leaf = Paint()
      ..color = const Color(0xff70845a)
      ..style = PaintingStyle.fill;
    for (final y in [35.0, 51.0, 67.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width / 2 + (seed.isEven ? 1.6 : -1.6), y),
          width: 3.5,
          height: 8,
        ),
        leaf,
      );
    }
    final flower = Paint()..color = const Color(0xffe7d7a8);
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(size.width / 2 + (i - 1) * 2, 10 + (i.isEven ? 1 : -1)),
        1.8,
        flower,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RitualStalkPainter oldDelegate) =>
      oldDelegate.material != material ||
      oldDelegate.accent != accent ||
      oldDelegate.seed != seed;
}

class TraditionalYarrowCard extends StatefulWidget {
  const TraditionalYarrowCard({
    super.key,
    required this.session,
    required this.onConfirm,
  });
  final CastingSession session;
  final ValueChanged<int> onConfirm;

  @override
  State<TraditionalYarrowCard> createState() => _TraditionalYarrowCardState();
}

class _TraditionalYarrowCardState extends State<TraditionalYarrowCard> {
  final Random _random = Random.secure();
  late int _leftPile;
  var _mode = SplitMode.manual;

  bool get _hasTwoPiles =>
      _leftPile > 0 && _leftPile < widget.session.traditionalRemaining;

  void _setMode(SplitMode mode) {
    setState(() {
      _mode = mode;
      if (mode == SplitMode.automatic) {
        final remaining = widget.session.traditionalRemaining;
        _leftPile = _random.nextInt(remaining - 1) + 1;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _leftPile = widget.session.traditionalRemaining ~/ 2;
  }

  void _setFromPosition(double x, double width) {
    final fraction = (x / width).clamp(0.0, 1.0);
    setState(
      () => _leftPile = (fraction * widget.session.traditionalRemaining)
          .round()
          .clamp(0, widget.session.traditionalRemaining),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.session.traditionalRemaining;
    return Card(
      color: _ritualCardColor(context, yin: const Color(0xff2b1d20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${lineName(widget.session.traditionalLine)} · 第 ${widget.session.traditionalChange} 变 / 三变成一爻',
              style: TextStyle(
                fontSize: 17,
                color: _ritualTitleColor(context, yin: const Color(0xffffc1b8)),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '当前以 $remaining 策进行分堆。请将策分为左右两手；确认后，系统会从右手取一，并以四数归余。',
              style: TextStyle(color: _ritualBodyColor(context), height: 1.4),
            ),
            const SizedBox(height: 12),
            SegmentedButton<SplitMode>(
              segments: const [
                ButtonSegment(
                  value: SplitMode.manual,
                  icon: Icon(Icons.pan_tool_alt_outlined),
                  label: Text('亲自分堆'),
                ),
                ButtonSegment(
                  value: SplitMode.automatic,
                  icon: Icon(Icons.shuffle),
                  label: Text('自动分堆'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (value) => _setMode(value.first),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                onHorizontalDragStart: _mode == SplitMode.manual
                    ? (details) => _setFromPosition(
                        details.localPosition.dx,
                        constraints.maxWidth,
                      )
                    : null,
                onHorizontalDragUpdate: _mode == SplitMode.manual
                    ? (details) => _setFromPosition(
                        details.localPosition.dx,
                        constraints.maxWidth,
                      )
                    : null,
                onTapDown: _mode == SplitMode.manual
                    ? (details) => _setFromPosition(
                        details.localPosition.dx,
                        constraints.maxWidth,
                      )
                    : null,
                child: Container(
                  height: 158,
                  decoration: BoxDecoration(
                    color: _ritualSurfaceColor(
                      context,
                      yin: const Color(0xff1d1215),
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _ritualBorderColor(
                        context,
                        yin: const Color(0xff6b4547),
                      ),
                    ),
                  ),
                  child: RitualSplitScene(
                    total: remaining,
                    leftPile: _leftPile,
                    accent: const Color(0xffffb0a7),
                    material: RitualMaterial.yarrow,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SplitQuantityBar(
              total: remaining,
              leftPile: _leftPile,
              accent: _vermilion,
              enabled: _mode == SplitMode.manual,
              onChanged: (value) =>
                  setState(() => _leftPile = value.clamp(0, remaining)),
            ),
            const SizedBox(height: 8),
            if (_mode == SplitMode.manual)
              _hasTwoPiles
                  ? Text(
                      '在策列上横向划动，或拖动下方数量滑轨，确定分堆位置。',
                      style: TextStyle(
                        color: _ritualMutedColor(context),
                        fontSize: 12,
                      ),
                    )
                  : const _InvalidSplitNotice()
            else
              OutlinedButton.icon(
                onPressed: () => setState(
                  () => _leftPile = _random.nextInt(remaining - 1) + 1,
                ),
                icon: const Icon(Icons.casino_outlined),
                label: const Text('自动分策'),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _hasTwoPiles
                  ? () => widget.onConfirm(_leftPile)
                  : null,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('确认本变并计算归余'),
            ),
          ],
        ),
      ),
    );
  }
}

class RitualPreparationCard extends StatelessWidget {
  const RitualPreparationCard({
    super.key,
    required this.session,
    required this.onConfirm,
  });

  final CastingSession session;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => Card(
    color: _ritualCardColor(context, yin: const Color(0xff2a1b1d)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '起筮准备',
            style: TextStyle(
              fontSize: 17,
              color: _ritualTitleColor(context, yin: const Color(0xffffc1b8)),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            session.nextInstruction,
            style: TextStyle(color: _ritualBodyColor(context), height: 1.5),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onConfirm,
            icon: const Icon(Icons.self_improvement_outlined),
            label: const Text('已完成准备，开始起筮'),
          ),
        ],
      ),
    ),
  );
}

class FortuneDrawCard extends StatefulWidget {
  const FortuneDrawCard({
    super.key,
    required this.session,
    required this.onDraw,
  });
  final CastingSession session;
  final VoidCallback onDraw;

  @override
  State<FortuneDrawCard> createState() => _FortuneDrawCardState();
}

class _FortuneDrawCardState extends State<FortuneDrawCard> {
  var _drawing = false;
  String? _errorMessage;

  String get _label => switch (widget.session.method) {
    DivinationMethod.eightSix => [
      '抽取上卦签',
      '抽取下卦签',
      '抽取动爻签',
    ][widget.session.methodStepsCompleted],
    DivinationMethod.sixtyFourSix => [
      '抽取本卦签',
      '抽取动爻签',
    ][widget.session.methodStepsCompleted],
    DivinationMethod.threeEightyFour => '抽取爻签',
    _ => '抽签',
  };

  Future<void> _draw() async {
    if (_drawing) return;
    setState(() => _drawing = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 520));
      if (mounted) widget.onDraw();
    } on Object {
      if (mounted) {
        setState(() {
          _drawing = false;
          _errorMessage = '本次抽取未完成，请重新尝试。';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    color: _ritualCardColor(context, yin: const Color(0xff2a1b1d)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _label,
            style: TextStyle(
              fontSize: 17,
              color: _ritualTitleColor(context, yin: const Color(0xffffc1b8)),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            widget.session.nextInstruction,
            style: TextStyle(color: _ritualBodyColor(context)),
          ),
          const SizedBox(height: 10),
          Center(
            child: SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  CustomPaint(
                    size: const Size(150, 118),
                    painter: const _FortuneCylinderPainter(),
                  ),
                  ...List.generate(
                    5,
                    (index) => Positioned(
                      bottom: 37,
                      left: 65 + index * 10.0,
                      child: Transform.rotate(
                        angle: (index - 2) * .075,
                        child: CustomPaint(
                          size: const Size(15, 100),
                          painter: _RitualStalkPainter(
                            material: RitualMaterial.fortune,
                            accent: _vermilion,
                            seed: index,
                          ),
                        ),
                      ),
                    ),
                  ),
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutBack,
                    offset: _drawing ? const Offset(0, -.62) : Offset.zero,
                    child: CustomPaint(
                      size: const Size(24, 142),
                      painter: const _RitualStalkPainter(
                        material: RitualMaterial.fortune,
                        accent: _vermilion,
                        seed: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: FilledButton.icon(
              onPressed: _drawing ? null : _draw,
              icon: const Icon(Icons.touch_app),
              label: Text(_drawing ? '签正在出筒…' : _label),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: _ritualTitleColor(context, yin: const Color(0xffffc1b8)),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _FortuneCylinderPainter extends CustomPainter {
  const _FortuneCylinderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * .6),
      width: 104,
      height: 75,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(15)),
      Paint()..color = const Color(0xff4e2720),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, 32),
        width: 104,
        height: 27,
      ),
      Paint()..color = const Color(0xff72352b),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, 32),
        width: 78,
        height: 15,
      ),
      Paint()..color = const Color(0xff160e10),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(15)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xffc79551),
    );
  }

  @override
  bool shouldRepaint(covariant _FortuneCylinderPainter oldDelegate) => false;
}

class CastingProgress extends StatelessWidget {
  const CastingProgress({super.key, required this.session});
  final CastingSession session;

  @override
  Widget build(BuildContext context) => Card(
    color: _ritualCardColor(context, yin: const Color(0xff231d16)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '起筮记录 · ${session.completedSteps}/${session.totalSteps}',
            style: TextStyle(
              color: _ritualTitleColor(context, yin: _cyan),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (!session.isComplete)
            Text(
              session.nextInstruction,
              style: TextStyle(color: _ritualBodyColor(context), height: 1.5),
            ),
          if (session.displayRecords.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...session.displayRecords.map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      style: TextStyle(
                        color: _ritualTitleColor(context, yin: _vermilion),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      record.detail,
                      style: TextStyle(
                        color: _ritualBodyColor(context),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '本步含义：${record.meaning}',
                      style: TextStyle(
                        color: _ritualBodyColor(context),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class ResultCard extends StatelessWidget {
  const ResultCard({super.key, required this.result});
  final DivinationResult result;

  @override
  Widget build(BuildContext context) {
    final hex = result.hexagram;
    final changed = result.changedHexagram;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final accent = _adaptiveAccent(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('本次签意', style: TextStyle(color: accent, letterSpacing: 2)),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${hex.number.toString().padLeft(2, '0')} · ${hex.name}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hex.symbol,
                        style: TextStyle(
                          color: accent,
                          fontSize: 18,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '上${hex.upper.name} · 下${hex.lower.name}',
                        style: TextStyle(
                          color: foreground.withValues(alpha: .72),
                        ),
                      ),
                    ],
                  ),
                ),
                HexagramGlyph(lines: result.lines, moving: result.movingLines),
              ],
            ),
            const Divider(height: 30),
            _ResultBlock(title: '卦辞', value: result.source.judgment),
            if (result.movingLines.isEmpty)
              const _ResultBlock(title: '占断', value: '本次为静卦，宜先参看本卦卦辞以体会当下之象。')
            else
              ...result.movingLines.map((line) {
                final reading = result.source.lines[line];
                return _ResultBlock(
                  title: '${lineName(line)}《占断》',
                  value:
                      '${reading?.title ?? ''}\n${reading?.divination ?? '此爻暂未收录占断内容。'}',
                );
              }),
            if (changed != null)
              _ResultBlock(
                title: '之卦',
                value: '第 ${changed.number} 卦《${changed.name}》',
              ),
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('查看起卦记录', style: TextStyle(fontSize: 13)),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    result.trace,
                    style: TextStyle(
                      color: foreground.withValues(alpha: .76),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '解签内容依据《高岛易断占断破解》所收录的逐条《占》。本应用仅供传统文化学习与个人省思之用。',
                  style: TextStyle(
                    color: foreground.withValues(alpha: .66),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultBlock extends StatelessWidget {
  const _ResultBlock({required this.title, required this.value});
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _vermilion,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(height: 1.55)),
      ],
    ),
  );
}

class HexagramGlyph extends StatelessWidget {
  const HexagramGlyph({super.key, required this.lines, required this.moving});
  final List<bool> lines;
  final List<int> moving;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 84,
    height: 142,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (visualIndex) {
        final lineIndex = 5 - visualIndex;
        final active = moving.contains(lineIndex + 1);
        final yang = lines[lineIndex];
        return Row(
          children: [
            Expanded(
              child: Container(height: 5, color: active ? _vermilion : _cyan),
            ),
            if (!yang) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Container(height: 5, color: active ? _vermilion : _cyan),
              ),
            ],
          ],
        );
      }),
    ),
  );
}

class _MethodNotes extends StatelessWidget {
  const _MethodNotes();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '使用说明',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 12),
        Text('本筮、中筮、略筮按筮竹“变数”区分。本应用收录传统本筮、49 签略筮与抽签简法；中筮法因书中未载完整操作，暂不单列入口。'),
        SizedBox(height: 10),
        Text('八卦签、64 卦签、384 爻签为高岛晚年所用的直接抽签简法。自动分签仅在本机完成，不上传占问内容或起筮记录。'),
      ],
    ),
  );
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
  String get actionLabel =>
      isComplete ? '重新起卦' : '完成第 ${completedSteps + 1} 步 / $totalSteps';
  String get nextInstruction {
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
  String get symbol => '${upper.symbol}${lower.symbol}';
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
