import 'package:flutter/material.dart';
import '../core/core.dart';
import 'boot.dart';
import 'home.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool reg = false, busy = false, hide = true;
  final user = TextEditingController(), email = TextEditingController(), pass = TextEditingController();

  Future<void> submit() async {
    setState(() => busy = true);
    final ok = await act(context, () async {
      final r = reg
          ? await Api.post('/api/register', {'username': user.text.trim(), 'email': email.text.trim(), 'password': pass.text})
          : await Api.post('/api/login', {'identity': user.text.trim(), 'password': pass.text});
      await Api.setToken(r['token']);
      Api.me = r['user'];
    }, reg ? 'Akun dibuat' : 'Login berhasil');
    if (!mounted) return;
    setState(() => busy = false);
    if (ok) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Home()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.asset('assets/logo.png', width: 80, height: 80)),
                const SizedBox(height: 8),
                const Text('NEXVORA', style: TextStyle(fontSize: 18, letterSpacing: 5, fontWeight: FontWeight.w300)),
                const SizedBox(height: 8),
                Text(reg ? 'Buat Akun' : 'Masuk', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 24),
                TextField(controller: user, decoration: InputDecoration(labelText: reg ? 'Username' : 'Username atau email', prefixIcon: const Icon(Icons.person), border: const OutlineInputBorder())),
                if (reg) ...[
                  const SizedBox(height: 12),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email), border: OutlineInputBorder())),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: pass,
                  obscureText: hide,
                  decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock), border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => hide = !hide))),
                ),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Tunggu...' : (reg ? 'Daftar' : 'Masuk')))),
                TextButton(onPressed: () => setState(() => reg = !reg), child: Text(reg ? 'Sudah punya akun? Masuk' : 'Belum punya akun? Daftar')),
                TextButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Boot())), child: const Text('Ganti server')),
              ]),
            ),
          ),
        ),
      );
}
