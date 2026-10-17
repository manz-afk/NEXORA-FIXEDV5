import 'package:flutter/material.dart';
import '../core/core.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  Key k = UniqueKey();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Riwayat Aktivitas'), actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
              if (!await confirm(context, 'Hapus semua riwayat?')) return;
              if (!mounted) return;
              if (await act(context, () => Api.del('/api/history'), 'Riwayat dihapus')) setState(() => k = UniqueKey());
            },
          ),
        ]),
        body: Loader(
          key: k,
          load: () => Api.get('/api/history'),
          build: (c, d, r) {
            final hs = d['history'] as List;
            if (hs.isEmpty) return ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Belum ada aktivitas')))]);
            return ListView(padding: const EdgeInsets.all(12), children: [
              for (final h in hs)
                GradCard(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${h['toolName']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${h['input']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ])),
                  Text(tgl(h['t']), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ])),
            ]);
          },
        ),
      );
}
