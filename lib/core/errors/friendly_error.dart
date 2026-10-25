import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/generated/app_localizations.dart';

/// Turns whatever went wrong into a sentence a person can act on, in their
/// language — instead of showing "ClientException: NetworkError when
/// attempting to fetch resource" or a Postgres error code.
String friendlyErrorText(AppLocalizations l10n, Object error) {
  final raw = error.toString();
  final lower = raw.toLowerCase();

  // The server couldn't be reached at all (offline, paused project, DNS...).
  if (error is AuthRetryableFetchException ||
      lower.contains('networkerror') ||
      lower.contains('failed host lookup') ||
      lower.contains('socketexception') ||
      lower.contains('clientexception') ||
      lower.contains('xmlhttprequest') ||
      lower.contains('connection refused') ||
      lower.contains('connection closed')) {
    return l10n.networkError;
  }

  if (error is PostgrestException) {
    return switch (error.code) {
      '42501' => l10n.permissionDeniedError,
      '23505' => l10n.duplicateEntryError,
      _ => l10n.genericError,
    };
  }

  if (error is StorageException) {
    final status = error.statusCode;
    if (status == '403' || status == '401') return l10n.permissionDeniedError;
    return l10n.genericError;
  }

  if (error is AuthException) {
    if (error.message == 'Invalid login credentials') {
      return l10n.invalidCredentialsError;
    }
    // Supabase's own sentence (e.g. "Password should be at least 6 characters").
    return error.message;
  }

  // Deliberate `throw Exception('Readable sentence')` from our own code, such
  // as the message the register-company function sends back.
  if (error is Exception && raw.startsWith('Exception: ')) {
    return raw.substring('Exception: '.length);
  }

  return l10n.genericError;
}

/// [friendlyErrorText] for use inside widgets.
String friendlyError(BuildContext context, Object error) =>
    friendlyErrorText(AppLocalizations.of(context)!, error);
