import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_job_manager/core/supabase/supabase_providers.dart';
import 'package:simple_job_manager/features/employees/presentation/add_employee_screen.dart';
import 'package:simple_job_manager/features/projects/data/project_repository.dart';
import 'package:simple_job_manager/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('the add-person form offers an optional profile photo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseClientProvider.overrideWithValue(
            SupabaseClient(
              'https://example.supabase.co',
              'test-anon-key',
              authOptions: const AuthClientOptions(autoRefreshToken: false),
            ),
          ),
          projectListProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AddEmployeeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Zdjęcie profilowe (opcjonalnie)'), findsOneWidget);
    expect(find.text('Dodaj zdjęcie'), findsOneWidget);
    // Nothing is chosen yet, so there's nothing to take back out.
    expect(find.byTooltip('Usuń wybrane zdjęcie'), findsNothing);
  });
}
