import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/providers/account_provider.dart';
import 'package:receipto/providers/budget_provider.dart';
import 'package:receipto/providers/category_provider.dart';
import 'package:receipto/providers/goal_provider.dart';
import 'package:receipto/providers/recurring_provider.dart';
import 'package:receipto/providers/settings_provider.dart';
import 'package:receipto/providers/transaction_provider.dart';
import 'package:receipto/screens/analytics_screen.dart';
import 'package:receipto/screens/chatbot_screen.dart';
import 'package:receipto/screens/home_screen.dart';
import 'package:receipto/screens/settings_screen.dart';
import 'package:receipto/services/backup_service.dart';
import 'package:receipto/widgets/glass.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ReceiptoApp());
}

class ReceiptoApp extends StatelessWidget {
  const ReceiptoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProvider(create: (_) => GoalProvider()),
        ChangeNotifierProvider(create: (_) => RecurringProvider()),
        ChangeNotifierProvider(create: (_) => AccountProvider()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        // Every route paints its own opaque glass backdrop (via the page
        // transitions builder), so pushes fully cover the previous page instead
        // of letting it bleed through a transparent scaffold during the slide.
        theme: AppTheme.darkTheme.copyWith(
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: GlassPageTransitionsBuilder(),
              TargetPlatform.iOS: GlassPageTransitionsBuilder(),
              TargetPlatform.fuchsia: GlassPageTransitionsBuilder(),
              TargetPlatform.linux: GlassPageTransitionsBuilder(),
              TargetPlatform.macOS: GlassPageTransitionsBuilder(),
              TargetPlatform.windows: GlassPageTransitionsBuilder(),
            },
          ),
        ),
        debugShowCheckedModeBanner: false,
        home: const AppShell(),
      ),
    );
  }
}

/// Root shell widget that manages the bottom navigation and tab screens.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  // The four main tab screens.
  final List<Widget> _screens = const [
    HomeScreen(),
    AnalyticsScreen(),
    ChatbotScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Load initial data after the first frame.
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    final txnProvider = context.read<TransactionProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final budgetProvider = context.read<BudgetProvider>();
    final goalProvider = context.read<GoalProvider>();
    final recurringProvider = context.read<RecurringProvider>();
    final accountProvider = context.read<AccountProvider>();

    // Materialise any due recurring transactions before loading the month so
    // they show up immediately.
    await recurringProvider.processDue();

    await Future.wait([
      txnProvider.loadTransactions(),
      settingsProvider.loadSettings(),
      categoryProvider.loadCategories(),
      budgetProvider.loadBudgets(),
      goalProvider.loadGoals(),
      recurringProvider.loadRecurring(),
      accountProvider.loadAccounts(),
    ]);

    // Fire-and-forget auto-backup — never blocks the UI.
    _runAutoBackup();
  }

  /// Runs auto-backup silently after app load.
  /// Only shows feedback on failure.
  void _runAutoBackup() {
    BackupService.autoBackup().catchError((Object e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Auto-backup failed. Check your Google Drive '
              'connection in Backup settings.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack preserves state across tab switches.
      body: IndexedStack(index: _currentIndex, children: _screens),
      // Frosted-glass bottom bar: a real blur of the backdrop behind a
      // translucent white fill. A single persistent instance, so the live blur
      // is cheap (unlike per-row list blur, which we avoid).
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: const BoxDecoration(
              color: AppTheme.glassRowFill,
              border: Border(
                top: BorderSide(color: AppTheme.glassBorderSoft, width: 1),
              ),
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Analytics',
                ),
                NavigationDestination(
                  icon: Icon(Icons.smart_toy_outlined),
                  selectedIcon: Icon(Icons.smart_toy),
                  label: 'Chat',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
