import 'package:flutter/material.dart';
import '../core/core.dart';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});
  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  String type = 'feedback';
  final title = TextEditingController(), msg = TextEditingController();
  bool busy = false;

  Future<void> send() async {
    setState(() => busy = true);
    final ok = await act(context, () async {
      var m = msg.text.trim();
      if (type == 'bug') {
        final info = await PackageInfo.fromPlatform();
        m += '\n\n[info: Nexvora ${info.version}, ${Platform.operatingSystem} ${Platform.operatingSystemVersion}]';
      }
      await Api.post('/api/feedback', {'type': type, 'title': title.text.trim(), 'message': m});
    }, 'Terkirim, terima kasih!');
    if (ok) {
      title.clear();
      msg.clear();
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Masukan')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'feedback', label: Text('Feedback')), ButtonSegment(value: 'bug', label: Text('Laporan bug'))],
            selected: {type},
            onSelectionChanged: (v) => setState(() => type = v.first),
          ),
          const SizedBox(height: 16),
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Judul', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: msg, minLines: 5, maxLines: 10, decoration: InputDecoration(labelText: type == 'bug' ? 'Apa yang terjadi? Langkah-langkahnya?' : 'Pesan', border: const OutlineInputBorder())),
          const SizedBox(height: 16),
          FilledButton(onPressed: busy ? null : send, child: Text(busy ? 'Mengirim...' : 'Kirim')),
          const SizedBox(height: 8),
          const Text('Masuk ke server, admin bisa membacanya.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      );
}
