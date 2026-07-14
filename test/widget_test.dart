import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:simple_job_manager/core/supabase/supabase_providers.dart';
import 'package:simple_job_manager/features/auth/presentation/login_screen.dart';
import 'package:simple_job_manager/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('Login screen shows email/password fields and submit button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Avoid touching the real Supabase singleton in widget tests.
          supabaseClientProvider.overrideWithValue(
            SupabaseClient(
              'https://example.supabase.co',
              'test-anon-key',
              authOptions: const AuthClientOptions(autoRefreshToken: false),
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: LoginScreen(),
        ),
      ),
    );

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);

    // Submitting with empty fields should show validation errors instead of
    // attempting a network call.
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Please enter your email address.'), findsOneWidget);
    expect(find.text('Please enter your password.'), findsOneWidget);
  });
}
