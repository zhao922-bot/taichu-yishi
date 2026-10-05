import 'package:flutter/material.dart';

const kInk = Color(0xff19130f);
const kPanel = Color(0xff292016);
const kJade = Color(0xff8eb49a);
const kGold = Color(0xffd2a65d);
const kVermilion = Color(0xffbd4b3f);
const kPaper = Color(0xfff0e0bb);
const kCyan = kJade;
const kAppFont = 'NotoSerifSC';

Color adaptiveAccent(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
    ? const Color(0xff416f55)
    : kCyan;

bool isYangTheme(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light;

Color ritualCardColor(BuildContext context, {required Color yin}) =>
    isYangTheme(context) ? const Color(0xfffff7e5) : yin;

Color ritualSurfaceColor(BuildContext context, {required Color yin}) =>
    isYangTheme(context) ? const Color(0xfffff9ea) : yin;

Color ritualBorderColor(BuildContext context, {required Color yin}) =>
    isYangTheme(context) ? const Color(0xffb68b4f) : yin;

Color ritualBodyColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface.withValues(alpha: .78);

Color ritualMutedColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface.withValues(alpha: .58);

Color ritualTitleColor(BuildContext context, {required Color yin}) =>
    isYangTheme(context) ? const Color(0xff8a3d34) : yin;