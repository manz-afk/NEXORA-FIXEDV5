import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

const amUrl = 'https://am.zervida.my.id/runtime/preset.html';

const _ext = {
  'video/mp4': '.mp4', 'video/webm': '.webm', 'image/png': '.png', 'image/jpeg': '.jpg',
  'audio/mpeg': '.mp3', 'audio/mp4': '.m4a', 'audio/wav': '.wav', 'text/xml': '.xml', 'application/xml': '.xml',
};

String _fixName(String name, String mime) {
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

class AmZarvidaPage extends StatefulWidget {
  const AmZarvidaPage({super.key});
  @override
  State<AmZarvidaPage> createState() => _AmZarvidaPageState();
}

class _AmZarvidaPageState extends State<AmZarvidaPage> {
  InAppWebViewController? ctl;
  double progress = 0;
  IOSink? sink;
  String savePath = '', saveMime = '', saveName = 'file';
  String pendingName = 'file';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => askPermissions());
  }

  void toast(String m, {SnackBarAction? action}) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), action: action));
  }

  Future<void> askPermissions() async {
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Izin akses media'),
        content: const Text('Nexvora meminta akses foto, video, audio, dan penyimpanan untuk memilih media preset dan menyimpan video hasil ekspor.\n\nTidak meminta kamera, mikrofon, lokasi, atau kontak.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Nanti')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Lanjut')),
        ],
      ),
    );
    if (ok == true) await [Permission.photos, Permission.videos, Permission.audio, Permission.storage].request();
  }

  Future<void> finish(String path, String mime, String name) async {
    try {
      if (mime.startsWith('video/')) {
        await Gal.putVideo(path, album: 'Nexvora');
        toast('Video tersimpan di galeri (album Nexvora)', action: SnackBarAction(label: 'Bagikan', onPressed: () => Share.shareXFiles([XFile(path)])));
      } else if (mime.startsWith('image/')) {
        await Gal.putImage(path, album: 'Nexvora');
        toast('Gambar tersimpan di galeri (album Nexvora)');
      } else {
        await Share.shareXFiles([XFile(path, mimeType: mime.isEmpty ? null : mime)]);
      }
    } catch (e) {
      toast('Gagal menyimpan: $e');
    }
  }

  Future<void> httpDownload(String url, String name, String? mime) async {
    toast('Mengunduh...');
    try {
      final r = await http.get(Uri.parse(url));
      if (r.statusCode != 200) throw 'HTTP ${r.statusCode}';
      final dir = await getTemporaryDirectory();
      final m = mime ?? r.headers['content-type'] ?? '';
      final n = _fixName(name, m);
      final p = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$n';
      await File(p).writeAsBytes(r.bodyBytes);
      await finish(p, m, n);
    } catch (e) {
      toast('Gagal mengunduh: $e');
    }
  }

  void registerHandlers(InAppWebViewController c) {
    c.addJavaScriptHandler(handlerName: 'dlStart', callback: (a) async {
      final dir = await getTemporaryDirectory();
      saveMime = '${a[0]}';
      saveName = _fixName(pendingName, saveMime);
      savePath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$saveName';
      sink = File(savePath).openWrite();
      toast('Mengunduh $saveName ...');
    });
    c.addJavaScriptHandler(handlerName: 'dlChunk', callback: (a) {
      sink?.add(base64Decode('${a[0]}'));
    });
    c.addJavaScriptHandler(handlerName: 'dlEnd', callback: (a) async {
      await sink?.flush();
      await sink?.close();
      sink = null;
      await finish(savePath, saveMime, saveName);
    });
    c.addJavaScriptHandler(handlerName: 'dlFail', callback: (a) async {
      await sink?.close();
      sink = null;
      toast('Unduhan gagal: ${a.isNotEmpty ? a[0] : ''}');
    });
  }

  @override
  Widget build(BuildContext context) => WillPopScope(
        onWillPop: () async {
          if (ctl != null && await ctl!.canGoBack()) {
            ctl!.goBack();
            return false;
          }
          return true;
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('AM Zarvida'), actions: [
            IconButton(icon: const Icon(Icons.perm_media), tooltip: 'Izin media', onPressed: askPermissions),
            IconButton(icon: const Icon(Icons.refresh), onPressed: () => ctl?.reload()),
          ]),
          body: Column(children: [
            if (progress < 1) LinearProgressIndicator(value: progress),
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(amUrl)),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  useOnDownloadStart: true,
                  allowFileAccess: true,
                  allowContentAccess: true,
                  supportZoom: false,
                  useHybridComposition: true,
                ),
                onWebViewCreated: (c) {
                  ctl = c;
                  registerHandlers(c);
                },
                onProgressChanged: (c, p) => setState(() => progress = p / 100),
                onDownloadStartRequest: (c, req) async {
                  final url = req.url.toString();
                  pendingName = req.suggestedFilename ?? 'video';
                  if (url.startsWith('blob:')) {
                    await c.evaluateJavascript(source: _blobJs(url));
                  } else {
                    await httpDownload(url, pendingName, req.mimeType);
                  }
                },
                onPermissionRequest: (c, req) async => PermissionResponse(resources: req.resources, action: PermissionResponseAction.DENY),
              ),
            ),
          ]),
        ),
      );
}
