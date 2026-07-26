import 'dart:ui' show ImageFilter;

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
import 'package:receipto/widgets/pressable.dart';

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
  final PageController _pageController = PageController();

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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Slides to [index] with a smooth horizontal transition (the direction is
  /// inferred automatically from the current page).
  void _goToTab(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index); // immediate nav-pill highlight
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
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
      // Let the body extend behind the nav so the pill floats over the content
      // (like the reference) instead of sitting in a reserved bar.
      extendBody: true,
      // PageView slides between tabs; keep-alive wrappers preserve each tab's
      // state (scroll position, etc.) like the old IndexedStack did. Swipe is
      // disabled so only nav taps drive the transition.
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _currentIndex = i),
        children: [
          for (final screen in _screens) _KeepAlivePage(child: screen),
        ],
      ),
      // Floating white pill nav (ParkingLah-style): active tab gets a rounded
      // light-blue highlight with a blue icon + label.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          // Shadow on the outer box (kept outside the clip); the inner layer is
          // a real backdrop blur of the content behind + a translucent white
          // fill, so a hint of the page shows through the pill.
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: AppTheme.glassShadow,
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.navGlassFill,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: const Color(0x99FFFFFF),
                      width: 1,
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Stack(
                    children: [
                      // Single highlight that slides between the four slots,
                      // in sync with the page transition.
                      Positioned.fill(
                        child: AnimatedAlign(
                          alignment: Alignment((_currentIndex - 1.5) * 2 / 3, 0),
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeInOutCubic,
                          child: FractionallySizedBox(
                            widthFactor: 1 / 4,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.goldDark,
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          _navItem(0, Icons.home_outlined, Icons.home, 'Home'),
                          _navItem(1, Icons.bar_chart_outlined,
                              Icons.bar_chart, 'Analytics'),
                          _navItem(2, Icons.smart_toy_outlined,
                              Icons.smart_toy, 'Chat'),
                          _navItem(3, Icons.settings_outlined, Icons.settings,
                              'Settings'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData activeIcon, String label) {
    final selected = _currentIndex == index;
    // Crossfade the icon/label colour over the same window as the sliding
    // highlight so the whole thing moves together.
    return Expanded(
      child: PressableScale(
        onTap: () => _goToTab(index),
        pressedScale: 0.86,
        pressedOpacity: 0.6,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: selected ? 1 : 0),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            builder: (context, t, _) {
              final color = Color.lerp(AppTheme.textMuted, AppTheme.gold, t)!;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(selected ? activeIcon : icon, size: 22, color: color),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          t > 0.5 ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Keeps a tab's element tree alive while it's off-screen in the [PageView], so
/// switching tabs preserves scroll position and other ephemeral state (the same
/// guarantee the previous IndexedStack gave).
class _KeepAlivePage extends StatefulWidget {
  final Widget child;

  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

