import 'package:flutter/material.dart';
import '../core/core.dart';
import 'tool_page.dart';
import 'am_zarvida_page.dart';
import 'swwa_page.dart';
import 'browser_page.dart';
import 'files_page.dart';
import 'media_tools.dart';

IconData toolIcon(String? k) {
  switch (k) {
    case 'text': return Icons.text_fields;
    case 'id': return Icons.badge;
    case 'qr': return Icons.qr_code_2;
    case 'ip': return Icons.public;
    case 'key': return Icons.password;
    case 'cek': return Icons.auto_awesome;
    case 'love': return Icons.favorite;
    case 'preset': return Icons.movie_filter;
    case 'video': return Icons.hd;
    case 'browser': return Icons.language;
    case 'folder': return Icons.folder;
    case 'scan': return Icons.qr_code_scanner;
    case 'ocr': return Icons.document_scanner;
    case 'speaker': return Icons.volume_up;
    case 'mic': return Icons.mic;
    case 'translate': return Icons.translate;
    case 'uuid': return Icons.tag;
    case 'json': return Icons.data_object;
    case 'web': return Icons.cloud;
    case 'code': return Icons.code;
    case 'bolt': return Icons.bolt;
    default: return Icons.build;
  }
}

Widget? appPage(String route) {
  switch (route) {
    case 'am_zarvida': return const AmZarvidaPage();
    case 'sw_wa': return const SwWaPage();
    case 'browser': return const BrowserPage();
    case 'files': return const FileManagerPage();
    case 'qr_scan': return const QrScanPage();
    case 'ocr': return const OcrPage();
    case 'tts': return const TtsPage();
    case 'stt': return const SttPage();
  }
  return null;
}

Future<void> openTool(BuildContext c, Map t) async {
  if (t['suspended'] == true) {
    final r = '${t['reason'] ?? ''}';
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('${t['name']} sedang dinonaktifkan${r.isEmpty ? '' : ': $r'}')));
    return;
  }
  if (t['kind'] == 'app') {
    final page = appPage('${t['route']}');
    if (page != null) {
      await Navigator.push(c, MaterialPageRoute(builder: (_) => page));
      return;
    }
  }
  await Navigator.push(c, MaterialPageRoute(builder: (_) => ToolPage(tool: t)));
}

Widget toolTile(BuildContext c, Map t, VoidCallback onChanged) {
  final susp = t['suspended'] == true;
  final r = '${t['reason'] ?? ''}';
  return Opacity(
    opacity: susp ? 0.5 : 1,
    child: MenuTile(
      icon: susp ? Icons.pause_circle : toolIcon(t['icon']),
      title: '${t['name']}',
      subtitle: susp ? 'Dinonaktifkan${r.isEmpty ? '' : ': $r'}' : '${t['desc']}',
      trailing: IconButton(
        icon: Icon(t['fav'] == true ? Icons.star : Icons.star_border),
        onPressed: () async {
          try {
            await Api.post('/api/favorites/${t['id']}');
            onChanged();
          } catch (_) {}
        },
      ),
      onTap: () async {
        await openTool(c, t);
        onChanged();
      },
    ),
  );
}
