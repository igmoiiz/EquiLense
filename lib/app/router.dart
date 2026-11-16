import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/supabase_providers.dart';
import '../features/analysis/presentation/analyses_screen.dart';
import '../features/analysis/presentation/analysis_hub_screen.dart';
import '../features/analysis/presentation/new_analysis_screen.dart';
import '../features/authentication/presentation/auth_screens.dart';
import '../features/authentication/presentation/onboarding_screen.dart';
import '../features/companies/presentation/companies_screen.dart';
import '../features/comparison/presentation/results_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/documents/presentation/documents_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/validation/presentation/validation_screen.dart';
import 'app_shell.dart';
import 'preferences.dart';

/// Re-runs router redirects whenever auth state changes.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(SupabaseClient db) {
    _sub = db.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.passwordRecovery) recovering = true;
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _sub;
  bool recovering = false;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

const _publicRoutes = {'/welcome', '/login', '/register', '/forgot-password'};

final routerProvider = Provider<GoRouter>((ref) {
  final db = ref.watch(supabaseProvider);
  final auth = _AuthListenable(db);
  ref.onDispose(auth.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      final loggedIn = db.auth.currentSession != null;
      final loc = state.matchedLocation;
      if (auth.recovering && loc != '/reset-password') return '/reset-password';
      if (loc == '/reset-password') return auth.recovering || loggedIn ? null : '/login';
      if (loc == '/') {
        if (loggedIn) return '/dashboard';
        return ref.read(preferencesProvider).onboardingSeen ? '/login' : '/welcome';
      }
      if (!loggedIn && !_publicRoutes.contains(loc)) return '/login';
      if (loggedIn && _publicRoutes.contains(loc)) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (_, _) => ResetPasswordScreen(onDone: () => auth.recovering = false),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, _) => const DashboardScreen()),
          GoRoute(path: '/companies', builder: (_, _) => const CompaniesScreen()),
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
          GoRoute(
            path: '/analyses',
            builder: (_, _) => const AnalysesScreen(),
            routes: [
              GoRoute(path: 'new', builder: (_, _) => const NewAnalysisScreen()),
              GoRoute(
                path: ':id',
                builder: (_, s) => AnalysisHubScreen(analysisId: s.pathParameters['id']!),
                routes: [
                  GoRoute(path: 'documents', builder: (_, s) => DocumentsScreen(analysisId: s.pathParameters['id']!)),
                  GoRoute(path: 'validate', builder: (_, s) => ValidationScreen(analysisId: s.pathParameters['id']!)),
                  GoRoute(path: 'results', builder: (_, s) => ResultsScreen(analysisId: s.pathParameters['id']!)),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
