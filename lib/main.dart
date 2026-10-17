import 'package:flutter/material.dart';
import 'core/core.dart';
import 'screens/boot.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.i.load();
  await AppLock.i.load();
  runApp(const NexvoraApp());
}

class NexvoraApp extends StatelessWidget {
  const NexvoraApp({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: AppSettings.i,
        builder: (c, _) {
          final s = AppSettings.i;
          final seed = AppSettings.seeds[s.seed];
          return MaterialApp(
            title: 'Nexvora',
            debugShowCheckedModeBanner: false,
            themeMode: s.mode,
            theme: nexvoraTheme(Brightness.light, seed, s.anim),
            darkTheme: nexvoraTheme(Brightness.dark, seed, s.anim),
            builder: (context, child) => ListenableBuilder(
              listenable: AppLock.i,
              builder: (c, _) => Stack(children: [
                child ?? const SizedBox(),
                if (AppLock.i.locked) const Positioned.fill(child: LockScreen()),
                const Watermark(),
              ]),
            ),
            home: const Boot(),
          );
        },
      );
}
