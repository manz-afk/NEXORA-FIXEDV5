import 'package:flutter/material.dart';
import '../core/core.dart';
import 'tool_tile.dart';

class FavoritesTab extends StatelessWidget {
  const FavoritesTab({super.key});
  @override
  Widget build(BuildContext context) => Loader(
        load: () => Api.get('/api/favorites'),
        build: (c, d, r) {
          final tools = d['tools'] as List;
          if (tools.isEmpty) return ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Belum ada favorit.\nKetuk bintang di tab Fitur.', textAlign: TextAlign.center)))]);
          return ListView(padding: const EdgeInsets.all(12), children: [for (final t in tools) toolTile(c, t, r)]);
        },
      );
}
