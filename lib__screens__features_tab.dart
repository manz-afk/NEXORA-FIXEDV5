import 'package:flutter/material.dart';
import '../core/core.dart';
import 'tool_tile.dart';

class FeaturesTab extends StatelessWidget {
  const FeaturesTab({super.key});
  @override
  Widget build(BuildContext context) => Loader(
        load: () => Api.get('/api/tools'),
        build: (c, d, r) {
          final tools = d['tools'] as List;
          return ListView(padding: const EdgeInsets.all(12), children: [
            const Padding(padding: EdgeInsets.fromLTRB(4, 12, 4, 4), child: Text('Alat', style: TextStyle(fontWeight: FontWeight.bold))),
            for (final t in tools) toolTile(c, t, r),
          ]);
        },
      );
}
