import 'package:flutter/material.dart';

BoxDecoration gradDecoration(BuildContext c, {double radius = 16}) {
  final dark = Theme.of(c).brightness == Brightness.dark;
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: dark ? const Color(0xFF2A2A2F) : const Color(0xFFB5B5BC)),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark ? const [Color(0xFF2E2E33), Color(0xFF151517), Color(0xFF050506)] : const [Color(0xFFF1F1F4), Color(0xFFDCDCE1), Color(0xFFC6C6CD)],
    ),
  );
}

class GradCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const GradCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: gradDecoration(context),
            child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: Padding(padding: padding, child: child)),
          ),
        ),
      );
}

class MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const MenuTile({super.key, required this.icon, required this.title, this.subtitle, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) => GradCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ),
          trailing ?? const Icon(Icons.chevron_right),
        ]),
      );
}
