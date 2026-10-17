import 'package:flutter/material.dart';

class Loader extends StatefulWidget {
  final Future<dynamic> Function() load;
  final Widget Function(BuildContext, dynamic, VoidCallback) build;
  const Loader({super.key, required this.load, required this.build});
  @override
  State<Loader> createState() => _LoaderState();
}

class _LoaderState extends State<Loader> {
  late Future<dynamic> f;
  @override
  void initState() {
    super.initState();
    f = widget.load();
  }

  void reload() => setState(() => f = widget.load());

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: f,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (s.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(padding: const EdgeInsets.all(16), child: Text('${s.error}', textAlign: TextAlign.center)),
                FilledButton(onPressed: reload, child: const Text('Coba lagi')),
              ]),
            );
          }
          return RefreshIndicator(onRefresh: () async => reload(), child: widget.build(c, s.data, reload));
        },
      );
}
