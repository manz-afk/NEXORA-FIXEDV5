import 'package:flutter/material.dart';
import '../core/core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'update_check.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tentang')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          const SizedBox(height: 8),
          Center(child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.asset('assets/logo.png', width: 84, height: 84))),
          const SizedBox(height: 10),
          const Center(child: Text('NEXVORA', style: TextStyle(fontSize: 20, letterSpacing: 6, fontWeight: FontWeight.w300))),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (c, s) => Center(child: Padding(padding: const EdgeInsets.all(6), child: Text('Versi ${s.data?.version ?? '-'} • by manz', style: const TextStyle(color: Colors.grey)))),
          ),
          const SizedBox(height: 10),
          MenuTile(icon: Icons.help_outline, title: 'FAQ', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FaqPage()))),
          MenuTile(icon: Icons.school, title: 'Tutorial', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TutorialPage()))),
          MenuTile(icon: Icons.new_releases, title: 'Changelog', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangelogPage()))),
          MenuTile(icon: Icons.system_update, title: 'Cek pembaruan', onTap: () => checkUpdate(context, manual: true)),
        ]),
      );
}

Widget _page(String title, List<Widget> children) => Scaffold(appBar: AppBar(title: Text(title)), body: ListView(padding: const EdgeInsets.all(12), children: children));

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});
  static const items = [
    ['Server tidak ketemu?', 'Pastikan server menyala. Di layar Akses Server tekan "Cari ulang", atau ketik alamat manual (IP-atau-domain:port). Server di panel harus bisa diakses dari internet.'],
    ['Fitur tertulis "dinonaktifkan"?', 'Admin sedang mematikan fitur itu karena rusak atau perawatan. Fitur yang error beruntun juga dimatikan otomatis dan dicoba lagi setelah 15 menit.'],
    ['Cari Preset tidak menemukan link?', 'Caption video yang tidak berisi link tidak bisa diproses. Komentar TikTok tidak bisa dibaca otomatis: salin komentar dari TikTok lalu tempel di kolom Komentar.'],
    ['Video AM Zarvida gagal diunduh?', 'Ekspor 4K bisa sangat besar. Coba resolusi lebih kecil, pastikan penyimpanan cukup, dan izinkan akses foto/video.'],
    ['Kenapa status WA tetap kurang tajam?', 'WhatsApp mengompres ulang semua foto dan video status. Pakai mode "WA Status" (1080p, 30fps) yang paling pas; 4K/120fps tidak terlihat di status.'],
    ['Lupa PIN?', 'PIN hanya tersimpan di HP ini. Hapus data app lewat pengaturan Android lalu login lagi; akunmu tetap ada di server.'],
    ['Data hilang saat ganti HP?', 'Pakai Akun → Backup & Restore untuk ekspor data, lalu impor di HP baru.'],
  ];
  @override
  Widget build(BuildContext context) => _page('FAQ', [
        for (final x in items)
          GradCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(x[0], style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text(x[1], style: const TextStyle(color: Colors.grey))])),
      ]);
}

class TutorialPage extends StatelessWidget {
  const TutorialPage({super.key});
  static const steps = [
    ['1. Sambung ke server', 'Buka app, tunggu pencarian otomatis. Kalau tidak ketemu, ketik alamat server.'],
    ['2. Daftar atau masuk', 'Akun pertama yang mendaftar di server otomatis jadi admin.'],
    ['3. Pakai fitur', 'Buka tab Fitur. Ketuk bintang untuk menyimpan ke Favorit. Semua pemakaian tercatat di Riwayat.'],
    ['4. Cari preset', 'Fitur Cari Preset TikTok: tempel link video, lalu Buka AM atau Edit di AM Zarvida.'],
    ['5. HD-kan status', 'Fitur SW WA HD: pilih foto/video, pilih mode, proses, lalu kirim ke Status WhatsApp.'],
    ['6. Amankan app', 'Akun → Keamanan: aktifkan PIN, fingerprint, dan auto lock.'],
  ];
  @override
  Widget build(BuildContext context) => _page('Tutorial', [
        for (final x in steps)
          GradCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(x[0], style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text(x[1], style: const TextStyle(color: Colors.grey))])),
      ]);
}

class ChangelogPage extends StatelessWidget {
  const ChangelogPage({super.key});
  static const items = [
    ['1.5.0', 'Tambah fitur dari app (admin): fitur dari web atau kode, terminal uji, impor/ekspor JSON.'],
    ['1.4.0', 'SW WA HD, Browser Internal, File Manager, QR Scanner, OCR, Text to Speech, Speech to Text, Translator, UUID, JSON Formatter, Backup & Restore, PIN/Fingerprint/Auto Lock, Mode Offline, Feedback & Laporan Bug, cek update, widget layar utama.'],
    ['1.3.0', 'Suspend fitur oleh admin (manual dan otomatis).'],
    ['1.2.0', 'Dashboard, Pencarian, Favorit, Riwayat, tema, AM Zarvida, Cari Preset TikTok.'],
    ['1.0.0', 'Rilis awal.'],
  ];
  @override
  Widget build(BuildContext context) => _page('Changelog', [
        for (final x in items)
          GradCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Versi ${x[0]}', style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text(x[1], style: const TextStyle(color: Colors.grey))])),
      ]);
}
