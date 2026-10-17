import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static final AppSettings i = AppSettings();
  ThemeMode mode = ThemeMode.dark;
  int seed = 0;
  bool anim = true;
  bool offline = true;
  static const seeds = [Color(0xFF9A9AFF), Color(0xFF6FD6A0), Color(0xFFFF9F7A), Color(0xFF5CC8FF), Color(0xFFFF7AB6)];

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    mode = ThemeMode.values[(p.getInt('mode') ?? 2).clamp(0, 2)];
    seed = (p.getInt('seed') ?? 0).clamp(0, seeds.length - 1);
    anim = p.getBool('anim') ?? true;
    offline = p.getBool('offline') ?? true;
  }

  Future<void> reload() async {
    await load();
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('mode', mode.index);
    await p.setInt('seed', seed);
    await p.setBool('anim', anim);
    await p.setBool('offline', offline);
    notifyListeners();
  }

  Future<void> setMode(ThemeMode m) { mode = m; return _save(); }
  Future<void> setSeed(int s) { seed = s; return _save(); }
  Future<void> setAnim(bool a) { anim = a; return _save(); }
  Future<void> setOffline(bool o) { offline = o; return _save(); }
}
