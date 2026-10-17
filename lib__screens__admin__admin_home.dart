import 'package:flutter/material.dart';
import '../../core/core.dart';
import 'admin_users.dart';
import 'admin_news.dart';
import 'admin_tools.dart';
import 'admin_custom.dart';
import 'admin_feedback.dart';
import 'admin_update.dart';
import 'admin_logs.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});
  void go(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute(builder: (_) => w));
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          SizedBox(
            height: 92,
            child: Loader(
              load: () => Api.get('/api/admin/stats'),
              build: (c, s, r) {
                Widget st(String l, String v) => Expanded(
                      child: GradCard(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 11, color: Colors.grey)), Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))])),
                    );
                return Row(children: [st('Pengguna', '${s['users']}'), const SizedBox(width: 8), st('Fitur', '${s['tools']}'), const SizedBox(width: 8), st('Riwayat', '${s['history']}')]);
              },
            ),
          ),
          MenuTile(icon: Icons.add_circle, title: 'Tambah fitur', subtitle: 'Buat fitur baru dari web atau kode, langsung tampil di semua pengguna', onTap: () => go(context, const AdminCustomPage())),
          MenuTile(icon: Icons.people, title: 'Pengguna aplikasi', subtitle: 'Ban, ubah role', onTap: () => go(context, const AdminUsers())),
          MenuTile(icon: Icons.pause_circle, title: 'Suspend fitur', subtitle: 'Matikan fitur yang rusak', onTap: () => go(context, const AdminToolsPage())),
          MenuTile(icon: Icons.campaign, title: 'Pengumuman', subtitle: 'Tulis & hapus', onTap: () => go(context, const AdminNewsPage())),
          MenuTile(icon: Icons.feedback, title: 'Feedback & Bug', subtitle: 'Masukan dari pengguna', onTap: () => go(context, const AdminFeedbackPage())),
          MenuTile(icon: Icons.system_update, title: 'Update aplikasi', subtitle: 'Versi terbaru & link APK', onTap: () => go(context, const AdminUpdatePage())),
          MenuTile(icon: Icons.history, title: 'Log aktivitas', onTap: () => go(context, const AdminLogs())),
        ]),
      );
}
