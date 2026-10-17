import 'dart:io';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'downloader.dart' show nexvoraDir, fixName;

/// Hasil simpan: [inGallery] true jika video/gambar masuk galeri (album Nexvora).
class SaveResult {
  final String path;
  final bool inGallery;
  final String mime;
  const SaveResult(this.path, this.inGallery, this.mime);
}

const _ua = 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

const _extMime = {
  'video/mp4': '.mp4', 'video/webm': '.webm', 'video/quicktime': '.mov',
  'image/jpeg': '.jpg', 'image/png': '.png', 'image/webp': '.webp', 'image/gif': '.gif',
  'audio/mpeg': '.mp3', 'audio/mp4': '.m4a', 'audio/wav': '.wav', 'audio/ogg': '.ogg',
  'application/pdf': '.pdf', 'application/zip': '.zip', 'application/json': '.json',
  'text/plain': '.txt', 'text/xml': '.xml', 'application/xml': '.xml',
};

String _urlExt(String url) {
  final m = RegExp(r'\.([A-Za-z0-9]{2,5})(?:\?|#|$)').firstMatch(url);
  return m == null ? '' : '.${m.group(1)!.toLowerCase()}';
}

/// Unduh file langsung di dalam app (tanpa browser) lalu simpan:
/// video/gambar -> galeri (album Nexvora), lainnya -> folder Nexvora.
/// [onProgress] 0..1, atau -1 kalau ukuran file tidak diketahui.
Future<SaveResult> saveMediaToGallery(
  String url, {
  String name = 'nexvora',
  void Function(double p)? onProgress,
}) async {
  final client = http.Client();
  File? file;
  try {
    final req = http.Request('GET', Uri.parse(url))..headers['User-Agent'] = _ua;
    final res = await client.send(req).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) throw Exception('Server sumber membalas HTTP ${res.statusCode}');

    final mime = (res.headers['content-type'] ?? '').split(';').first.trim().toLowerCase();
    final urlExt = _urlExt(url);
    final ext = urlExt.isNotEmpty ? urlExt : (_extMime[mime] ?? '');
    final dir = await nexvoraDir('Download');
    final base = name.contains('.') ? fixName(name, '') : fixName(name, '') + ext;
    final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$base';

    final total = res.contentLength ?? -1;
    var got = 0;
    file = File(path);
    final sink = file.openWrite();
    try {
      await for (final chunk in res.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (onProgress != null) onProgress(total > 0 ? got / total : -1);
      }
    } finally {
      await sink.close();
    }
    if (got == 0) throw Exception('File kosong');

    final isVideo = mime.startsWith('video/') || const ['.mp4', '.webm', '.mov', '.mkv'].contains(ext);
    final isImage = mime.startsWith('image/') || const ['.jpg', '.jpeg', '.png', '.webp', '.gif'].contains(ext);
    if (isVideo || isImage) {
      if (!await Gal.hasAccess(toAlbum: true)) {
        await Gal.requestAccess(toAlbum: true);
      }
      if (isVideo) {
        await Gal.putVideo(path, album: 'Nexvora');
      } else {
        await Gal.putImage(path, album: 'Nexvora');
      }
      return SaveResult(path, true, mime);
    }
    return SaveResult(path, false, mime);
  } catch (e) {
    try { if (file != null && await file.exists()) await file.delete(); } catch (_) {}
    rethrow;
  } finally {
    client.close();
  }
}
