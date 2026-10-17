import 'package:flutter/material.dart';
import '../core/core.dart';
import 'auth_page.dart';
import 'home.dart';

class Boot extends StatefulWidget {
  const Boot({super.key});
  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  String status = 'Mencari server...';
  bool manual = false;
  final urlC = TextEditingController();

  @override
  void initState() {
    super.initState();
    go();
  }

  Future<void> go() async {
    setState(() { manual = false; status = 'Mencari server...'; });
    await Api.load();
    bool ok = Api.base.isNotEmpty && await Api.ping(Api.base, const Duration(seconds: 4));
    if (!ok && await Api.ping(Api.defaultBase, const Duration(seconds: 4))) { await Api.setBase(Api.defaultBase); ok = true; }
    if (!ok) {
      final f = await Api.discover();
      if (f != null) { await Api.setBase(f); ok = true; }
    }
    if (!ok) { if (mounted) setState(() { manual = true; status = 'Server tidak ketemu otomatis. Masukkan alamat server.'; }); return; }
    await next();
  }

  Future<void> next() async {
    if (Api.token.isNotEmpty) {
      try {
        Api.me = (await Api.get('/api/me'))['user'];
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Home()));
        return;
      } catch (_) { await Api.setToken(''); }
    }
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthPage()));
  }

  Future<void> useManual() async {
    var u = urlC.text.trim();
    if (u.isEmpty) return;
    final hasPort = RegExp(r':\d+(/|$)').hasMatch(u.replaceAll(RegExp(r'^https?://'), ''));
    final isHttps = u.startsWith('https://');
    if (!hasPort && !isHttps) {
      setState(() => status = 'Mencari port di $u ...');
      final f = await Api.discoverHost(u);
      if (f != null) { await Api.setBase(f); await next(); return; }
      setState(() { status = 'Tidak ada server di $u. Cek apakah server panel sudah Start.'; manual = true; });
      return;
    }
    if (!u.startsWith('http')) u = 'http://$u';
    setState(() => status = 'Mengecek...');
    if (await Api.ping(u)) { await Api.setBase(u); await next(); }
    else { setState(() { status = 'Server tidak merespon di $u'; manual = true; }); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.asset('assets/logo.png', width: 96, height: 96)),
              const SizedBox(height: 12),
              const Text('NEXVORA', style: TextStyle(fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.w300)),
              const Text('Akses Server', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              Text(status, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              if (!manual) const CircularProgressIndicator(),
              if (manual) ...[
                TextField(controller: urlC, decoration: const InputDecoration(labelText: 'IP server (port boleh dikosongkan)', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  FilledButton(onPressed: useManual, child: const Text('Hubungkan')),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: go, child: const Text('Cari ulang')),
                ]),
              ],
            ]),
          ),
        ),
      );
}
