import 'package:flutter/material.dart';
import 'package:financer/providers/budget_provider.dart';
import 'package:financer/screens/home_screen.dart';
import 'package:financer/services/storage_service.dart';
import 'package:financer/services/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.init();
  final themeController = await ThemeController.init();
  runApp(FinanceApp(storage: storage, themeController: themeController));
}

class FinanceApp extends StatefulWidget {
  const FinanceApp(
      {super.key, required this.storage, required this.themeController});
  final StorageService storage;
  final ThemeController themeController;

  @override
  State<FinanceApp> createState() => _FinanceAppState();
}

class _FinanceAppState extends State<FinanceApp> with WidgetsBindingObserver {
  late final BudgetProvider _budget = BudgetProvider(storage: widget.storage);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _budget.dispose();
    widget.themeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _budget.flush();
  }

  ThemeData _lightTheme() {
    const canvas = Color(0xFFF8FAFC);
    const teal = Color(0xFF0F766E);
    const cyan = Color(0xFF0891B2);
    final scheme =
        ColorScheme.fromSeed(seedColor: teal, brightness: Brightness.light)
            .copyWith(
      primary: teal,
      secondary: cyan,
      surface: Colors.white,
      error: const Color(0xFFDC3348),
      tertiary: const Color(0xFF15803D),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      appBarTheme: const AppBarTheme(
          backgroundColor: canvas,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          centerTitle: false),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: teal, width: 1.6)),
      ),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: teal, foregroundColor: Colors.white),
    );
  }

  ThemeData _darkTheme() {
    const canvas = Color(0xFF0F172A);
    const surface = Color(0xFF1E293B);
    const teal = Color(0xFF2DD4BF);
    const cyan = Color(0xFF22D3EE);
    final scheme =
        ColorScheme.fromSeed(seedColor: teal, brightness: Brightness.dark)
            .copyWith(
      primary: teal,
      secondary: cyan,
      surface: surface,
      error: const Color(0xFFFB7185),
      tertiary: const Color(0xFF4ADE80),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      appBarTheme: const AppBarTheme(
          backgroundColor: canvas,
          foregroundColor: Color(0xFFE2E8F0),
          elevation: 0,
          centerTitle: false),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: teal, width: 1.6)),
      ),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: teal, foregroundColor: Color(0xFF042F2E)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.themeController,
      builder: (context, _) => MaterialApp(
        title: 'Personal Finance',
        debugShowCheckedModeBanner: false,
        theme: _lightTheme(),
        darkTheme: _darkTheme(),
        themeMode: widget.themeController.mode,
        themeAnimationDuration: const Duration(milliseconds: 250),
        home: HomeScreen(
            budget: _budget, themeController: widget.themeController),
      ),
    );
  }
}
