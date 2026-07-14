import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/startup/presentation/app_startup_gate.dart';

/// Single entry route for now: [AppStartupGate] decides internally whether
/// to show the language picker, the login screen, or the boss/worker home,
/// based on locale + auth + profile state. As features grow, add nested
/// routes here (e.g. /boss/projects/:id).
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const AppStartupGate(),
      ),
    ],
  );
});
