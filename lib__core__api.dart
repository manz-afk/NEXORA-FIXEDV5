import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'settings.dart';

class Api {
  static const defaultBase = 'http://38.253.224.75:3205';
  static String base = '';
  static String token = '';
  static Map<String, dynamic> me = {};

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    base = p.getString('base') ?? '';
    token = p.getString('token') ?? '';
  }

  static Future<void> setBase(String b) async {
    base = b.endsWith('/') ? b.substring(0, b.length - 1) : b;
    (await SharedPreferences.getInstance()).setString('base', base);
  }

  static Future<void> setToken(String t) async {
    token = t;
    final p = await SharedPreferences.getInstance();
    if (t.isEmpty) {
      p.remove('token');
      for (final k in p.getKeys().where((k) => k.startsWith('cache:')).toList()) {
        p.remove(k);
      }
    } else {
      p.setString('token', t);
    }
  }

  static Future<bool> ping(String url, [Duration t = const Duration(milliseconds: 1500)]) async {
    try {
      final r = await http.get(Uri.parse('$url/ping')).timeout(t);
      return r.statusCode == 200 && jsonDecode(r.body)['app'] == 'botapp';
    } catch (_) {
      return false;
    }
  }

  /// Cari server otomatis di localhost (port ditebak)
  static Future<String?> discover() async {
    final ports = <int>[
      ...List.generate(60, (i) => 3000 + i),
      ...List.generate(40, (i) => 8000 + i),
      ...List.generate(20, (i) => 5000 + i),
      ...List.generate(20, (i) => 4000 + i),
      ...List.generate(20, (i) => 9000 + i),
    ];
    final done = Completer<String?>();
    int left = ports.length;
    for (final p in ports) {
      final url = 'http://127.0.0.1:$p';
      ping(url).then((ok) {
        if (ok && !done.isCompleted) done.complete(url);
        if (--left == 0 && !done.isCompleted) done.complete(null);
      });
    }
    return done.future;
  }

  /// Cari port otomatis di host tertentu (mis. IP panel), tanpa perlu tahu port
  static Future<String?> discoverHost(String host) async {
    host = host.replaceAll(RegExp(r'^https?://'), '').replaceAll('/', '');
    final ports = <int>[
      ...List.generate(1000, (i) => 3000 + i),
      ...List.generate(40, (i) => 8000 + i),
      ...List.generate(100, (i) => 5000 + i),
      ...List.generate(20, (i) => 4000 + i),
      ...List.generate(20, (i) => 9000 + i),
      ...List.generate(100, (i) => 25500 + i),
      ...List.generate(100, (i) => 20000 + i),
    ];
    const batch = 100;
    for (var s = 0; s < ports.length; s += batch) {
      final chunk = ports.skip(s).take(batch).toList();
      final res = await Future.wait(chunk.map((p) async {
        final url = 'http://$host:$p';
        return await ping(url, const Duration(seconds: 3)) ? url : null;
      }));
      for (final r in res) {
        if (r != null) return r;
      }
    }
    return null;
  }

  static Future<dynamic> call(String m, String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$base$path');
    final h = {'Content-Type': 'application/json', if (token.isNotEmpty) 'Authorization': 'Bearer $token'};
    http.Response r;
    try {
      switch (m) {
        case 'GET':
          r = await http.get(uri, headers: h).timeout(const Duration(seconds: 30));
          break;
        case 'POST':
          r = await http.post(uri, headers: h, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 60));
          break;
        case 'PUT':
          r = await http.put(uri, headers: h, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 30));
          break;
        default:
          r = await http.delete(uri, headers: h).timeout(const Duration(seconds: 30));
      }
    } catch (_) {
      throw 'Tidak bisa terhubung ke server';
    }
    final j = r.body.isEmpty ? {} : jsonDecode(r.body);
    if (r.statusCode >= 400) throw (j['error'] ?? 'Error ${r.statusCode}').toString();
    return j;
  }

  static final ValueNotifier<bool> fromCache = ValueNotifier(false);
  static const _cachePaths = ['/api/tools', '/api/dashboard', '/api/news', '/api/favorites', '/api/history'];

  static Future<dynamic> get(String p) async {
    try {
      final r = await call('GET', p);
      fromCache.value = false;
      if (_cachePaths.contains(p)) {
        final sp = await SharedPreferences.getInstance();
        await sp.setString('cache:$p', jsonEncode(r));
      }
      return r;
    } catch (e) {
      if ('$e' == 'Tidak bisa terhubung ke server' && _cachePaths.contains(p) && AppSettings.i.offline) {
        final sp = await SharedPreferences.getInstance();
        final c = sp.getString('cache:$p');
        if (c != null) {
          fromCache.value = true;
          return jsonDecode(c);
        }
      }
      rethrow;
    }
  }
  static Future<dynamic> post(String p, [Map<String, dynamic>? b]) => call('POST', p, b);
  static Future<dynamic> put(String p, Map<String, dynamic> b) => call('PUT', p, b);
  static Future<dynamic> del(String p) => call('DELETE', p);
}
