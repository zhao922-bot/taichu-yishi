import 'dart:math';

import 'package:flutter/material.dart';

import 'session.dart';
import 'ui_style.dart';

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
  var _splitMode = SplitMode.manual;
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
    try {
      setState(() {
        _session!.advance(leftPile: leftPile);
      });
    } on ArgumentError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message?.toString() ?? '分堆无效，请重新分堆后再确认。'),
        ),
      );
      return;
    }
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
        child: Container(height: 1, color: kGold.withValues(alpha: .7)),
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
                style: TextStyle(color: kGold, fontSize: 13, letterSpacing: 3),
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
                  onPressed: _start,
                  style: FilledButton.styleFrom(
                    backgroundColor: kVermilion,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                  ),
                  icon: const Icon(Icons.auto_awesome),
                  label: Text('开始分步起卦 · ${_method.title}'),
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
                  initialMode: _splitMode,
                  onModeChanged: (mode) => setState(() => _splitMode = mode),
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
                  initialMode: _splitMode,
                  onModeChanged: (mode) => setState(() => _splitMode = mode),
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
                    ? kVermilion
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
      color: kVermilion,
      border: Border.all(color: kGold, width: 1.2),
      borderRadius: BorderRadius.circular(3),
    ),
    child: const Text(
      '易',
      style: TextStyle(
        color: kPaper,
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
      ..color = kGold.withValues(alpha: .055)
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
      ..color = kGold.withValues(alpha: .035)
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
    required this.initialMode,
    required this.onModeChanged,
  });
  final CastingSession session;
  final ValueChanged<int> onConfirm;
  final SplitMode initialMode;
  final ValueChanged<SplitMode> onModeChanged;

  @override
  State<LueShiPileCard> createState() => _LueShiPileCardState();
}

class _LueShiPileCardState extends State<LueShiPileCard> {
  final Random _random = Random.secure();
  late int _leftPile;
  late var _mode = widget.initialMode;

  bool get _hasTwoPiles => _leftPile > 0 && _leftPile < 49;

  @override
  void initState() {
    super.initState();
    _leftPile = _mode == SplitMode.automatic ? _random.nextInt(48) + 1 : 24;
  }

  void _setMode(SplitMode mode) {
    widget.onModeChanged(mode);
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
    final stepIndex = widget.session.methodStepsCompleted;
    final stepLabel = stepIndex < 3 ? ['上卦', '下卦', '动爻'][stepIndex] : '完成';
    return Card(
      color: ritualCardColor(context, yin: const Color(0xff202b22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '第 ${widget.session.methodStepsCompleted + 1} 步 · 分签定$stepLabel',
              style: TextStyle(
                fontSize: 17,
                color: ritualTitleColor(context, yin: kCyan),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.session.nextInstruction,
              style: TextStyle(color: ritualBodyColor(context)),
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
                  onTapUp: _mode == SplitMode.manual
                      ? (details) => _setFromPosition(
                          details.localPosition.dx,
                          constraints.maxWidth,
                        )
                      : null,
                  child: Container(
                    height: 166,
                    decoration: BoxDecoration(
                      color: ritualSurfaceColor(
                        context,
                        yin: const Color(0xff171c15),
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: ritualBorderColor(
                          context,
                          yin: const Color(0xff607359),
                        ),
                      ),
                    ),
                    child: RitualSplitScene(
                      total: 49,
                      leftPile: _leftPile,
                      accent: kCyan,
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
              accent: kJade,
              enabled: _mode == SplitMode.manual,
              onChanged: (value) => setState(() => _leftPile = value),
            ),
            if (_mode == SplitMode.manual) ...[
              const SizedBox(height: 8),
              if (_hasTwoPiles)
                Text(
                  '在签列上横向划动，或拖动下方数量滑轨，确定分签位置。',
                  style: TextStyle(
                    color: ritualMutedColor(context),
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
    final warning = ritualTitleColor(context, yin: const Color(0xffffc1b8));
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
            style: TextStyle(color: ritualMutedColor(context), fontSize: 12),
          ),
          Text(
            '右 ${total - leftPile}',
            style: TextStyle(color: kGold, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 7,
          activeTrackColor: accent,
          inactiveTrackColor: kGold.withValues(alpha: .32),
          thumbColor: kGold,
          overlayColor: kGold.withValues(alpha: .15),
          tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 1.2),
          activeTickMarkColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: .75),
          inactiveTickMarkColor: kGold.withValues(alpha: .45),
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
            style: TextStyle(color: ritualMutedColor(context), fontSize: 11),
          ),
          Text(
            '全数',
            style: TextStyle(color: ritualMutedColor(context), fontSize: 11),
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
                    color: ritualMutedColor(context),
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
                    color: ritualMutedColor(context),
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
              child: Container(width: 1, color: kGold.withValues(alpha: .75)),
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
                      accent: inLeft ? accent : kGold,
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
    required this.initialMode,
    required this.onModeChanged,
  });
  final CastingSession session;
  final ValueChanged<int> onConfirm;
  final SplitMode initialMode;
  final ValueChanged<SplitMode> onModeChanged;

  @override
  State<TraditionalYarrowCard> createState() => _TraditionalYarrowCardState();
}

class _TraditionalYarrowCardState extends State<TraditionalYarrowCard> {
  final Random _random = Random.secure();
  late int _leftPile;
  late var _mode = widget.initialMode;

  bool get _hasTwoPiles =>
      _leftPile > 0 && _leftPile < widget.session.traditionalRemaining;

  int _randomPile(int remaining) =>
      sampleTraditionalLeftPile(remaining, _random);

  void _setMode(SplitMode mode) {
    widget.onModeChanged(mode);
    setState(() {
      _mode = mode;
      if (mode == SplitMode.automatic) {
        _leftPile = _randomPile(widget.session.traditionalRemaining);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final remaining = widget.session.traditionalRemaining;
    _leftPile = _mode == SplitMode.automatic
        ? _randomPile(remaining)
        : remaining ~/ 2;
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
      color: ritualCardColor(context, yin: const Color(0xff2b1d20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${lineName(widget.session.traditionalLine)} · 第 ${widget.session.traditionalChange} 变 / 三变成一爻',
              style: TextStyle(
                fontSize: 17,
                color: ritualTitleColor(context, yin: const Color(0xffffc1b8)),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '当前以 $remaining 策进行分堆。请将策分为左右两手；确认后，系统会从右手取一，并以四数归余。',
              style: TextStyle(color: ritualBodyColor(context), height: 1.4),
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
                onTapUp: _mode == SplitMode.manual
                    ? (details) => _setFromPosition(
                        details.localPosition.dx,
                        constraints.maxWidth,
                      )
                    : null,
                child: Container(
                  height: 158,
                  decoration: BoxDecoration(
                    color: ritualSurfaceColor(
                      context,
                      yin: const Color(0xff1d1215),
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: ritualBorderColor(
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
              accent: kVermilion,
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
                        color: ritualMutedColor(context),
                        fontSize: 12,
                      ),
                    )
                  : const _InvalidSplitNotice()
            else
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _leftPile = _randomPile(remaining)),
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
    color: ritualCardColor(context, yin: const Color(0xff2a1b1d)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '起筮准备',
            style: TextStyle(
              fontSize: 17,
              color: ritualTitleColor(context, yin: const Color(0xffffc1b8)),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            session.nextInstruction,
            style: TextStyle(color: ritualBodyColor(context), height: 1.5),
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

  String get _label {
    if (widget.session.isComplete) return '抽签完成';
    return switch (widget.session.method) {
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
  }

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
    color: ritualCardColor(context, yin: const Color(0xff2a1b1d)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _label,
            style: TextStyle(
              fontSize: 17,
              color: ritualTitleColor(context, yin: const Color(0xffffc1b8)),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            widget.session.nextInstruction,
            style: TextStyle(color: ritualBodyColor(context)),
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
                            accent: kVermilion,
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
                        accent: kVermilion,
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
                color: ritualTitleColor(context, yin: const Color(0xffffc1b8)),
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
    color: ritualCardColor(context, yin: const Color(0xff231d16)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '起筮记录 · ${session.completedSteps}/${session.totalSteps}',
            style: TextStyle(
              color: ritualTitleColor(context, yin: kCyan),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (!session.isComplete)
            Text(
              session.nextInstruction,
              style: TextStyle(color: ritualBodyColor(context), height: 1.5),
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
                        color: ritualTitleColor(context, yin: kVermilion),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      record.detail,
                      style: TextStyle(
                        color: ritualBodyColor(context),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '本步含义：${record.meaning}',
                      style: TextStyle(
                        color: ritualBodyColor(context),
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
    final accent = adaptiveAccent(context);
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hex.upper.symbol,
                            style: TextStyle(
                              color: accent,
                              fontSize: 18,
                              letterSpacing: 3,
                            ),
                          ),
                          Text(
                            hex.lower.symbol,
                            style: TextStyle(
                              color: accent,
                              fontSize: 18,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
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
            color: kVermilion,
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
              child: Container(height: 5, color: active ? kVermilion : kCyan),
            ),
            if (!yang) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Container(height: 5, color: active ? kVermilion : kCyan),
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
