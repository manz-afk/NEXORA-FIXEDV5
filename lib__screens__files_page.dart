import 'package:flutter/material.dart';
import '../core/core.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../core/downloader.dart';

String _size(int b) => b < 1024 ? '$b B' : b < 1048576 ? '${(b / 1024).toStringAsFixed(1)} KB' : '${(b / 1048576).toStringAsFixed(1)} MB';

class FileManagerPage extends StatefulWidget {
  const FileManagerPage({super.key});
  @override
  State<FileManagerPage> createState() => _FileManagerPageState();
}

class _FileManagerPageState extends State<FileManagerPage> {
  Directory? root, cur;
  List<FileSystemEntity> list = [];

  @override
  void initState() {
    super.initState();
    nexvoraDir().then((d) {
      root = d;
      cur = d;
      _ls();
    });
  }

  void _ls() {
    final l = cur!.listSync().toList();
    l.sort((a, b) {
      final ad = a is Directory, bd = b is Directory;
      if (ad != bd) return ad ? -1 : 1;
      return a.path.toLowerCase().compareTo(b.path.toLowerCase());
    });
    if (mounted) setState(() => list = l);
  }

  String get rel => cur == null || root == null ? '' : cur!.path.replaceFirst(root!.path, '').isEmpty ? '/' : cur!.path.replaceFirst(root!.path, '');

  @override
  Widget build(BuildContext context) => WillPopScope(
        onWillPop: () async {
          if (cur != null && root != null && cur!.path != root!.path) {
            cur = cur!.parent;
            _ls();
            return false;
          }
          return true;
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('File Manager'), actions: [
            IconButton(
              icon: const Icon(Icons.create_new_folder),
              onPressed: () async {
                final f = await form(context, 'Folder baru', ['Nama']);
                if (f == null || (f['Nama'] ?? '').isEmpty) return;
                await Directory('${cur!.path}/${f['Nama']!.replaceAll('/', '_')}').create();
                _ls();
              },
            ),
            IconButton(
              icon: const Icon(Icons.file_upload),
              tooltip: 'Tambah file dari HP',
              onPressed: () async {
                final r = await FilePicker.platform.pickFiles(allowMultiple: true);
                if (r == null) return;
                for (final f in r.files) {
                  if (f.path != null) await File(f.path!).copy('${cur!.path}/${f.name}');
                }
                _ls();
              },
            ),
          ]),
          body: cur == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.all(12), children: [
                  Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text('Folder Nexvora: $rel\nHanya file milik app ini (unduhan, backup, hasil HD). Tidak membuka semua file HP.', style: const TextStyle(fontSize: 12, color: Colors.grey))),
                  if (list.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Folder kosong'))),
                  for (final e in list)
                    MenuTile(
                      icon: e is Directory ? Icons.folder : Icons.insert_drive_file,
                      title: e.path.split('/').last,
                      subtitle: e is File ? _size(e.lengthSync()) : null,
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'share' && e is File) Share.shareXFiles([XFile(e.path)]);
                          if (v == 'rename') {
                            final f = await form(context, 'Ganti nama', ['Nama baru']);
                            if (f == null || (f['Nama baru'] ?? '').isEmpty) return;
                            await e.rename('${e.parent.path}/${f['Nama baru']!.replaceAll('/', '_')}');
                            _ls();
                          }
                          if (v == 'del') {
                            if (!await confirm(context, 'Hapus ${e.path.split('/').last}?')) return;
                            await e.delete(recursive: true);
                            _ls();
                          }
                        },
                        itemBuilder: (_) => [
                          if (e is File) const PopupMenuItem(value: 'share', child: Text('Bagikan')),
                          const PopupMenuItem(value: 'rename', child: Text('Ganti nama')),
                          const PopupMenuItem(value: 'del', child: Text('Hapus')),
                        ],
                      ),
                      onTap: () {
                        if (e is Directory) {
                          cur = e;
                          _ls();
                        } else {
                          OpenFilex.open(e.path);
                        }
                      },
                    ),
                ]),
        ),
      );
}
