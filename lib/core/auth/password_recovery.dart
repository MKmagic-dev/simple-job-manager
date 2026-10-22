import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app was opened from a "reset your password" email link.
/// Must be read from the URL in `main()` *before* Supabase initializes —
/// the SDK consumes and cleans the link's `code` / `type=recovery` params.
bool launchedFromRecoveryLink = false;

/// Call at the very start of `main()`.
void detectRecoveryLaunch() {
  if (!kIsWeb) return;
  final uri = Uri.base;
  launchedFromRecoveryLink =
      uri.queryParameters.containsKey('code') ||
      uri.fragment.contains('type=recovery') ||
      uri.queryParameters['type'] == 'recovery';
}

/// True while the user arrived from a reset link and still has to choose a
/// new password; the auth gate shows the set-new-password screen meanwhile.
final passwordRecoveryPendingProvider = StateProvider<bool>(
  (ref) => launchedFromRecoveryLink,
);

/// Where the reset email's link should send the user back to: this web app.
/// On web that's the page the app is served from; elsewhere there's no
/// deep-link setup yet, so Supabase's configured Site URL (the web app) is
/// used.
String? passwordResetRedirectUrl() {
  if (!kIsWeb) return null;
  return '${Uri.base.origin}${Uri.base.path}';
}
