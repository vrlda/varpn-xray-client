import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/localization/app_localizations.dart';
import 'core/providers/ping_monitor_provider.dart';
import 'core/router/app_router.dart';
import 'core/providers/settings_provider.dart';
import 'core/services/app_log_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Open settings box
  await Hive.openBox(Settings.boxName);

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogService.instance.error(
      source: 'app',
      message:
          'Flutter error: ${details.exceptionAsString()}\n${details.stack?.toString().split('\n').take(8).join('\n') ?? ''}',
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogService.instance.error(
      source: 'app',
      message:
          'Platform error: $error\n${stack.toString().split('\n').take(8).join('\n')}',
    );
    return false;
  };

  await runZonedGuarded(
    () async {
      runApp(
        const ProviderScope(
          child: VarPNApp(),
        ),
      );
    },
    (error, stack) {
      AppLogService.instance.error(
        source: 'app',
        message:
            'Uncaught error: $error\n${stack.toString().split('\n').take(8).join('\n')}',
      );
    },
  );
}

class VarPNApp extends ConsumerWidget {
  const VarPNApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    ref.watch(pingMonitorProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      locale: AppLocalizations.localeFromCode(settings.language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: AppTheme.themeModeFrom(settings.theme),
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
