import 'package:flutter/material.dart';

class Watermark extends StatelessWidget {
  const Watermark({super.key});
  @override
  Widget build(BuildContext context) => const Positioned(
        left: 0,
        right: 0,
        bottom: 3,
        child: IgnorePointer(
          child: Center(
            child: Text('by manz', style: TextStyle(fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600, color: Color.fromRGBO(150, 150, 160, 0.6), decoration: TextDecoration.none)),
          ),
        ),
      );
}
