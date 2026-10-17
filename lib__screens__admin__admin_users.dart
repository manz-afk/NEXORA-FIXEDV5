import 'package:flutter/material.dart';
import '../../core/core.dart';

class AdminUsers extends StatelessWidget {
  const AdminUsers({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pengguna')),
        body: Loader(
          load: () => Api.get('/api/admin/users'),
          build: (c, d, reload) => ListView(padding: const EdgeInsets.all(12), children: [
            for (final u in d['users'] as List)
              MenuTile(
                icon: u['role'] == 'admin' ? Icons.shield : Icons.person,
                title: '${u['username']}${u['banned'] == true ? '  (banned)' : ''}',
                subtitle: '${u['email']} • ${u['role']}',
                onTap: () => showModalBottomSheet(
                  context: c,
                  builder: (sc) => Wrap(children: [
                    ListTile(
                      leading: const Icon(Icons.block),
                      title: Text(u['banned'] == true ? 'Buka ban' : 'Ban'),
                      onTap: () async {
                        Navigator.pop(sc);
                        if (await act(c, () => Api.post('/api/admin/users/${u['id']}/ban', {'banned': u['banned'] != true}))) reload();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.shield),
                      title: Text(u['role'] == 'admin' ? 'Jadikan user' : 'Jadikan admin'),
                      onTap: () async {
                        Navigator.pop(sc);
                        if (await act(c, () => Api.post('/api/admin/users/${u['id']}/role', {'role': u['role'] == 'admin' ? 'user' : 'admin'}))) reload();
                      },
                    ),
                  ]),
                ),
              ),
          ]),
        ),
      );
}
