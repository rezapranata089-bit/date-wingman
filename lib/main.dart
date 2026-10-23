import 'package:flutter/material.dart';

import 'history_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings();
  await settings.load();
  runApp(DateApp(settings: settings));
}

class DateApp extends StatelessWidget {
  final AppSettings settings;
  const DateApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFE91E63);
    return MaterialApp(
      title: 'Date Wingman',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
      ),
      home: RootShell(settings: settings),
    );
  }
}

class RootShell extends StatefulWidget {
  final AppSettings settings;
  const RootShell({super.key, required this.settings});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            settings: widget.settings,
            onCaptured: () {
              if (_index != 0) setState(() => _index = 0);
            },
            onGoSettings: () => setState(() => _index = 2),
          ),
          HistoryScreen(settings: widget.settings),
          SettingsScreen(settings: widget.settings),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Bantu',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}
