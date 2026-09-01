import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../admin/presentation/admin_home_screen.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/login_screen.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/profile_model.dart';
import 'boss_home_screen.dart';
import 'worker_home_screen.dart';

/// Root widget that decides what to show based on auth + profile state:
/// - no session            -> [LoginScreen]
/// - session, no profile   -> loading (profile row not created yet)
/// - session, boss profile -> [BossHomeScreen]
/// - session, worker profile -> [WorkerHomeScreen]
/// - session, admin profile -> [AdminHomeScreen]
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (state) {
        final session =
            state.session ?? Supabase.instance.client.auth.currentSession;
        if (session == null) return const LoginScreen();
        return const _ProfileGate();
      },
      loading: () => const _LoadingScreen(),
      error: (error, stackTrace) => const LoginScreen(),
    );
  }
}

class _ProfileGate extends ConsumerWidget {
  const _ProfileGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return _LoadingScreen(
            message: AppLocalizations.of(context)!.preparingAccount,
          );
        }
        return switch (profile.role) {
          UserRole.boss => BossHomeScreen(profile: profile),
          UserRole.worker => WorkerHomeScreen(profile: profile),
          UserRole.admin => AdminHomeScreen(profile: profile),
        };
      },
      loading: () => const _LoadingScreen(),
      error: (error, stackTrace) => _ErrorScreen(message: error.toString()),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends ConsumerWidget {
  const _ErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                child: Text(AppLocalizations.of(context)!.signOutButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
