import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/preferences.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/common.dart';
import '../../authentication/data/auth_repository.dart';
import '../../scoring/domain/verdict.dart';

/// User profile and application settings.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  final _currency = TextEditingController();
  final _password = TextEditingController();
  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _currency.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f, String ok) async {
    setState(() => _busy = true);
    try {
      await f();
      if (mounted) showSnack(context, ok);
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final prefs = ref.watch(preferencesProvider);
    final repo = ref.read(authRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & settings')),
      body: AsyncView(
        value: profile,
        onRetry: () => ref.invalidate(profileProvider),
        data: (p) {
          if (!_loaded) {
            _name.text = p.fullName ?? '';
            _currency.text = p.defaultCurrency;
            _loaded = true;
          }
          return PageBody(maxWidth: 640, children: [
            SectionCard(
              title: 'Profile',
              subtitle: p.email,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
                const SizedBox(height: 12),
                TextField(
                  controller: _currency,
                  decoration: const InputDecoration(labelText: 'Default currency'),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 3,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              if (!RegExp(r'^[A-Za-z]{3}$').hasMatch(_currency.text.trim())) {
                                throw const AppException('Currency must be a 3-letter code.');
                              }
                              await repo.updateProfile(fullName: _name.text, currency: _currency.text);
                              ref.invalidate(profileProvider);
                            }, 'Profile saved.'),
                    child: const Text('Save profile'),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Security',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password', helperText: 'At least 8 characters'),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              if (_password.text.length < 8) throw const AppException('Use at least 8 characters.');
                              await repo.updatePassword(_password.text);
                              _password.clear();
                            }, 'Password updated.'),
                    child: const Text('Change password'),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Appearance',
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('System')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ],
                selected: {prefs.themeMode},
                onSelectionChanged: (s) => ref.read(preferencesProvider.notifier).setThemeMode(s.first),
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'About',
              child: Text('EquiLense compares the reported financial performance of PSX-listed companies. '
                  '$disclaimer'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _run(repo.signOut, 'Signed out.'),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ]);
        },
      ),
    );
  }
}
