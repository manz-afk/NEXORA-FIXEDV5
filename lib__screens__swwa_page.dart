import 'package:flutter/material.dart';
import '../core/core.dart';
import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class SwWaPage extends StatefulWidget {
  const SwWaPage({super.key});
  @override
  State<SwWaPage> createState() => _SwWaPageState();
}

class _SwWaPageState extends State<SwWaPage> {
  static const vidExt = ['mp4', 'mov', 'mkv', 'webm', '3gp', 'avi', 'm4v'];
  String? path;
  bool isVideo = true, sharpen = true, busy = false;
  String mode = 'wa', status = '';
  int fps = 30;
  double progress = 0, durationSec = 0;
  int? srcW, srcH;
  String? out;

  void snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.media);
    final p = r?.files.single.path;
    if (p == null) return;
    final ext = p.split('.').last.toLowerCase();
    setState(() { path = p; isVideo = vidExt.contains(ext); out = null; status = 'Membaca info media...'; srcW = null; srcH = null; durationSec = 0; });
    try {
      final s = await FFprobeKit.getMediaInformation(p);
      final info = s.getMediaInformation();
      for (final st in info?.getStreams() ?? []) {
        final w = st.getWidth(), h = st.getHeight();
        if (w != null && h != null) { srcW = w; srcH = h; break; }
      }
      durationSec = double.tryParse(info?.getDuration() ?? '') ?? 0;
      setState(() => status = 'Siap: ${srcW ?? '?'}x${srcH ?? '?'}${isVideo ? ', ${durationSec.toStringAsFixed(1)} detik' : ''}');
    } catch (_) {
      setState(() => status = 'Siap');
    }
  }

  String _vf({required bool withFps}) {
    final portrait = (srcH ?? 1920) >= (srcW ?? 1080);
    final long = mode == '4k' ? 3840 : 1920, short = mode == '4k' ? 2160 : 1080;
    final w = portrait ? short : long, h = portrait ? long : short;
    final f = mode == 'wa' ? 30 : fps;
    return [
      'scale=$w:$h:force_original_aspect_ratio=decrease:flags=lanczos',
      'pad=$w:$h:(ow-iw)/2:(oh-ih)/2:black',
      if (sharpen) 'unsharp=5:5:0.8:5:5:0.4',
      if (withFps && isVideo) 'fps=$f',
      if (isVideo) 'format=yuv420p',
    ].join(',');
  }

  Future<void> run() async {
    if (path == null) return;
    setState(() { busy = true; progress = 0; out = null; status = 'Memproses...'; });
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = path!.split('.').last.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final inPath = '${dir.path}/in_$ts.$ext';
    await File(path!).copy(inPath);
    final outPath = '${dir.path}/nexvora_hd_$ts.${isVideo ? 'mp4' : 'jpg'}';
    final crf = mode == '4k' ? 16 : 18;
    final cmds = isVideo
        ? [
            '-y -i "$inPath" -vf "${_vf(withFps: true)}" -c:v libx264 -preset veryfast -crf $crf -c:a aac -b:a 192k -movflags +faststart "$outPath"',
            '-y -i "$inPath" -vf "${_vf(withFps: true)}" -c:v h264_mediacodec -b:v ${mode == '4k' ? '40M' : '16M'} -c:a aac -b:a 192k -movflags +faststart "$outPath"',
          ]
        : ['-y -i "$inPath" -vf "${_vf(withFps: false)}" -frames:v 1 -q:v 2 "$outPath"'];
    var ok = false;
    for (int i = 0; i < cmds.length; i++) {
      final done = Completer<bool>();
      await FFmpegKit.executeAsync(
        cmds[i],
        (session) async {
          final rc = await session.getReturnCode();
          done.complete(ReturnCode.isSuccess(rc));
        },
        null,
        (stats) {
          if (durationSec > 0) {
            final t = (stats.getTime() as num).toDouble() / 1000;
            if (mounted) setState(() => progress = (t / durationSec).clamp(0.0, 1.0));
          }
        },
      );
      ok = await done.future;
      if (ok) break;
      if (i + 1 < cmds.length && mounted) setState(() => status = 'Encoder utama gagal, mencoba encoder hardware...');
    }
    try { await File(inPath).delete(); } catch (_) {}
    if (!mounted) return;
    setState(() {
      busy = false;
      if (ok) {
        out = outPath;
        progress = 1;
        status = 'Selesai (${(File(outPath).lengthSync() / 1048576).toStringAsFixed(1)} MB)';
      } else {
        status = 'Gagal memproses. Coba mode lebih rendah atau file lain.';
      }
    });
  }

  Future<void> saveGallery() async {
    try {
      if (isVideo) {
        await Gal.putVideo(out!, album: 'Nexvora');
      } else {
        await Gal.putImage(out!, album: 'Nexvora');
      }
      snack('Tersimpan di galeri (album Nexvora)');
    } catch (e) {
      snack('Gagal menyimpan: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('SW WA HD')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          GradCard(
            onTap: busy ? null : pick,
            child: SizedBox(
              height: 96,
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.upload_file, size: 30),
                const SizedBox(height: 6),
                Text(path == null ? 'Pilih foto atau video' : path!.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
            ),
          ),
          if (status.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(status, style: const TextStyle(color: Colors.grey))),
          const Padding(padding: EdgeInsets.only(top: 8, bottom: 4), child: Text('Mode', style: TextStyle(fontWeight: FontWeight.bold))),
          Wrap(spacing: 8, children: [
            for (final m in const {'wa': 'WA Status', '1080': '1080p', '4k': '4K'}.entries)
              ChoiceChip(label: Text(m.value), selected: mode == m.key, onSelected: busy ? null : (_) => setState(() => mode = m.key)),
          ]),
          if (isVideo && mode != 'wa') ...[
            const Padding(padding: EdgeInsets.only(top: 12, bottom: 4), child: Text('FPS', style: TextStyle(fontWeight: FontWeight.bold))),
            Wrap(spacing: 8, children: [
              for (final f in const [30, 60, 120]) ChoiceChip(label: Text('$f'), selected: fps == f, onSelected: busy ? null : (_) => setState(() => fps = f)),
            ]),
          ],
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Penajaman ringan'), value: sharpen, onChanged: busy ? null : (v) => setState(() => sharpen = v)),
          GradCard(
            child: Text(
              mode == 'wa'
                  ? 'Mode WA Status: 1080p, 30fps, bitrate tinggi, penajaman ringan. Ini yang paling pas untuk status WhatsApp.'
                  : 'Mode ${mode == '4k' ? '4K' : '1080p'}: prosesnya berat dan file besar. WhatsApp tetap mengompres ulang status, jadi 4K/120fps tidak terlihat di status. ${fps == 120 ? 'FPS 120 dari video 30fps hanya menggandakan frame.' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          if (busy) ...[
            LinearProgressIndicator(value: progress > 0 ? progress : null),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => FFmpegKit.cancel(), child: const Text('Batalkan')),
          ] else
            FilledButton(onPressed: path == null ? null : run, child: const Text('Proses HD')),
          if (out != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: saveGallery, child: const Text('Simpan ke galeri'))),
              const SizedBox(width: 8),
              Expanded(child: FilledButton(onPressed: () => Share.shareXFiles([XFile(out!)]), child: const Text('Kirim ke Status WA'))),
            ]),
            const Padding(padding: EdgeInsets.only(top: 6), child: Text('Di menu bagikan, pilih WhatsApp lalu "Status saya".', style: TextStyle(fontSize: 12, color: Colors.grey))),
          ],
        ]),
      );
}
