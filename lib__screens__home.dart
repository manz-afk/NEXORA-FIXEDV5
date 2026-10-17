import 'package:flutter/material.dart';
import '../core/core.dart';
import 'dash_tab.dart';
import 'features_tab.dart';
import 'search_tab.dart';
import 'favorites_tab.dart';
import 'account_tab.dart';
import 'update_check.dart';
import '../core/widget_sync.dart';

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int i = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkUpdate(context);
      syncWidget();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [const DashTab(), const FeaturesTab(), const SearchTab(), const FavoritesTab(), const AccountTab()];
    return Scaffold(
      appBar: AppBar(title: Text(['Beranda', 'Fitur', 'Cari', 'Favorit', 'Akun'][i])),
      body: Column(children: [
        ValueListenableBuilder<bool>(
          valueListenable: Api.fromCache,
          builder: (c, v, _) => v
              ? Container(width: double.infinity, color: Colors.orange.withOpacity(0.2), padding: const EdgeInsets.all(6), child: const Text('Mode offline: menampilkan data terakhir', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)))
              : const SizedBox.shrink(),
        ),
        Expanded(child: pages[i]),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (v) => setState(() => i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.apps), label: 'Fitur'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Cari'),
          NavigationDestination(icon: Icon(Icons.star), label: 'Favorit'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Akun'),
        ],
      ),
    );
  }
}
