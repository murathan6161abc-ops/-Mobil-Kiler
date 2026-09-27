import 'package:flutter/material.dart';
import 'package:mobil_uygulamam/screens/chat_screen.dart';
import 'package:mobil_uygulamam/screens/inventory_screen.dart';
import 'package:mobil_uygulamam/screens/settings_screen.dart';
import 'package:mobil_uygulamam/screens/stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  // Sekmeye her geçişte ilgili ekranın verisini tazelemek için
  int _statsVersion = 0;
  int _inventoryVersion = 0;

  void _select(int index) {
    setState(() {
      if (index == 1 && _index != 1) _statsVersion++;
      // Ayarlardan (ör. sunucu adresi değişince) dönüldüğünde listeyi yenile
      if (index == 0 && _index == 3) _inventoryVersion++;
      _index = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          InventoryScreen(refreshToken: _inventoryVersion),
          StatsScreen(refreshToken: _statsVersion),
          const ChatScreen(embedded: true),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.kitchen_outlined),
            selectedIcon: Icon(Icons.kitchen),
            label: 'Kilerim',
          ),
          NavigationDestination(icon: Icon(Icons.eco_outlined), selectedIcon: Icon(Icons.eco), label: 'Etki'),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Asistan',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}
