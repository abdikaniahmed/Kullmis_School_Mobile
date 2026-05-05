import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_messages.dart';

const _languageStorageKey = 'language';

class AppLanguageController extends ChangeNotifier {
  AppLanguageController({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;
  Locale _locale = const Locale('en');

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';
  TextDirection get textDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  Future<void> load() async {
    final storedLocale = await _storage.read(key: _languageStorageKey);
    _setLocaleCode(storedLocale, persist: false);
  }

  Future<void> setLocale(Locale locale) async {
    await _setLocaleCode(locale.languageCode);
  }

  Future<void> toggleLocale() async {
    await _setLocaleCode(isArabic ? 'en' : 'ar');
  }

  Future<void> _setLocaleCode(String? code, {bool persist = true}) async {
    final normalizedCode = code == 'ar' ? 'ar' : 'en';
    final nextLocale = Locale(normalizedCode);

    if (_locale == nextLocale) {
      return;
    }

    _locale = nextLocale;
    if (persist) {
      await _storage.write(key: _languageStorageKey, value: normalizedCode);
    }
    notifyListeners();
  }

  String t(String key, [String fallback = '']) {
    final normalizedKey = _messageFor('en', key) != null ||
            _messageFor('ar', key) != null
        ? key
        : _keyFromText(key);

    return _messageFor(_locale.languageCode, normalizedKey) ??
        _messageFor('en', normalizedKey) ??
        fallback.ifNotEmpty ??
        key;
  }

  String trans(
    String key, {
    Map<String, Object?> replacements = const <String, Object?>{},
    String fallback = '',
  }) {
    var message = t(key, fallback);
    for (final entry in replacements.entries) {
      message = message.replaceAll(':${entry.key}', '${entry.value ?? ''}');
    }
    return message;
  }

  String? _messageFor(String locale, String key) => appMessages[locale]?[key];

  String _keyFromText(String text) {
    return text
        .trim()
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}

extension on String {
  String? get ifNotEmpty => isEmpty ? null : this;
}

class AppLanguageScope extends InheritedNotifier<AppLanguageController> {
  const AppLanguageScope({
    super.key,
    required AppLanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLanguageController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    assert(scope != null, 'AppLanguageScope was not found in the widget tree.');
    return scope!.notifier!;
  }
}

extension AppLanguageBuildContext on BuildContext {
  AppLanguageController get language => AppLanguageScope.of(this);
  String tr(String key, [String fallback = '']) => language.t(key, fallback);
}
