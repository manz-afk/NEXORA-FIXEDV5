import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import '../core/core.dart';
import 'am_zarvida_page.dart';


class ToolPage extends StatefulWidget {
  final Map tool;
  const ToolPage({super.key, required this.tool});
  @override
  State<ToolPage> createState() => _ToolPageState();
}

class _ToolPageState extends State<ToolPage> {
  final Map<String, TextEditingController> ctr = {};
  final Map<String, String> sel = {};
  String result = '';
  String? image;
  List links = [];
  bool busy = false;
  late bool fav;
  // url -> progres unduhan (0..1, -1 = tidak diketahui)
  final Map<String, double> prog = {};
  // url -> path file hasil simpan (untuk tombol Buka file di dalam app)
  final Map<String, String> savedPath = {};

  @override
  void initState() {
    super.initState();
    fav = widget.tool['fav'] == true;
    for (final i in widget.tool['inputs'] as List) {
      if (i['type'] == 'select') {
        sel[i['key']] = '${(i['options'] as List).first}';
      } else {
        ctr[i['key']] = TextEditingController();
      }
    }
  }

  void snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void upd(VoidCallback f) {
    if (mounted) setState(f);
  }

  Future<void> run() async {
    setState(() => busy = true);
    final body = <String, dynamic>{for (final e in ctr.entries) e.key: e.value.text.trim(), ...sel};
    try {
      final r = await Api.post('/api/tools/${widget.tool['id']}/run', body);
      setState(() {
        result = '${r['text'] ?? ''}';
        image = r['image'] as String?;
        links = (r['links'] as List?) ?? [];
        prog.clear();
        savedPath.clear();
      });
    } catch (e) {
      snack('$e');
    }
    if (mounted) setState(() => busy = false);
  }

  /// Simpan file langsung di app (tanpa browser). Video/gambar masuk galeri.
  Future<void> saveLink(Map l) async {
    final url = '${l['url']}';
    upd(() => prog[url] = 0);
    try {
      final r = await saveMediaToGallery(
        url,
        name: '${widget.tool['id']}_${DateTime.now().millisecondsSinceEpoch}',
        onProgress: (p) => upd(() => prog[url] = p),
      );
      upd(() {
        prog.remove(url);
        savedPath[url] = r.path;
      });
      snack(r.inGallery ? 'Tersimpan di galeri (album Nexvora)' : 'Tersimpan di folder Nexvora');
    } catch (e) {
      upd(() => prog.remove(url));
      snack('Gagal menyimpan: $e');
    }
  }

  Future<void> toggleFav() async {
    try {
      final r = await Api.post('/api/favorites/${widget.tool['id']}');
      setState(() => fav = r['fav'] == true);
    } catch (e) {
      snack('$e');
    }
  }

  Widget linkCard(Map l) {
    final url = '${l['url']}';
    final kind = '${l['kind']}';
    final p = prog[url];
    final path = savedPath[url];
    final busyThis = p != null;
    return GradCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${l['label']}', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        SelectableText(url, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        if (busyThis) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: p < 0 ? null : p),
          const SizedBox(height: 4),
          Text(p < 0 ? 'Mengunduh...' : 'Mengunduh ${(p * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12)),
        ],
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          FilledButton.icon(
            icon: const Icon(Icons.download),
            onPressed: busyThis ? null : () => saveLink(l),
            label: Text(busyThis ? 'Menyimpan...' : 'Simpan'),
          ),
          if (path != null)
            OutlinedButton.icon(
              icon: const Icon(Icons.play_circle_outline),
              onPressed: () => OpenFilex.open(path),
              label: const Text('Buka file'),
            ),
          if (kind == 'am')
            OutlinedButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                snack('Link disalin, tempel di kolom "Ambil dari link Alight Motion"');
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AmZarvidaPage()));
              },
              child: const Text('Edit di AM Zarvida'),
            ),
          OutlinedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              snack('Link disalin');
            },
            child: const Text('Salin'),
          ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('${widget.tool['name']}'), actions: [IconButton(icon: Icon(fav ? Icons.star : Icons.star_border), onPressed: toggleFav)]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text('${widget.tool['desc']}', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          for (final i in widget.tool['inputs'] as List) ...[
            if (i['type'] == 'select')
              DropdownButtonFormField<String>(
                value: sel[i['key']],
                decoration: InputDecoration(labelText: '${i['label']}', border: const OutlineInputBorder()),
                items: [for (final o in i['options'] as List) DropdownMenuItem(value: '$o', child: Text('$o'))],
                onChanged: (v) => setState(() => sel[i['key']] = v!),
              )
            else
              TextField(
                controller: ctr[i['key']],
                minLines: i['multiline'] == true ? 3 : 1,
                maxLines: i['multiline'] == true ? 6 : 1,
                decoration: InputDecoration(labelText: '${i['label']}', border: const OutlineInputBorder()),
              ),
            const SizedBox(height: 12),
          ],
          FilledButton(onPressed: busy ? null : run, child: Text(busy ? 'Memproses...' : 'Jalankan')),
          const SizedBox(height: 16),
          if (image != null) Center(child: Image.network(image!, height: 240, errorBuilder: (_, __, ___) => const Text('Gambar gagal dimuat'))),
          if (result.isNotEmpty) ...[
            GradCard(child: SizedBox(width: double.infinity, child: SelectableText(result))),
            TextButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Salin hasil'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: result));
                snack('Disalin');
              },
            ),
          ],
          for (final l in links) linkCard(l),
        ]),
      );
}
