import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'session.dart';
import 'ui.dart';
import 'ui_style.dart';

export 'session.dart';
export 'ui.dart';
export 'ui_style.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final corpus = await SourceCorpus.load();
  SharedPreferences? preferences;
  try {
    preferences = await SharedPreferences.getInstance();
  } on Object catch (error, stackTrace) {
    debugPrint('偏好初始化失败：$error\n$stackTrace');
  }
  runApp(CyberYiApp(corpus: corpus, preferences: preferences));
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
  Future<void> _pendingPersistence = Future<void>.value();

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
        unawaited(_persistSession(null));
      }
    }
  }

  Future<void> _setAppearance(AppAppearance value) async {
    setState(() => _appearance = value);
    await _persistPreference(_appearanceStorageKey, value.storageKey);
  }

  Future<void> _persistSession(CastingSession? session) async {
    // 入队时生成快照，避免排队期间会话继续变化。
    final snapshot = session == null || session.isComplete
        ? null
        : jsonEncode(session.toJson());
    await _persistPreference(_sessionStorageKey, snapshot);
  }

  Future<void> _persistPreference(String key, String? value) {
    final operation = _pendingPersistence.then((_) async {
      final preferences = widget.preferences;
      if (preferences == null) return;
      try {
        final succeeded = value == null
            ? await preferences.remove(key)
            : await preferences.setString(key, value);
        if (!succeeded) {
          throw StateError('SharedPreferences 返回 false');
        }
      } on Object catch (error, stackTrace) {
        debugPrint('持久化失败（$key）：$error\n$stackTrace');
      }
    });
    _pendingPersistence = operation;
    return operation;
  }

  ThemeData _theme(Brightness brightness) {
    final isYang = brightness == Brightness.light;
    final foreground = isYang ? const Color(0xff332317) : kPaper;
    final baseTextTheme = ThemeData(
      brightness: brightness,
      fontFamily: kAppFont,
    ).textTheme;
    return ThemeData(
      fontFamily: kAppFont,
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: isYang ? const Color(0xfff4ead2) : kInk,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kGold,
        brightness: brightness,
        surface: isYang ? const Color(0xfffff7e5) : kPanel,
      ).copyWith(onSurface: foreground, onSurfaceVariant: foreground),
      textTheme: baseTextTheme.apply(
        bodyColor: foreground,
        displayColor: foreground,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isYang ? const Color(0xfff4ead2) : kInk,
        foregroundColor: isYang ? const Color(0xff382617) : kPaper,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: isYang ? const Color(0xfffff7e5) : kPanel,
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
        labelStyle: const TextStyle(color: kGold),
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
          borderSide: const BorderSide(color: kGold, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: kVermilion,
          foregroundColor: kPaper,
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
      onAppearanceChanged: (value) => unawaited(_setAppearance(value)),
      onSessionChanged: (session) => unawaited(_persistSession(session)),
    ),
  );
}

const _appearanceStorageKey = 'appearance';
const _sessionStorageKey = 'casting_session';
