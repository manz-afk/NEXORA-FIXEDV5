import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLock extends ChangeNotifier with WidgetsBindingObserver {
  static final AppLock i = AppLock();
  bool pinOn = false, bioOn = false, locked = false, _busy = false;
  int minutes = 1;
  String _hash = '', _salt = '';
  DateTime? _paused;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _hash = p.getString('pin_hash') ?? '';
    _salt = p.getString('pin_salt') ?? '';
    pinOn = (p.getBool('pin_on') ?? false) && _hash.isNotEmpty;
    bioOn = pinOn && (p.getBool('bio_on') ?? false);
    minutes = p.getInt('lock_min') ?? 1;
    locked = pinOn;
    WidgetsBinding.instance.addObserver(this);
  }

  String _h(String pin, String salt) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<void> setPin(String pin) async {
    final r = Random.secure();
    _salt = base64Url.encode(List<int>.generate(12, (_) => r.nextInt(256)));
    _hash = _h(pin, _salt);
    pinOn = true;
    final p = await SharedPreferences.getInstance();
    await p.setString('pin_hash', _hash);
    await p.setString('pin_salt', _salt);
    await p.setBool('pin_on', true);
    notifyListeners();
  }

  Future<void> removePin() async {
    pinOn = false;
    bioOn = false;
    locked = false;
    _hash = '';
    _salt = '';
    final p = await SharedPreferences.getInstance();
    for (final k in ['pin_hash', 'pin_salt', 'pin_on', 'bio_on']) {
      await p.remove(k);
    }
    notifyListeners();
  }

  bool check(String pin) => pinOn && _h(pin, _salt) == _hash;

  void unlock() {
    locked = false;
    notifyListeners();
  }

  Future<void> setBio(bool v) async {
    bioOn = v;
    (await SharedPreferences.getInstance()).setBool('bio_on', v);
    notifyListeners();
  }

  Future<void> setMinutes(int m) async {
    minutes = m;
    (await SharedPreferences.getInstance()).setInt('lock_min', m);
    notifyListeners();
  }

  Future<bool> bioAvailable() async {
    try {
      final a = LocalAuthentication();
      return await a.canCheckBiometrics && (await a.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authBio() async {
    if (!bioOn) return false;
    _busy = true;
    try {
      return await LocalAuthentication().authenticate(
        localizedReason: 'Buka Nexvora',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    } finally {
      _busy = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (!pinOn || _busy) return;
    if (s == AppLifecycleState.paused) {
      _paused = DateTime.now();
    } else if (s == AppLifecycleState.resumed) {
      final t = _paused;
      _paused = null;
      if (t != null && !locked && DateTime.now().difference(t).inSeconds >= minutes * 60) {
        locked = true;
        notifyListeners();
      }
    }
  }
}
