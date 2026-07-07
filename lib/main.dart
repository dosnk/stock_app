import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages/home_page.dart';
import 'pages/trades_page.dart';
import 'pages/kline_page.dart';
import 'pages/positions_page.dart';
import 'pages/analysis_page.dart';
import 'pages/settings_page.dart';
import 'database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const StockApp());
}

class StockApp extends StatelessWidget {
  const StockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '股票交易助手',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF00C896),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F1923),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Color(0xFF0A1929),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1A2634),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF2A3A4A), width: 0.5),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0D1824),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2A3A4A)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2A3A4A)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF00C896)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C896),
            foregroundColor: const Color(0xFF0A1929),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF1A2634),
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    TradesPage(),
    KlinePage(),
    PositionsPage(),
    AnalysisPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: const Color(0xFF0A1929),
        indicatorColor: const Color(0xFF00C896).withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: Color(0xFF8899AA)),
            selectedIcon: Icon(Icons.home, color: Color(0xFF00C896)),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined, color: Color(0xFF8899AA)),
            selectedIcon: Icon(Icons.receipt_long, color: Color(0xFF00C896)),
            label: '交割单',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined, color: Color(0xFF8899AA)),
            selectedIcon: Icon(Icons.show_chart, color: Color(0xFF00C896)),
            label: 'K线',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline, color: Color(0xFF8899AA)),
            selectedIcon: Icon(Icons.work, color: Color(0xFF00C896)),
            label: '持仓',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined, color: Color(0xFF8899AA)),
            selectedIcon: Icon(Icons.auto_awesome, color: Color(0xFF00C896)),
            label: '分析',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 4
          ? null
          : FloatingActionButton.small(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage(isRoot: true)),
                );
              },
              backgroundColor: const Color(0xFF1A2634),
              child: const Icon(Icons.settings, color: Color(0xFF8899AA)),
            ),
    );
  }
}
