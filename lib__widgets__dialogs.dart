import 'package:flutter/material.dart';

Future<bool> act(BuildContext c, Future Function() f, [String ok = 'Berhasil']) async {
  try {
    await f();
    if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(ok)));
    return true;
  } catch (e) {
    if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('$e')));
    return false;
  }
}

Future<Map<String, String>?> form(BuildContext c, String title, List<String> fields, {List<String> secret = const []}) {
  final ctr = {for (final f in fields) f: TextEditingController()};
  return showDialog<Map<String, String>>(
    context: c,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final f in fields)
            TextField(controller: ctr[f], obscureText: secret.contains(f), decoration: InputDecoration(labelText: f)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(d, {for (final f in fields) f: ctr[f]!.text.trim()}), child: const Text('OK')),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext c, String msg) async =>
    (await showDialog<bool>(
      context: c,
      builder: (d) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Ya')),
        ],
      ),
    )) ??
    false;
