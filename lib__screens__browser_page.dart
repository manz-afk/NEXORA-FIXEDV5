import 'package:flutter/material.dart';
import '../core/core.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/downloader.dart';

const _desktopUa = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

class _Tab {
  final int id;
  String url;
  String title = 'Tab baru';
  bool desktop = false;
  double progress = 0;
  InAppWebViewController? ctl;
  Key key = UniqueKey();
  _Tab(this.id, this.url);
}

String _normalize(String s) {
  s = s.trim();
  if (s.isEmpty) return 'https://www.google.com';
  if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(s)) return s;
  if (!s.contains(' ') && s.contains('.')) return 'https://$s';
  return 'https://www.google.com/search?q=${Uri.encodeQueryComponent(s)}';
}

class BrowserPage extends StatefulWidget {
  final String? start;
  const BrowserPage({super.key, this.start});
  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  final List<_Tab> tabs = [];
  int cur = 0, _seq = 0;
  final addr = TextEditingController();
  List<Map<String, dynamic>> bookmarks = [], history = [];

  _Tab get t => tabs[cur];

  @override
  void initState() {
    super.initState();
    tabs.add(_Tab(_seq++, widget.start ?? 'https://www.google.com'));
    _loadStore();
  }

  List<Map<String, dynamic>> _dec(String? s) {
    if (s == null) return [];
    try {
      return (jsonDecode(s) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadStore() async {
    final sp = await SharedPreferences.getInstance();
    bookmarks = _dec(sp.getString('bm'));
    history = _dec(sp.getString('bh'));
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('bm', jsonEncode(bookmarks));
    await sp.setString('bh', jsonEncode(history));
  }

  void snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void go(String s) => t.ctl?.loadUrl(urlRequest: URLRequest(url: WebUri(_normalize(s))));

  void newTab([String? u]) => setState(() {
        tabs.add(_Tab(_seq++, u ?? 'https://www.google.com'));
        cur = tabs.length - 1;
        addr.text = '';
      });

  void closeTab(int i) {
    if (tabs.length == 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      tabs.removeAt(i);
      if (cur >= tabs.length) cur = tabs.length - 1;
      addr.text = t.url;
    });
  }

  void toggleDesktop() => setState(() {
        t.desktop = !t.desktop;
        t.key = UniqueKey();
      });

  bool get isBm => bookmarks.any((b) => b['u'] == t.url);

  Future<void> toggleBm() async {
    setState(() {
      if (isBm) {
        bookmarks.removeWhere((b) => b['u'] == t.url);
      } else {
        bookmarks.insert(0, {'t': t.title, 'u': t.url});
      }
    });
    await _save();
  }

  void _addHistory(String u, String title) {
    if (u.isEmpty || u == 'about:blank') return;
    history.removeWhere((h) => h['u'] == u);
    history.insert(0, {'t': title, 'u': u, 'at': DateTime.now().millisecondsSinceEpoch});
    if (history.length > 200) history.removeLast();
    _save();
  }

  Widget web(_Tab tab) => InAppWebView(
        key: tab.key,
        initialUrlRequest: URLRequest(url: WebUri(tab.url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          useOnDownloadStart: true,
          allowFileAccess: true,
          allowContentAccess: true,
          mediaPlaybackRequiresUserGesture: false,
          supportZoom: true,
          useHybridComposition: true,
          userAgent: tab.desktop ? _desktopUa : null,
          preferredContentMode: tab.desktop ? UserPreferredContentMode.DESKTOP : UserPreferredContentMode.RECOMMENDED,
        ),
        onWebViewCreated: (c) {
          tab.ctl = c;
          Downloader.i.attach(c);
        },
        onProgressChanged: (c, p) {
          if (mounted) setState(() => tab.progress = p / 100);
        },
        onUpdateVisitedHistory: (c, url, _) {
          if (url != null) {
            tab.url = url.toString();
            if (identical(tabs[cur], tab)) addr.text = tab.url;
          }
        },
        onTitleChanged: (c, title) => tab.title = title ?? tab.url,
        onLoadStop: (c, url) {
          if (url != null) _addHistory(url.toString(), tab.title);
        },
        onDownloadStartRequest: (c, req) async {
          snack('Mengunduh...');
          await Downloader.i.handle(c, req);
        },
        onPermissionRequest: (c, req) async => PermissionResponse(resources: req.resources, action: PermissionResponseAction.DENY),
      );

  void listSheet(String title, List<Map<String, dynamic>> list, {bool clearable = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sc) => StatefulBuilder(
        builder: (sc, setS) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                if (clearable && list.isNotEmpty)
                  TextButton(onPressed: () { setS(() => list.clear()); setState(() {}); _save(); }, child: const Text('Hapus semua')),
              ]),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('Kosong'))
                  : ListView(children: [
                      for (final b in List.of(list))
                        ListTile(
                          title: Text('${b['t']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${b['u']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () { Navigator.pop(sc); go('${b['u']}'); },
                          trailing: IconButton(icon: const Icon(Icons.close), onPressed: () { setS(() => list.remove(b)); setState(() {}); _save(); }),
                        ),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }

  void tabsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (sc) => StatefulBuilder(
        builder: (sc, setS) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(title: const Text('Tab', style: TextStyle(fontWeight: FontWeight.bold)), trailing: TextButton(onPressed: () { Navigator.pop(sc); newTab(); }, child: const Text('Tab baru'))),
            for (int i = 0; i < tabs.length; i++)
              ListTile(
                selected: i == cur,
                leading: Icon(tabs[i].desktop ? Icons.desktop_windows : Icons.phone_android),
                title: Text(tabs[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(tabs[i].url, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () { Navigator.pop(sc); setState(() { cur = i; addr.text = t.url; }); },
                trailing: IconButton(icon: const Icon(Icons.close), onPressed: () { Navigator.pop(sc); closeTab(i); }),
              ),
          ]),
        ),
      ),
    );
  }

  void downloadsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sc) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: ListenableBuilder(
          listenable: Downloader.i,
          builder: (c, _) {
            final l = Downloader.i.items;
            return Column(children: [
              const Padding(padding: EdgeInsets.all(14), child: Align(alignment: Alignment.centerLeft, child: Text('Download Manager', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
              Expanded(
                child: l.isEmpty
                    ? const Center(child: Text('Belum ada unduhan'))
                    : ListView(children: [
                        for (final d in l)
                          ListTile(
                            leading: Icon(d.status == 'selesai' ? Icons.check_circle : d.status == 'gagal' ? Icons.error : Icons.downloading),
                            title: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${d.status}${d.size > 0 ? ' • ${(d.size / 1048576).toStringAsFixed(1)} MB' : ''}'),
                            onTap: d.status == 'selesai' ? () => OpenFilex.open(d.path) : null,
                            trailing: d.status == 'selesai' ? IconButton(icon: const Icon(Icons.share), onPressed: () => Share.shareXFiles([XFile(d.path)])) : null,
                          ),
                      ]),
              ),
            ]);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => WillPopScope(
        onWillPop: () async {
          final c = t.ctl;
          if (c != null && await c.canGoBack()) {
            c.goBack();
            return false;
          }
          return true;
        },
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: SizedBox(
              height: 40,
              child: TextField(
                controller: addr,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: go,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  hintText: 'Cari atau ketik alamat',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Badge(label: Text('${tabs.length}'), child: const Icon(Icons.tab)),
                onPressed: tabsSheet,
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  switch (v) {
                    case 'new': newTab(); break;
                    case 'bm': listSheet('Bookmark', bookmarks); break;
                    case 'hist': listSheet('Riwayat browser', history, clearable: true); break;
                    case 'dl': downloadsSheet(); break;
                    case 'desk': toggleDesktop(); break;
                    case 'copy': await Clipboard.setData(ClipboardData(text: t.url)); snack('Link disalin'); break;
                    case 'ext': await launchUrl(Uri.parse(t.url), mode: LaunchMode.externalApplication); break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'new', child: Text('Tab baru')),
                  const PopupMenuItem(value: 'bm', child: Text('Bookmark')),
                  const PopupMenuItem(value: 'hist', child: Text('Riwayat')),
                  const PopupMenuItem(value: 'dl', child: Text('Download manager')),
                  PopupMenuItem(value: 'desk', child: Text(t.desktop ? 'Mode desktop: nyala' : 'Mode desktop: mati')),
                  const PopupMenuItem(value: 'copy', child: Text('Salin link')),
                  const PopupMenuItem(value: 'ext', child: Text('Buka di browser luar')),
                ],
              ),
            ],
          ),
          body: Column(children: [
            if (t.progress < 1) LinearProgressIndicator(value: t.progress),
            Expanded(child: IndexedStack(index: cur, children: [for (final tab in tabs) web(tab)])),
          ]),
          bottomNavigationBar: SizedBox(
            height: 52,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => t.ctl?.goBack()),
              IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => t.ctl?.goForward()),
              IconButton(icon: const Icon(Icons.refresh), onPressed: () => t.ctl?.reload()),
              IconButton(icon: Icon(isBm ? Icons.bookmark : Icons.bookmark_border), onPressed: toggleBm),
              IconButton(icon: const Icon(Icons.download), onPressed: downloadsSheet),
            ]),
          ),
        ),
      );
}
