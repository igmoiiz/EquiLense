import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive local UI preferences. Credentials are never stored here;
/// the Supabase SDK manages the session itself.
class Preferences {
  const Preferences({required this.themeMode, required this.onboardingSeen});

  final ThemeMode themeMode;
  final bool onboardingSeen;

  Preferences copyWith({ThemeMode? themeMode, bool? onboardingSeen}) => Preferences(
        themeMode: themeMode ?? this.themeMode,
        onboardingSeen: onboardingSeen ?? this.onboardingSeen,
      );
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('override in main'));

class PreferencesNotifier extends Notifier<Preferences> {
  static const _themeKey = 'theme_mode';
  static const _onboardingKey = 'onboarding_seen';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  Preferences build() {
    final p = ref.watch(sharedPreferencesProvider);
    return Preferences(
      themeMode: ThemeMode.values.asNameMap()[p.getString(_themeKey)] ?? ThemeMode.system,
      onboardingSeen: p.getBool(_onboardingKey) ?? false,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(_themeKey, mode.name);
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(onboardingSeen: true);
    await _prefs.setBool(_onboardingKey, true);
  }
}

final preferencesProvider = NotifierProvider<PreferencesNotifier, Preferences>(PreferencesNotifier.new);
