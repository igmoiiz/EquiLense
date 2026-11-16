import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/common.dart';
import '../data/auth_repository.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? v) =>
    (v == null || !_emailRe.hasMatch(v.trim())) ? 'Enter a valid email address' : null;

String? validatePassword(String? v) => (v == null || v.length < 8) ? 'Use at least 8 characters' : null;

/// Shared centered card layout for auth forms.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.title, required this.subtitle, required this.children});

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Icon(Icons.analytics_outlined, color: t.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('EquiLense', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 32),
                Text(title, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(subtitle, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 24),
                ...children,
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).signIn(_email.text, _password.text);
      // Router redirect handles navigation on auth change.
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
        title: 'Sign in',
        subtitle: 'Access your saved company comparisons.',
        children: [
          Form(
            key: _form,
            child: AutofillGroup(
              child: Column(children: [
                TextFormField(
                  key: const Key('login-email'),
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: validateEmail,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('login-password'),
                  controller: _password,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                ),
              ]),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => context.push('/forgot-password'), child: const Text('Forgot password?')),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('login-submit'),
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Sign in'),
          ),
          const SizedBox(height: 16),
          Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Text('New to EquiLense?'),
            TextButton(onPressed: () => context.go('/register'), child: const Text('Create an account')),
          ]),
        ],
      );
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _awaitingConfirmation = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final outcome = await ref
          .read(authRepositoryProvider)
          .signUp(email: _email.text, password: _password.text, fullName: _name.text);
      if (outcome == SignUpOutcome.confirmationRequired && mounted) setState(() => _awaitingConfirmation = true);
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_awaitingConfirmation) {
      return AuthLayout(
        title: 'Check your email',
        subtitle: 'We sent a confirmation link to ${_email.text.trim()}. Open it, then sign in.',
        children: [FilledButton(onPressed: () => context.go('/login'), child: const Text('Back to sign in'))],
      );
    }
    return AuthLayout(
      title: 'Create account',
      subtitle: 'Your companies, documents and analyses are private to your account.',
      children: [
        Form(
          key: _form,
          child: Column(children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name'),
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: validateEmail,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Password', helperText: 'At least 8 characters'),
              obscureText: true,
              textInputAction: TextInputAction.next,
              validator: validatePassword,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              decoration: const InputDecoration(labelText: 'Confirm password'),
              obscureText: true,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) => v != _password.text ? 'Passwords do not match' : null,
            ),
          ]),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create account'),
        ),
        const SizedBox(height: 16),
        Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const Text('Already registered?'),
          TextButton(onPressed: () => context.go('/login'), child: const Text('Sign in')),
        ]),
      ],
    );
  }
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
        title: _sent ? 'Email sent' : 'Reset password',
        subtitle: _sent
            ? 'If an account exists for ${_email.text.trim()}, a reset link is on its way.'
            : 'Enter your account email and we will send you a reset link.',
        children: [
          if (!_sent) ...[
            Form(
              key: _form,
              child: TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                onFieldSubmitted: (_) => _submit(),
                validator: validateEmail,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _busy ? null : _submit, child: const Text('Send reset link')),
          ],
          const SizedBox(height: 12),
          TextButton(onPressed: () => context.go('/login'), child: const Text('Back to sign in')),
        ],
      );
}

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      widget.onDone();
      if (mounted) {
        showSnack(context, 'Password updated.');
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
        title: 'Choose a new password',
        subtitle: 'Enter a new password for your account.',
        children: [
          Form(
            key: _form,
            child: TextFormField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'New password'),
              obscureText: true,
              validator: validatePassword,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _submit, child: const Text('Update password')),
        ],
      );
}
