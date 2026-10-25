import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_job_manager/core/errors/friendly_error.dart';
import 'package:simple_job_manager/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<AppLocalizations> _l10n(String code) =>
    AppLocalizations.delegate.load(Locale(code));

void main() {
  test(
    'network failures become one plain sentence, in every language',
    () async {
      final errors = <Object>[
        AuthRetryableFetchException(
          message: 'ClientException: NetworkError when attempting to fetch',
        ),
        Exception('SocketException: Failed host lookup'),
        'XMLHttpRequest error.',
      ];
      for (final code in ['pl', 'en', 'es', 'fr']) {
        final l10n = await _l10n(code);
        for (final error in errors) {
          final text = friendlyErrorText(l10n, error);
          expect(text, l10n.networkError, reason: '$code / $error');
          expect(text.toLowerCase(), isNot(contains('exception')));
        }
      }
    },
  );

  test('database refusals are explained, not dumped', () async {
    final l10n = await _l10n('pl');
    expect(
      friendlyErrorText(
        l10n,
        const PostgrestException(
          message: 'new row violates RLS',
          code: '42501',
        ),
      ),
      'Nie masz uprawnień do tej czynności.',
    );
    expect(
      friendlyErrorText(
        l10n,
        const PostgrestException(message: 'duplicate key', code: '23505'),
      ),
      'Taki wpis już istnieje.',
    );
    expect(
      friendlyErrorText(
        l10n,
        const PostgrestException(message: 'something odd', code: 'XX000'),
      ),
      l10n.genericError,
    );
  });

  test('login errors and our own readable messages pass through', () async {
    final l10n = await _l10n('pl');
    expect(
      friendlyErrorText(l10n, const AuthException('Invalid login credentials')),
      l10n.invalidCredentialsError,
    );
    expect(
      friendlyErrorText(
        l10n,
        const AuthException('Password should be at least 6 characters'),
      ),
      'Password should be at least 6 characters',
    );
    // The register-company function's own sentence is shown as written.
    expect(
      friendlyErrorText(l10n, Exception('Email already registered.')),
      'Email already registered.',
    );
    // A programming error never leaks a stack-trace-looking message.
    expect(friendlyErrorText(l10n, StateError('boom')), l10n.genericError);
  });
}
