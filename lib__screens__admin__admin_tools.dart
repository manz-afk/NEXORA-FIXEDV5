import 'package:flutter/material.dart';
import '../../core/core.dart';

class AdminToolsPage extends StatefulWidget {
  const AdminToolsPage({super.key});
  @override
  State<AdminToolsPage> createState() => _AdminToolsPageState();
}

class _AdminToolsPageState extends State<AdminToolsPage> {
  Key k = UniqueKey();
  void refresh() => setState(() => k = UniqueKey());
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Suspend Fitur')),
        body: Loader(
          key: k,
          load: () => Api.get('/api/admin/tools'),
          build: (c, d, r) => ListView(padding: const EdgeInsets.all(12), children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text('Matikan fitur yang rusak. Pengguna melihat pesan "sedang dinonaktifkan". Fitur yang error 5 kali beruntun dimatikan otomatis dan dicoba lagi setelah 15 menit.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            for (final t in d['tools'] as List)
              GradCard(
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${t['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        t['suspended'] == true ? 'Nonaktif${t['auto'] == true ? ' (otomatis)' : ''}${'${t['reason']}'.isEmpty ? '' : ': ${t['reason']}'}' : 'Aktif',
                        style: TextStyle(fontSize: 12, color: t['suspended'] == true ? Colors.orangeAccent : Colors.greenAccent),
                      ),
                    ]),
                  ),
                  Switch(
                    value: t['suspended'] != true,
                    onChanged: (on) async {
                      var reason = '';
                      if (!on) {
                        final f = await form(c, 'Alasan (opsional)', ['Alasan']);
                        if (f == null) return;
                        reason = f['Alasan'] ?? '';
                      }
                      if (!c.mounted) return;
                      if (await act(c, () => Api.post('/api/admin/tools/${t['id']}/suspend', {'suspended': !on, 'reason': reason}), on ? 'Fitur diaktifkan' : 'Fitur dinonaktifkan')) refresh();
                    },
                  ),
                ]),
              ),
          ]),
        ),
      );
}
