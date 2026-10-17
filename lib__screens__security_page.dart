import 'package:flutter/material.dart';
import '../core/core.dart';

class SecurityPage extends StatelessWidget {
  const SecurityPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Keamanan & Offline')),
        body: ListenableBuilder(
          listenable: Listenable.merge([AppLock.i, AppSettings.i]),
          builder: (c, _) {
            final l = AppLock.i, s = AppSettings.i;
            void snack(String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
            return ListView(padding: const EdgeInsets.all(12), children: [
              GradCard(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('PIN aplikasi'),
                  subtitle: const Text('Kunci app dengan PIN 6 digit'),
                  value: l.pinOn,
                  onChanged: (v) async {
                    if (v) {
                      final f = await form(c, 'Buat PIN', ['PIN (6 digit)', 'Ulangi PIN'], secret: ['PIN (6 digit)', 'Ulangi PIN']);
                      if (f == null) return;
                      final a = f['PIN (6 digit)'] ?? '', b = f['Ulangi PIN'] ?? '';
                      if (!RegExp(r'^\d{6}$').hasMatch(a)) return snack('PIN harus 6 angka');
                      if (a != b) return snack('PIN tidak sama');
                      await l.setPin(a);
                    } else {
                      if (await confirm(c, 'Matikan PIN aplikasi?')) await l.removePin();
                    }
                  },
                ),
              ),
              GradCard(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fingerprint'),
                  subtitle: Text(l.pinOn ? 'Buka kunci dengan sidik jari' : 'Aktifkan PIN dulu'),
                  value: l.bioOn,
                  onChanged: l.pinOn
                      ? (v) async {
                          if (v && !await l.bioAvailable()) return snack('Sidik jari belum diatur di HP ini');
                          await l.setBio(v);
                        }
                      : null,
                ),
              ),
              GradCard(
                child: Row(children: [
                  const Expanded(child: Text('Auto lock')),
                  DropdownButton<int>(
                    value: l.minutes,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Langsung')),
                      DropdownMenuItem(value: 1, child: Text('1 menit')),
                      DropdownMenuItem(value: 5, child: Text('5 menit')),
                      DropdownMenuItem(value: 15, child: Text('15 menit')),
                      DropdownMenuItem(value: 30, child: Text('30 menit')),
                    ],
                    onChanged: l.pinOn ? (v) => l.setMinutes(v ?? 1) : null,
                  ),
                ]),
              ),
              GradCard(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mode offline'),
                  subtitle: const Text('Saat tidak ada koneksi, tampilkan data terakhir yang pernah dimuat'),
                  value: s.offline,
                  onChanged: (v) => s.setOffline(v),
                ),
              ),
              const Padding(padding: EdgeInsets.all(8), child: Text('PIN disimpan hanya di HP ini (tidak dikirim ke server). Kalau lupa PIN, hapus data app lewat pengaturan Android; akunmu tetap aman di server.', style: TextStyle(fontSize: 12, color: Colors.grey))),
            ]);
          },
        ),
      );
}
