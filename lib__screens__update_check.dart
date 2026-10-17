import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/core.dart';

bool _newer(String a, String b) {
  List<int> p(String s) => s.split('+').first.split('.').map((x) => int.tryParse(x) ?? 0).toList();
  final x = p(a), y = p(b);
  for (int i = 0; i < 3; i++) {
    final xi = i < x.length ? x[i] : 0, yi = i < y.length ? y[i] : 0;
    if (xi != yi) return xi > yi;
  }
  return false;
}

Future<void> checkUpdate(BuildContext c, {bool manual = false}) async {
  void snack(String m) {
    if (manual && c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
  }

  try {
    final info = await PackageInfo.fromPlatform();
    final r = await Api.get('/api/app-version');
    final v = '${r['version'] ?? ''}';
    if (v.isEmpty || !_newer(v, info.version)) return snack('Sudah versi terbaru (${info.version})');
    if (!c.mounted) return;
    final url = '${r['url'] ?? ''}';
    await showDialog(
      context: c,
      builder: (d) => AlertDialog(
        title: Text('Versi $v tersedia'),
        content: Text('Versi kamu ${info.version}.\n${r['notes'] ?? ''}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Nanti')),
          if (url.isNotEmpty) FilledButton(onPressed: () { Navigator.pop(d); launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); }, child: const Text('Unduh')),
        ],
      ),
    );
  } catch (e) {
    snack('$e');
  }
}
