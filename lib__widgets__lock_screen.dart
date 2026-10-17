import 'package:flutter/material.dart';
import '../core/applock.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String pin = '';
  String? err;

  @override
  void initState() {
    super.initState();
    if (AppLock.i.bioOn) WidgetsBinding.instance.addPostFrameCallback((_) => bio());
  }

  Future<void> bio() async {
    if (await AppLock.i.authBio()) AppLock.i.unlock();
  }

  void press(String d) {
    if (pin.length >= 6) return;
    setState(() { pin += d; err = null; });
    if (pin.length == 6) {
      if (AppLock.i.check(pin)) {
        AppLock.i.unlock();
      } else {
        setState(() { pin = ''; err = 'PIN salah'; });
      }
    }
  }

  Widget key(Widget child, VoidCallback? onTap) => SizedBox(width: 84, height: 64, child: TextButton(onPressed: onTap, child: child));

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.asset('assets/logo.png', width: 72, height: 72)),
              const SizedBox(height: 10),
              const Text('NEXVORA', style: TextStyle(fontSize: 18, letterSpacing: 6, fontWeight: FontWeight.w300)),
              const SizedBox(height: 18),
              const Text('Masukkan PIN'),
              const SizedBox(height: 14),
              Row(mainAxisSize: MainAxisSize.min, children: [
                for (int i = 0; i < 6; i++)
                  Container(margin: const EdgeInsets.symmetric(horizontal: 6), width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: i < pin.length ? Theme.of(context).colorScheme.primary : Colors.grey.withOpacity(0.35))),
              ]),
              SizedBox(height: 22, child: err == null ? null : Padding(padding: const EdgeInsets.only(top: 4), child: Text(err!, style: const TextStyle(color: Colors.redAccent)))),
              const SizedBox(height: 10),
              for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']])
                Row(mainAxisSize: MainAxisSize.min, children: [for (final d in row) key(Text(d, style: const TextStyle(fontSize: 24)), () => press(d))]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                key(AppLock.i.bioOn ? const Icon(Icons.fingerprint, size: 30) : const SizedBox(), AppLock.i.bioOn ? bio : null),
                key(const Text('0', style: TextStyle(fontSize: 24)), () => press('0')),
                key(const Icon(Icons.backspace_outlined), () => setState(() { if (pin.isNotEmpty) pin = pin.substring(0, pin.length - 1); })),
              ]),
            ]),
          ),
        ),
      );
}
