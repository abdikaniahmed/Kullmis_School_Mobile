import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_language.dart';
import 'screens/session_gate.dart';
import 'services/laravel_api.dart';
import 'services/offline_cache_store.dart';
import 'services/token_store.dart';

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.api,
    this.tokenStore,
    this.offlineCacheStore,
  });

  final LaravelApi? api;
  final TokenStore? tokenStore;
  final OfflineCacheStore? offlineCacheStore;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppLanguageController _languageController = AppLanguageController();

  @override
  void initState() {
    super.initState();
    _languageController.load();
  }

  @override
  void dispose() {
    _languageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const canvas = Color(0xFFF4EFE6);
    const ink = Color(0xFF1F2933);

    return AnimatedBuilder(
      animation: _languageController,
      builder: (context, _) {
        return AppLanguageScope(
          controller: _languageController,
          child: MaterialApp(
            title: _languageController.t('kullmis_school'),
            debugShowCheckedModeBanner: false,
            locale: _languageController.locale,
            supportedLocales: const [
              Locale('en'),
              Locale('ar'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            theme: ThemeData(
              useMaterial3: true,
              scaffoldBackgroundColor: canvas,
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF0F766E),
                secondary: Color(0xFFCB6E17),
                surface: Colors.white,
                onPrimary: Colors.white,
                onSecondary: Colors.white,
                onSurface: ink,
              ),
              textTheme: const TextTheme(
                headlineLarge: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
                headlineMedium: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
                titleLarge: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
                bodyLarge: TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: ink,
                ),
                bodyMedium: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Color(0xFF52606D),
                ),
              ),
            ),
            home: SessionGate(
              api: widget.api ?? LaravelApi(),
              tokenStore: widget.tokenStore ?? const SecureTokenStore(),
              offlineCacheStore:
                  widget.offlineCacheStore ?? const FileOfflineCacheStore(),
            ),
          ),
        );
      },
    );
  }
}
