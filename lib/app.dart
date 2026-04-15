import 'package:flutter/material.dart';

import 'screens/session_gate.dart';
import 'services/laravel_api.dart';
import 'services/token_store.dart';

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.api,
    this.tokenStore,
  });

  final LaravelApi? api;
  final TokenStore? tokenStore;

  @override
  Widget build(BuildContext context) {
    const canvas = Color(0xFFF4EFE6);
    const ink = Color(0xFF1F2933);

    return MaterialApp(
      title: 'Kullmis School Mobile',
      debugShowCheckedModeBanner: false,
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
        api: api ?? LaravelApi(),
        tokenStore: tokenStore ?? const SecureTokenStore(),
      ),
    );
  }
}
