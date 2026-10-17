import 'package:flutter/material.dart';

class _NoAnim extends PageTransitionsBuilder {
  const _NoAnim();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) => child;
}

ThemeData nexvoraTheme(Brightness b, Color seed, bool anim) {
  final dark = b == Brightness.dark;
  final cs = ColorScheme.fromSeed(seedColor: seed, brightness: b);
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: dark ? const Color(0xFF0A0A0D) : const Color(0xFFF4F4F6),
    appBarTheme: AppBarTheme(backgroundColor: dark ? const Color(0xFF0A0A0D) : const Color(0xFFF4F4F6), centerTitle: true),
    pageTransitionsTheme: anim
        ? const PageTransitionsTheme()
        : const PageTransitionsTheme(builders: {TargetPlatform.android: _NoAnim(), TargetPlatform.iOS: _NoAnim()}),
  );
}
