import 'package:flutter/material.dart';
import '../core/core.dart';

class DashTab extends StatelessWidget {
  const DashTab({super.key});
  @override
  Widget build(BuildContext context) => Loader(
        load: () => Api.get('/api/dashboard'),
        build: (c, d, r) {
          final news = d['news'] as List;
          final recent = d['recent'] as List;
          Widget stat(String l, String v) => Expanded(
                child: GradCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ]),
                ),
              );
          return ListView(padding: const EdgeInsets.all(12), children: [
            Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/logo.png', width: 40, height: 40)),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Halo,', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text('${Api.me['username']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
            ]),
            const SizedBox(height: 8),
            Row(children: [stat('Fitur', '${d['tools']}'), const SizedBox(width: 8), stat('Favorit', '${d['favorites']}'), const SizedBox(width: 8), stat('Riwayat', '${d['history']}')]),
            const Padding(padding: EdgeInsets.fromLTRB(4, 12, 4, 4), child: Text('Pengumuman', style: TextStyle(fontWeight: FontWeight.bold))),
            if (news.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Belum ada pengumuman', style: TextStyle(color: Colors.grey))),
            for (final n in news)
              GradCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${n['title']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                if ('${n['body']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${n['body']}', style: const TextStyle(fontSize: 12, color: Colors.grey))),
              ])),
            const Padding(padding: EdgeInsets.fromLTRB(4, 12, 4, 4), child: Text('Aktivitas terakhir', style: TextStyle(fontWeight: FontWeight.bold))),
            if (recent.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Belum ada aktivitas', style: TextStyle(color: Colors.grey))),
            for (final h in recent)
              GradCard(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${h['toolName']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${h['input']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ])),
                Text(tgl(h['t']), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ])),
          ]);
        },
      );
}
