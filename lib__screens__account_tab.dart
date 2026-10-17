import 'package:flutter/material.dart';
import '../core/core.dart';
import 'boot.dart';
import 'auth_page.dart';
import 'history_page.dart';
import 'security_page.dart';
import 'backup_page.dart';
import 'feedback_page.dart';
import 'about_page.dart';
import 'admin/admin_home.dart';

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: AppSettings.i,
        builder: (c, _) {
          final s = AppSettings.i;
          return ListView(padding: const EdgeInsets.all(12), children: [
            ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text('${Api.me['username']}'), subtitle: Text('${Api.me['email']} • ${Api.me['role']}')),
            const Padding(padding: EdgeInsets.fromLTRB(4, 8, 4, 4), child: Text('Tema', style: TextStyle(fontWeight: FontWeight.bold))),
            GradCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.dark, label: Text('Gelap')),
                    ButtonSegment(value: ThemeMode.light, label: Text('Terang')),
                    ButtonSegment(value: ThemeMode.system, label: Text('Sistem')),
                  ],
                  selected: {s.mode},
                  onSelectionChanged: (v) => s.setMode(v.first),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  for (int i = 0; i < AppSettings.seeds.length; i++)
                    GestureDetector(
                      onTap: () => s.setSeed(i),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(color: AppSettings.seeds[i], shape: BoxShape.circle, border: s.seed == i ? Border.all(color: Colors.white, width: 2.5) : null),
                      ),
                    ),
                ]),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Animasi'), value: s.anim, onChanged: (v) => s.setAnim(v)),
              ]),
            ),
            const SizedBox(height: 8),
            MenuTile(icon: Icons.history, title: 'Riwayat aktivitas', onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const HistoryPage()))),
            MenuTile(icon: Icons.security, title: 'Keamanan & Offline', subtitle: 'PIN, fingerprint, auto lock, mode offline', onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const SecurityPage()))),
            MenuTile(icon: Icons.backup, title: 'Backup & Restore', subtitle: 'Export, import, cadangan', onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const BackupPage()))),
            MenuTile(icon: Icons.feedback, title: 'Masukan & Laporan Bug', onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const FeedbackPage()))),
            MenuTile(icon: Icons.info, title: 'Tentang, FAQ, Tutorial', onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const AboutPage()))),
            if (Api.me['role'] == 'admin') MenuTile(icon: Icons.admin_panel_settings, title: 'Admin', onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const AdminPage()))),
            MenuTile(
              icon: Icons.email,
              title: 'Ganti email',
              onTap: () async {
                final f = await form(c, 'Ganti email', ['Email baru']);
                if (f == null || !c.mounted) return;
                await act(c, () async => Api.me = (await Api.put('/api/me', {'email': f['Email baru']}))['user']);
              },
            ),
            MenuTile(
              icon: Icons.lock,
              title: 'Ganti password',
              onTap: () async {
                final f = await form(c, 'Ganti password', ['Password lama', 'Password baru'], secret: ['Password lama', 'Password baru']);
                if (f == null || !c.mounted) return;
                await act(c, () => Api.post('/api/me/password', {'old': f['Password lama'], 'new': f['Password baru']}));
              },
            ),
            MenuTile(icon: Icons.dns, title: 'Ganti server', subtitle: Api.base, onTap: () => Navigator.pushReplacement(c, MaterialPageRoute(builder: (_) => const Boot()))),
            MenuTile(
              icon: Icons.logout,
              title: 'Keluar',
              onTap: () async {
                await Api.setToken('');
                if (c.mounted) Navigator.pushReplacement(c, MaterialPageRoute(builder: (_) => const AuthPage()));
              },
            ),
          ]);
        },
      );
}
