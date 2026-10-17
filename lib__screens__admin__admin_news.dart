import 'package:flutter/material.dart';
import '../../core/core.dart';

class AdminNewsPage extends StatefulWidget {
  const AdminNewsPage({super.key});
  @override
  State<AdminNewsPage> createState() => _AdminNewsPageState();
}

class _AdminNewsPageState extends State<AdminNewsPage> {
  Key k = UniqueKey();
  void refresh() => setState(() => k = UniqueKey());
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pengumuman')),
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.add),
          onPressed: () async {
            final f = await form(context, 'Pengumuman baru', ['Judul', 'Isi']);
            if (f == null || !mounted) return;
            if (await act(context, () => Api.post('/api/admin/news', {'title': f['Judul'], 'body': f['Isi']}), 'Terkirim')) refresh();
          },
        ),
        body: Loader(
          key: k,
          load: () => Api.get('/api/news'),
          build: (c, d, r) => ListView(padding: const EdgeInsets.all(12), children: [
            for (final n in d['news'] as List)
              GradCard(
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${n['title']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${n['body']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ])),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () async {
                      if (!await confirm(c, 'Hapus pengumuman ini?')) return;
                      if (!c.mounted) return;
                      if (await act(c, () => Api.del('/api/admin/news/${n['id']}'), 'Dihapus')) refresh();
                    },
                  ),
                ]),
              ),
          ]),
        ),
      );
}
