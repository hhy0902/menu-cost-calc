import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'screens/ingredient_list_screen.dart';
import 'screens/settings_screen.dart';

class CostApp extends StatelessWidget {
  const CostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '원가 계산기',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = [
    DashboardScreen(),
    IngredientListScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.restaurant_menu), label: '메뉴'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: '식자재'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: '설정'),
        ],
      ),
    );
  }
}
