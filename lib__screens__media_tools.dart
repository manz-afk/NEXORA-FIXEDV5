import 'package:flutter/material.dart';
import '../core/core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';

void _snack(BuildContext c, String m) {
  if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
}

Future<String?> _pickImage() async => (await FilePicker.platform.pickFiles(type: FileType.image))?.files.single.path;

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});
  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  List<String> codes = [];
  bool busy = false, done = false;

  Future<void> pick() async {
    final p = await _pickImage();
    if (p == null) return;
    setState(() => busy = true);
    final scanner = BarcodeScanner();
    try {
      final res = await scanner.processImage(InputImage.fromFilePath(p));
      setState(() { codes = res.map((b) => b.rawValue ?? '').where((s) => s.isNotEmpty).toList(); done = true; });
    } catch (e) {
      _snack(context, 'Gagal membaca: $e');
    } finally {
      await scanner.close();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('QR Scanner')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Pilih gambar yang berisi QR code atau barcode dari galeri.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: busy ? null : pick, icon: const Icon(Icons.image), label: Text(busy ? 'Membaca...' : 'Pilih gambar')),
          const SizedBox(height: 12),
          if (done && codes.isEmpty) const Text('Tidak ada QR/barcode terdeteksi.'),
          for (final c in codes)
            GradCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SelectableText(c),
                Wrap(spacing: 8, children: [
                  TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: c)); _snack(context, 'Disalin'); }, child: const Text('Salin')),
                  if (c.startsWith('http')) TextButton(onPressed: () => launchUrl(Uri.parse(c), mode: LaunchMode.externalApplication), child: const Text('Buka')),
                ]),
              ]),
            ),
        ]),
      );
}

class OcrPage extends StatefulWidget {
  const OcrPage({super.key});
  @override
  State<OcrPage> createState() => _OcrPageState();
}

class _OcrPageState extends State<OcrPage> {
  String text = '';
  bool busy = false, done = false;

  Future<void> pick() async {
    final p = await _pickImage();
    if (p == null) return;
    setState(() => busy = true);
    final rec = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final r = await rec.processImage(InputImage.fromFilePath(p));
      setState(() { text = r.text; done = true; });
    } catch (e) {
      _snack(context, 'Gagal membaca: $e');
    } finally {
      await rec.close();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('OCR')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Pilih gambar berisi teks (huruf latin). Diproses di HP, tanpa internet.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: busy ? null : pick, icon: const Icon(Icons.document_scanner), label: Text(busy ? 'Membaca...' : 'Pilih gambar')),
          const SizedBox(height: 12),
          if (done && text.trim().isEmpty) const Text('Tidak ada teks terdeteksi.'),
          if (text.trim().isNotEmpty) ...[
            GradCard(child: SizedBox(width: double.infinity, child: SelectableText(text))),
            TextButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: text)); _snack(context, 'Disalin'); }, icon: const Icon(Icons.copy), label: const Text('Salin teks')),
          ],
        ]),
      );
}

class TtsPage extends StatefulWidget {
  const TtsPage({super.key});
  @override
  State<TtsPage> createState() => _TtsPageState();
}

class _TtsPageState extends State<TtsPage> {
  final tts = FlutterTts();
  final ctrl = TextEditingController();
  String lang = 'id-ID';
  double rate = 0.5;

  Future<void> speak() async {
    if (ctrl.text.trim().isEmpty) return;
    try {
      await tts.setLanguage(lang);
      await tts.setSpeechRate(rate);
      await tts.speak(ctrl.text);
    } catch (e) {
      _snack(context, 'Gagal: $e');
    }
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Text to Speech')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: ctrl, minLines: 5, maxLines: 10, decoration: const InputDecoration(labelText: 'Teks yang dibacakan', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: lang,
            decoration: const InputDecoration(labelText: 'Bahasa', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'id-ID', child: Text('Indonesia')),
              DropdownMenuItem(value: 'en-US', child: Text('English (US)')),
              DropdownMenuItem(value: 'ja-JP', child: Text('Jepang')),
              DropdownMenuItem(value: 'ar-SA', child: Text('Arab')),
            ],
            onChanged: (v) => setState(() => lang = v ?? lang),
          ),
          const SizedBox(height: 8),
          Row(children: [const Text('Kecepatan'), Expanded(child: Slider(value: rate, min: 0.2, max: 1.0, onChanged: (v) => setState(() => rate = v)))]),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: speak, icon: const Icon(Icons.play_arrow), label: const Text('Bacakan'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () => tts.stop(), icon: const Icon(Icons.stop), label: const Text('Stop'))),
          ]),
        ]),
      );
}

class SttPage extends StatefulWidget {
  const SttPage({super.key});
  @override
  State<SttPage> createState() => _SttPageState();
}

class _SttPageState extends State<SttPage> {
  final stt = SpeechToText();
  bool ready = false, listening = false;
  String text = '', lang = 'id_ID';

  Future<void> start() async {
    if (!ready) {
      ready = await stt.initialize(
        onError: (e) { if (mounted) setState(() => listening = false); _snack(context, e.errorMsg); },
        onStatus: (s) { if ((s == 'done' || s == 'notListening') && mounted) setState(() => listening = false); },
      );
      if (!ready) return _snack(context, 'Pengenalan suara tidak tersedia atau izin mikrofon ditolak');
    }
    setState(() => listening = true);
    await stt.listen(onResult: (r) => setState(() => text = r.recognizedWords), localeId: lang, listenOptions: SpeechListenOptions(partialResults: true));
  }

  @override
  void dispose() {
    stt.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Speech to Text')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Izin mikrofon baru diminta saat kamu menekan tombol bicara.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: lang,
            decoration: const InputDecoration(labelText: 'Bahasa', border: OutlineInputBorder()),
            items: const [DropdownMenuItem(value: 'id_ID', child: Text('Indonesia')), DropdownMenuItem(value: 'en_US', child: Text('English (US)'))],
            onChanged: (v) => setState(() => lang = v ?? lang),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: listening ? () { stt.stop(); setState(() => listening = false); } : start,
            icon: Icon(listening ? Icons.stop : Icons.mic),
            label: Text(listening ? 'Berhenti' : 'Mulai bicara'),
          ),
          const SizedBox(height: 12),
          if (text.isNotEmpty) ...[
            GradCard(child: SizedBox(width: double.infinity, child: SelectableText(text))),
            TextButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: text)); _snack(context, 'Disalin'); }, icon: const Icon(Icons.copy), label: const Text('Salin teks')),
          ],
        ]),
      );
}
