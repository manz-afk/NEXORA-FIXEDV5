import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/core.dart';
import '../tool_tile.dart';

Future<String?> _askPw(BuildContext c) async => (await form(c, 'Konfirmasi password admin', ['Password'], secret: ['Password']))?['Password'];

const _icons = ['web', 'code', 'build', 'text', 'key', 'qr', 'ip', 'cek', 'love', 'translate', 'json', 'uuid', 'bolt'];

const _codeTemplate = '''// input.<kunci> = isi kolom yang kamu buat. Boleh pakai await, fetch(url), crypto, console.log.
// Hasil: return 'teks'  atau  return { text: '...', image: 'https://...', links: [{ label: 'A', url: 'https://...', kind: 'file' }] }
const nama = input.text || 'dunia';
console.log('memproses', nama);
return 'Halo, ' + nama + '!';
''';

class AdminCustomPage extends StatefulWidget {
  const AdminCustomPage({super.key});
  @override
  State<AdminCustomPage> createState() => _AdminCustomPageState();
}

class _AdminCustomPageState extends State<AdminCustomPage> {
  Key k = UniqueKey();
  void refresh() => setState(() => k = UniqueKey());

  Future<void> openEditor([Map? def]) async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => CustomEditorPage(def: def)));
    if (ok == true) refresh();
  }

  Future<void> importFeature() async {
    final f = await form(context, 'Impor fitur', ['Link JSON (opsional)', 'Atau tempel JSON di sini']);
    if (f == null || !mounted) return;
    final pw = await _askPw(context);
    if (pw == null || !mounted) return;
    final url = f['Link JSON (opsional)'] ?? '', js = f['Atau tempel JSON di sini'] ?? '';
    if (await act(context, () => Api.post('/api/admin/custom/import', {if (url.isNotEmpty) 'url': url, if (js.isNotEmpty) 'json': js, 'password': pw}), 'Fitur diimpor')) refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tambah Fitur'), actions: [IconButton(icon: const Icon(Icons.download), tooltip: 'Impor dari link / JSON', onPressed: importFeature)]),
        floatingActionButton: FloatingActionButton.extended(onPressed: () => openEditor(), icon: const Icon(Icons.add), label: const Text('Fitur baru')),
        body: Loader(
          key: k,
          load: () => Api.get('/api/admin/custom'),
          build: (c, d, r) {
            final list = d['custom'] as List;
            return ListView(padding: const EdgeInsets.all(12), children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text('Fitur yang kamu buat di sini langsung tampil di semua pengguna, dengan bentuk yang sama seperti fitur lain. Bisa dari web (panggil API/URL) atau dari kode.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              if (d['allowCode'] == false) const Padding(padding: EdgeInsets.all(8), child: Text('Fitur kode dimatikan di server (ALLOW_CODE=0). Hanya tipe Web yang bisa dibuat.', style: TextStyle(color: Colors.orangeAccent, fontSize: 12))),
              if (list.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Belum ada fitur buatan sendiri'))),
              for (final f in list)
                MenuTile(
                  icon: toolIcon('${f['icon']}'),
                  title: '${f['name']}',
                  subtitle: '${f['type'] == 'code' ? 'Kode' : 'Web'} • ${f['id']}',
                  onTap: () => showModalBottomSheet(
                    context: c,
                    builder: (sc) => Wrap(children: [
                      ListTile(leading: const Icon(Icons.edit), title: const Text('Edit'), onTap: () { Navigator.pop(sc); openEditor(f as Map); }),
                      ListTile(
                        leading: const Icon(Icons.copy),
                        title: const Text('Salin JSON (untuk dibagikan)'),
                        onTap: () {
                          Navigator.pop(sc);
                          final m = Map<String, dynamic>.from(f as Map)..remove('t')..remove('by');
                          Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(m)));
                          ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('JSON disalin')));
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete, color: Colors.redAccent),
                        title: const Text('Hapus fitur'),
                        onTap: () async {
                          Navigator.pop(sc);
                          if (!await confirm(c, 'Hapus fitur ${f['name']} untuk semua pengguna?')) return;
                          if (!c.mounted) return;
                          if (await act(c, () => Api.del('/api/admin/custom/${f['id']}'), 'Fitur dihapus')) refresh();
                        },
                      ),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      );
}

class CustomEditorPage extends StatefulWidget {
  final Map? def;
  const CustomEditorPage({super.key, this.def});
  @override
  State<CustomEditorPage> createState() => _CustomEditorPageState();
}

class _CustomEditorPageState extends State<CustomEditorPage> {
  late final bool editing;
  final id = TextEditingController(), name = TextEditingController(), desc = TextEditingController();
  final url = TextEditingController(), hdr = TextEditingController(), body = TextEditingController(), extract = TextEditingController(), code = TextEditingController();
  String icon = 'web', type = 'web', method = 'GET', term = '';
  List<Map<String, dynamic>> inputs = [];
  final Map<String, TextEditingController> tctr = {};
  bool testing = false, saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.def;
    editing = d != null;
    if (d != null) {
      id.text = '${d['id']}';
      name.text = '${d['name']}';
      desc.text = '${d['desc']}';
      icon = '${d['icon']}';
      type = '${d['type']}';
      inputs = (d['inputs'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (type == 'web') {
        final w = d['web'] as Map;
        method = '${w['method']}';
        url.text = '${w['url']}';
        hdr.text = (w['headers'] as Map).entries.map((e) => '${e.key}: ${e.value}').join('\n');
        body.text = '${w['body']}';
        extract.text = '${w['extract']}';
      } else {
        code.text = '${d['code']}';
      }
    } else {
      code.text = _codeTemplate;
    }
  }

  String _autoId() {
    var s = name.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    if (s.isEmpty || !RegExp(r'^[a-z]').hasMatch(s)) s = 'f_$s';
    while (s.length < 3) {
      s += '_x';
    }
    return s.length > 24 ? s.substring(0, 24) : s;
  }

  Map<String, dynamic> payload() {
    final headers = <String, String>{};
    for (final l in hdr.text.split('\n')) {
      final i = l.indexOf(':');
      if (i > 0) headers[l.substring(0, i).trim()] = l.substring(i + 1).trim();
    }
    return <String, dynamic>{
      'id': id.text.trim().isEmpty ? _autoId() : id.text.trim(),
      'name': name.text.trim(),
      'desc': desc.text.trim(),
      'icon': icon,
      'type': type,
      'inputs': inputs,
      if (type == 'web') 'web': {'method': method, 'url': url.text.trim(), 'headers': headers, 'body': body.text, 'extract': extract.text.trim()} else 'code': code.text,
    };
  }

  Future<void> addInput() async {
    final kKey = 'Kunci (huruf kecil, contoh: text)', kOpt = 'Opsi (pisah koma, khusus select)';
    final f = await form(context, 'Kolom baru', [kKey, 'Label', 'Jenis (text atau select)', kOpt, 'Multiline (ya/tidak)']);
    if (f == null) return;
    final key = (f[kKey] ?? '').trim();
    final sel = (f['Jenis (text atau select)'] ?? '').toLowerCase() == 'select';
    setState(() => inputs.add(<String, dynamic>{
          'key': key,
          'label': (f['Label'] ?? '').isEmpty ? key : f['Label'],
          'type': sel ? 'select' : 'text',
          if (sel) 'options': (f[kOpt] ?? '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() else if ((f['Multiline (ya/tidak)'] ?? '').toLowerCase() == 'ya') 'multiline': true,
        }));
  }

  Future<void> test() async {
    String? pw;
    if (type == 'code') {
      pw = await _askPw(context);
      if (pw == null) return;
    }
    setState(() { testing = true; term = r'$ menjalankan...'; });
    try {
      final inp = {for (final i in inputs) '${i['key']}': tctr['${i['key']}']?.text ?? ''};
      final r = await Api.post('/api/admin/custom/test', {...payload(), 'input': inp, if (pw != null) 'password': pw});
      final b = StringBuffer();
      for (final l in (r['logs'] as List? ?? [])) {
        b.writeln(l);
      }
      if (r['ok'] == true) {
        b.writeln(r['text'] ?? '');
        if (r['image'] != null) b.writeln('[gambar] ${r['image']}');
        for (final l in (r['links'] as List? ?? [])) {
          b.writeln('[link] ${l['label']} ${l['url']}');
        }
        b.write('\n✔ selesai (${r['ms']} ms)');
      } else {
        b.write('✖ ${r['error']}\n(${r['ms']} ms)');
      }
      setState(() => term = b.toString());
    } catch (e) {
      setState(() => term = '✖ $e');
    }
    if (mounted) setState(() => testing = false);
  }

  Future<void> save() async {
    String? pw;
    if (type == 'code') {
      pw = await _askPw(context);
      if (pw == null) return;
    }
    setState(() => saving = true);
    final data = {...payload(), if (pw != null) 'password': pw};
    final ok = await act(context, () => editing ? Api.put('/api/admin/custom/${widget.def!['id']}', data) : Api.post('/api/admin/custom', data), 'Fitur disimpan dan langsung tampil di semua pengguna');
    if (!mounted) return;
    setState(() => saving = false);
    if (ok) Navigator.pop(context, true);
  }

  InputDecoration deco(String l, {String? hint}) => InputDecoration(labelText: l, hintText: hint, border: const OutlineInputBorder());
  static const mono = TextStyle(fontFamily: 'monospace', fontSize: 12.5);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(editing ? 'Edit Fitur' : 'Fitur Baru')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (!editing) ...[TextField(controller: id, decoration: deco('ID (kosong = otomatis dari nama)')), const SizedBox(height: 12)],
          TextField(controller: name, decoration: deco('Nama fitur')),
          const SizedBox(height: 12),
          TextField(controller: desc, decoration: deco('Deskripsi singkat')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: icon,
            decoration: deco('Ikon'),
            items: [for (final i in _icons) DropdownMenuItem(value: i, child: Row(children: [Icon(toolIcon(i), size: 20), const SizedBox(width: 10), Text(i)]))],
            onChanged: (v) => setState(() => icon = v ?? icon),
          ),
          const SizedBox(height: 16),
          const Text('Kolom isian (sama seperti fitur lain)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          for (int i = 0; i < inputs.length; i++)
            GradCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(children: [
                Expanded(child: Text('${inputs[i]['key']}  •  ${inputs[i]['label']}  •  ${inputs[i]['type']}${inputs[i]['options'] != null ? ' (${(inputs[i]['options'] as List).length} opsi)' : ''}', style: const TextStyle(fontSize: 13))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => inputs.removeAt(i))),
              ]),
            ),
          OutlinedButton.icon(onPressed: inputs.length >= 6 ? null : addInput, icon: const Icon(Icons.add), label: const Text('Tambah kolom')),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'web', icon: Icon(Icons.cloud), label: Text('Dari web')), ButtonSegment(value: 'code', icon: Icon(Icons.code), label: Text('Dari kode'))],
            selected: {type},
            onSelectionChanged: (v) => setState(() => type = v.first),
          ),
          const SizedBox(height: 12),
          if (type == 'web') ...[
            DropdownButtonFormField<String>(value: method, decoration: deco('Metode'), items: const [DropdownMenuItem(value: 'GET', child: Text('GET')), DropdownMenuItem(value: 'POST', child: Text('POST'))], onChanged: (v) => setState(() => method = v ?? 'GET')),
            const SizedBox(height: 12),
            TextField(controller: url, keyboardType: TextInputType.url, decoration: deco('URL', hint: 'https://api.contoh.com/cari?q={{text}}')),
            if (inputs.isNotEmpty)
              Wrap(spacing: 6, children: [for (final i in inputs) ActionChip(label: Text('{{${i['key']}}}'), onPressed: () => setState(() => url.text += '{{${i['key']}}}'))]),
            const SizedBox(height: 12),
            TextField(controller: hdr, minLines: 2, maxLines: 5, decoration: deco('Header (satu per baris, Nama: nilai)')),
            const SizedBox(height: 12),
            TextField(controller: body, minLines: 2, maxLines: 6, style: mono, decoration: deco('Body (POST, boleh JSON dengan {{kunci}})')),
            const SizedBox(height: 12),
            TextField(controller: extract, decoration: deco('Ambil bagian respons (opsional)', hint: 'data.hasil[0].teks')),
          ] else ...[
            TextField(controller: code, minLines: 10, maxLines: 24, style: mono, decoration: deco('Kode JavaScript')),
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => setState(() => code.text = _codeTemplate), child: const Text('Isi contoh'))),
            const Text('Kode jalan di server dengan batas waktu 10 detik. Simpan dan uji meminta password admin.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
          const SizedBox(height: 16),
          const Text('Terminal uji', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          for (final i in inputs) ...[
            TextField(controller: tctr.putIfAbsent('${i['key']}', () => TextEditingController()), decoration: deco('Uji: ${i['label']}')),
            const SizedBox(height: 8),
          ],
          FilledButton.tonalIcon(onPressed: testing ? null : test, icon: const Icon(Icons.play_arrow), label: Text(testing ? 'Menjalankan...' : 'Jalankan uji')),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 110),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF05070A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1E2A22))),
            child: SelectableText(term.isEmpty ? r'$ (belum dijalankan)' : term, style: mono.copyWith(color: const Color(0xFF7CFC9A))),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Menyimpan...' : 'Simpan fitur')),
          const SizedBox(height: 24),
        ]),
      );
}
