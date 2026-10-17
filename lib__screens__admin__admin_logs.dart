import 'package:flutter/material.dart';
import '../../core/core.dart';

class AdminLogs extends StatelessWidget {
  const AdminLogs({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Log aktivitas')),
        body: Loader(
          load: () => Api.get('/api/admin/logs'),
          build: (c, d, r) => ListView(children: [
            for (final l in d['logs'] as List) ListTile(dense: true, title: Text('${l['user']}: ${l['act']}'), subtitle: Text(tgl(l['t']))),
          ]),
        ),
      );
}
