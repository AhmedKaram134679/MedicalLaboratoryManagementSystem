import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_provider.dart';
import 'services/automation_service.dart';
import 'services/database_service.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/main_layout.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/localization/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Handle known Flutter engine/framework-level editable assertion bug gracefully
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final exceptionStr = details.exception.toString();
    if (exceptionStr.contains('editable.dart') && exceptionStr.contains('isValid')) {
      // Suppress framework-level internal caret navigation assertion on desktop
      debugPrint('Suppressed framework internal caret movement assertion: ${details.summary}');
      return;
    }
    if (originalOnError != null) {
      originalOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  // Initialize window manager
  await windowManager.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Initialize FFI for SQFlite on Desktop
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(800, 500),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: "LabManagementSystem",
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setMinimumSize(const Size(800, 500));
      await windowManager.show();
      await windowManager.focus();
    });
  }
 
  // Pre-warm database in background
  DatabaseService().preWarm();

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppProvider())],
      child: const MyApp(),
    ),
  );

  // Defer non-critical startup tasks until after the immediate UI is ready
  Future.delayed(const Duration(milliseconds: 500), () {
    AutomationService().start();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.maximize();
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return MaterialApp(
      title: 'LabManagmentSystem',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: provider.themeMode,
      locale: provider.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: provider.currentUser != null
          ? const MainLayout()
          : const LoginScreen(),
    );
  }
}
