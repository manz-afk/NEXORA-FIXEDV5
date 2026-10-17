import 'package:flutter/material.dart';
import '../../core/core.dart';

class AdminUpdatePage extends StatelessWidget {
  const AdminUpdatePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Update Aplikasi')),
        body: Loader(
          load: () => Api.get('/api/admin/settings'),
          build: (c, s, reload) => ListView(padding: const EdgeInsets.all(12), children: [
            const Padding(padding: EdgeInsets.all(8), child: Text('Isi versi terbaru dan link unduh APK. Pengguna dengan versi lebih lama akan diberi tahu saat membuka app.', style: TextStyle(fontSize: 12, color: Colors.grey))),
            for (final e in {'Versi terbaru (contoh 1.5.0)': 'updVersion', 'Link unduh APK': 'updUrl', 'Catatan update': 'updNotes'}.entries)
              MenuTile(
                icon: Icons.edit,
                title: e.key,
                subtitle: '${s[e.value] ?? ''}'.isEmpty ? '(kosong)' : '${s[e.value]}',
                onTap: () async {
                  final f = await form(c, e.key, ['Nilai']);
                  if (f == null || !c.mounted) return;
                  if (await act(c, () => Api.put('/api/admin/settings', {e.value: f['Nilai']}))) reload();
                },
              ),
          ]),
        ),
      );
}
