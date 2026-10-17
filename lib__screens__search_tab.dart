import 'package:flutter/material.dart';
import '../core/core.dart';
import 'dart:async';
import 'tool_tile.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});
  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final q = TextEditingController();
  Timer? t;
  List tools = [];
  List history = [];
  String? err;
  bool busy = false, searched = false;

  void changed(String v) {
    t?.cancel();
    t = Timer(const Duration(milliseconds: 400), search);
  }

  Future<void> search() async {
    final s = q.text.trim();
    if (s.isEmpty) {
      setState(() { tools = []; history = []; searched = false; err = null; });
      return;
    }
    setState(() => busy = true);
    try {
      final r = await Api.get('/api/search?q=${Uri.encodeQueryComponent(s)}');
      setState(() { tools = r['tools'] as List; history = r['history'] as List; err = null; searched = true; });
    } catch (e) {
      setState(() => err = '$e');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(controller: q, onChanged: changed, decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Cari fitur atau riwayat', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        ),
        if (busy) const LinearProgressIndicator(),
        Expanded(
          child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            if (err != null) Padding(padding: const EdgeInsets.all(8), child: Text(err!)),
            if (searched && tools.isEmpty && history.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Tidak ada hasil'))),
            if (tools.isNotEmpty) const Padding(padding: EdgeInsets.fromLTRB(4, 8, 4, 4), child: Text('Fitur', style: TextStyle(fontWeight: FontWeight.bold))),
            for (final x in tools) toolTile(context, x, search),
            if (history.isNotEmpty) const Padding(padding: EdgeInsets.fromLTRB(4, 12, 4, 4), child: Text('Riwayat', style: TextStyle(fontWeight: FontWeight.bold))),
            for (final h in history)
              GradCard(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${h['toolName']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${h['input']}  •  ${tgl(h['t'])}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ])),
          ]),
        ),
      ]);
}
