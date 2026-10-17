import 'package:flutter/material.dart';
import '../core/core.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Directory> backupDir() async {
  final base = (await getExternalStorageDirectory()) ?? await getApplicationDocumentsDirectory();
  final d = Directory('${base.path}/Backup');
  await d.create(recursive: true);
  return d;
}

Future<Map<String, dynamic>> collectBackup() async {
  final server = await Api.get('/api/backup');
  final sp = await SharedPreferences.getInstance();
  return {
    'app': 'nexvora',
    'v': 1,
    't': DateTime.now().millisecondsSinceEpoch,
    'server': server,
    'local': {'mode': sp.getInt('mode'), 'seed': sp.getInt('seed'), 'anim': sp.getBool('anim'), 'offline': sp.getBool('offline'), 'bm': sp.getString('bm')},
  };
}

Future<void> applyBackup(Map m) async {
  if (m['app'] != 'nexvora') throw 'Bukan file backup Nexvora';
  await Api.post('/api/restore', Map<String, dynamic>.from(m['server'] as Map));
  final l = m['local'];
  if (l is Map) {
    final sp = await SharedPreferences.getInstance();
    if (l['mode'] is int) await sp.setInt('mode', l['mode']);
    if (l['seed'] is int) await sp.setInt('seed', l['seed']);
    if (l['anim'] is bool) await sp.setBool('anim', l['anim']);
    if (l['offline'] is bool) await sp.setBool('offline', l['offline']);
    if (l['bm'] is String) await sp.setString('bm', l['bm']);
    await AppSettings.i.reload();
  }
}

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  Key k = UniqueKey();
  void refresh() => setState(() => k = UniqueKey());

  Future<List<File>> files() async {
    final d = await backupDir();
    final l = d.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
    l.sort((a, b) => b.path.compareTo(a.path));
    return l;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Backup & Restore')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          MenuTile(
            icon: Icons.upload_file,
            title: 'Export data',
            subtitle: 'Simpan favorit, riwayat, pengaturan ke file',
            onTap: () => act(context, () async {
              final data = await collectBackup();
              final bytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));
              final r = await FilePicker.platform.saveFile(dialogTitle: 'Simpan backup', fileName: 'nexvora_backup.json', bytes: bytes);
              if (r == null) throw 'Dibatalkan';
            }, 'Backup tersimpan'),
          ),
          MenuTile(
            icon: Icons.download,
            title: 'Import data',
            subtitle: 'Pilih file backup (.json)',
            onTap: () => act(context, () async {
              final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
              if (r == null || r.files.single.bytes == null) throw 'Dibatalkan';
              await applyBackup(jsonDecode(utf8.decode(r.files.single.bytes!)) as Map);
              refresh();
            }, 'Data dipulihkan'),
          ),
          MenuTile(
            icon: Icons.backup,
            title: 'Backup sekarang',
            subtitle: 'Simpan cadangan di folder Nexvora/Backup',
            onTap: () async {
              if (await act(context, () async {
                final d = await backupDir();
                final n = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
                await File('${d.path}/nexvora_$n.json').writeAsString(jsonEncode(await collectBackup()));
              }, 'Cadangan dibuat')) {
                refresh();
              }
            },
          ),
          const Padding(padding: EdgeInsets.fromLTRB(4, 14, 4, 4), child: Text('Cadangan tersimpan', style: TextStyle(fontWeight: FontWeight.bold))),
          FutureBuilder<List<File>>(
            key: k,
            future: files(),
            builder: (c, s) {
              if (!s.hasData) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
              if (s.data!.isEmpty) return const Padding(padding: EdgeInsets.all(8), child: Text('Belum ada cadangan', style: TextStyle(color: Colors.grey)));
              return Column(children: [
                for (final f in s.data!)
                  GradCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(children: [
                      Expanded(child: Text(f.path.split('/').last, style: const TextStyle(fontSize: 12))),
                      TextButton(
                        onPressed: () async {
                          if (!await confirm(c, 'Pulihkan dari cadangan ini?')) return;
                          if (!c.mounted) return;
                          await act(c, () async => applyBackup(jsonDecode(await f.readAsString()) as Map), 'Data dipulihkan');
                        },
                        child: const Text('Restore'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () async {
                          await f.delete();
                          refresh();
                        },
                      ),
                    ]),
                  ),
              ]);
            },
          ),
        ]),
      );
}
