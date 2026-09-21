import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_job_manager/features/projects/domain/project_model.dart';
import 'package:simple_job_manager/features/shifts/presentation/schedule_calendar.dart';
import 'package:simple_job_manager/l10n/generated/app_localizations.dart';

void main() {
  Widget host(
    List<ProjectModel> projects, {
    ValueChanged<ProjectModel>? onTap,
  }) {
    return MaterialApp(
      locale: const Locale('pl'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 900,
          height: 700,
          child: ScheduleCalendar(
            shifts: const [],
            projects: projects,
            projectsOnly: true,
            isOwner: true,
            onProjectTap: onTap,
          ),
        ),
      ),
    );
  }

  ProjectModel runningProject() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return ProjectModel(
      id: 'p1',
      companyId: 'c1',
      name: 'Budowa domu',
      startDate: today.subtract(const Duration(days: 30)),
      endDate: today.add(const Duration(days: 30)),
    );
  }

  testWidgets('week view draws running projects as bars without errors', (
    tester,
  ) async {
    ProjectModel? tapped;
    await tester.pumpWidget(host([runningProject()], onTap: (p) => tapped = p));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Budowa domu'), findsOneWidget);

    await tester.tap(find.text('Budowa domu'));
    expect(tapped?.id, 'p1');
  });

  testWidgets('month view lists running projects without errors', (
    tester,
  ) async {
    await tester.pumpWidget(host([runningProject()]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Miesiąc'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Budowa domu'), findsWidgets);
  });

  testWidgets('shows an empty state when no project runs in the period', (
    tester,
  ) async {
    await tester.pumpWidget(host(const []));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Brak projektów w tym okresie.'), findsOneWidget);
  });
}
