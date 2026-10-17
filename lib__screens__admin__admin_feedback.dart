import 'package:flutter/material.dart';
import '../../core/core.dart';

class AdminFeedbackPage extends StatelessWidget {
  const AdminFeedbackPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Feedback & Bug')),
        body: Loader(
          load: () => Api.get('/api/admin/feedback'),
          build: (c, d, reload) {
            final l = d['feedback'] as List;
            if (l.isEmpty) return ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Belum ada masukan')))]);
            return ListView(padding: const EdgeInsets.all(12), children: [
              for (final f in l)
                GradCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(f['type'] == 'bug' ? Icons.bug_report : Icons.chat, size: 18),
                      const SizedBox(width: 6),
                      Expanded(child: Text('${f['title']}', style: const TextStyle(fontWeight: FontWeight.bold))),
                      if (f['done'] == true) const Text('selesai', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                    ]),
                    const SizedBox(height: 4),
                    Text('${f['username']} • ${tgl(f['t'])}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 6),
                    SelectableText('${f['message']}'),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () async {
                          if (await act(c, () => Api.post('/api/admin/feedback/${f['id']}/done', {'done': f['done'] != true}))) reload();
                        },
                        child: Text(f['done'] == true ? 'Buka lagi' : 'Tandai selesai'),
                      ),
                    ),
                  ]),
                ),
            ]);
          },
        ),
      );
}
