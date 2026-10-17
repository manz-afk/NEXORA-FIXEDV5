import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

Future<Directory> nexvoraDir([String sub = '']) async {
  final base = (await getExternalStorageDirectory()) ?? await getApplicationDocumentsDirectory();
  final d = Directory(sub.isEmpty ? base.path : '${base.path}/$sub');
  await d.create(recursive: true);
  return d;
}

const _ext = {
  'video/mp4': '.mp4', 'video/webm': '.webm', 'image/png': '.png', 'image/jpeg': '.jpg', 'image/webp': '.webp',
  'audio/mpeg': '.mp3', 'audio/mp4': '.m4a', 'audio/wav': '.wav', 'text/xml': '.xml', 'application/xml': '.xml',
  'application/pdf': '.pdf', 'application/zip': '.zip', 'application/json': '.json', 'text/plain': '.txt',
};

String fixName(String name, String mime) {
  var n = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  if (n.isEmpty) n = 'file';
  if (!n.contains('.') && _ext.containsKey(mime)) n += _ext[mime]!;
  return n;
}

String _blobJs(String url) {
  final u = jsonEncode(url);
  return '''
(async () => {
  try {
    const r = await fetch($u); const b = await r.blob();
    await window.flutter_inappwebview.callHandler('dlStart', b.type || '', b.size);
    const CH = 1024 * 1024; let off = 0;
    while (off < b.size) {
      const buf = new Uint8Array(await b.slice(off, off + CH).arrayBuffer());
      let bin = ''; for (let i = 0; i < buf.length; i += 0x8000) bin += String.fromCharCode.apply(null, buf.subarray(i, i + 0x8000));
      await window.flutter_inappwebview.callHandler('dlChunk', btoa(bin)); off += CH;
    }
    await window.flutter_inappwebview.callHandler('dlEnd');
  } catch (e) { await window.flutter_inappwebview.callHandler('dlFail', String(e)); }
})();
''';
}

class DlItem {
  final int id;
  String name, status, path, mime;
  int size;
  DlItem(this.id, this.name, {this.status = 'proses', this.path = '', this.mime = '', this.size = 0});
}

class Downloader extends ChangeNotifier {
  static final Downloader i = Downloader();
  final List<DlItem> items = [];
  IOSink? _sink;
  DlItem? _cur;
  String pendingName = 'file';
  int _seq = 0;

  void attach(InAppWebViewController c) {
    c.addJavaScriptHandler(handlerName: 'dlStart', callback: (a) async {
      final mime = '${a[0]}';
      final name = fixName(pendingName, mime);
      final dir = await nexvoraDir('Download');
      final it = DlItem(_seq++, name, mime: mime, size: (a[1] as num).toInt(), path: '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$name');
      _cur = it;
      items.insert(0, it);
      _sink = File(it.path).openWrite();
      notifyListeners();
    });
    c.addJavaScriptHandler(handlerName: 'dlChunk', callback: (a) {
      _sink?.add(base64Decode('${a[0]}'));
    });
    c.addJavaScriptHandler(handlerName: 'dlEnd', callback: (a) async {
      await _sink?.flush();
      await _sink?.close();
      _sink = null;
      if (_cur != null) await _finish(_cur!);
    });
    c.addJavaScriptHandler(handlerName: 'dlFail', callback: (a) async {
      await _sink?.close();
      _sink = null;
      _cur?.status = 'gagal';
      notifyListeners();
    });
  }

  Future<void> handle(InAppWebViewController c, DownloadStartRequest req) async {
    final url = req.url.toString();
    pendingName = req.suggestedFilename ?? 'file';
    if (url.startsWith('blob:')) {
      await c.evaluateJavascript(source: _blobJs(url));
      return;
    }
    final it = DlItem(_seq++, fixName(pendingName, req.mimeType ?? ''), mime: req.mimeType ?? '');
    items.insert(0, it);
    notifyListeners();
    try {
      final r = await http.get(Uri.parse(url));
      if (r.statusCode != 200) throw 'HTTP ${r.statusCode}';
      it.mime = it.mime.isEmpty ? (r.headers['content-type'] ?? '') : it.mime;
      it.name = fixName(pendingName, it.mime);
      final dir = await nexvoraDir('Download');
      it.path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${it.name}';
      await File(it.path).writeAsBytes(r.bodyBytes);
      it.size = r.bodyBytes.length;
      await _finish(it);
    } catch (_) {
      it.status = 'gagal';
      notifyListeners();
    }
  }

  Future<void> _finish(DlItem it) async {
    it.status = 'selesai';
    try {
      if (it.mime.startsWith('video/')) {
        await Gal.putVideo(it.path, album: 'Nexvora');
      } else if (it.mime.startsWith('image/')) {
        await Gal.putImage(it.path, album: 'Nexvora');
      }
    } catch (_) {}
    notifyListeners();
  }
}
