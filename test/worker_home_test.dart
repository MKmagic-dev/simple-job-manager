import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_job_manager/features/home/presentation/worker_home_screen.dart';
import 'package:simple_job_manager/features/profile/domain/profile_model.dart';
import 'package:simple_job_manager/features/projects/data/project_repository.dart';
import 'package:simple_job_manager/features/projects/domain/project_model.dart';
import 'package:simple_job_manager/features/shifts/data/shift_repository.dart';
import 'package:simple_job_manager/features/shifts/domain/shift_model.dart';
import 'package:simple_job_manager/features/tasks/data/task_repository.dart';
import 'package:simple_job_manager/features/tasks/domain/project_task_model.dart';
import 'package:simple_job_manager/l10n/generated/app_localizations.dart';

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

Widget _host({required bool withShiftToday}) {
  final today = _today();
  final project = ProjectModel(
    id: 'p1',
    companyId: 'c1',
    name: 'Budowa domu',
    startDate: today.subtract(const Duration(days: 5)),
    endDate: today.add(const Duration(days: 30)),
  );
  final task = ProjectTaskModel(
    id: 't1',
    companyId: 'c1',
    projectId: 'p1',
    title: 'Wylewanie fundamentów',
    startDate: today,
    endDate: today.add(const Duration(days: 3)),
    createdAt: today,
  );
  final shift = ShiftModel(
    id: 's1',
    companyId: 'c1',
    employeeId: 'e1',
    projectId: 'p1',
    taskId: 't1',
    workDate: withShiftToday ? today : today.add(const Duration(days: 2)),
    startTime: const TimeOfDay(hour: 8, minute: 0),
    endTime: const TimeOfDay(hour: 16, minute: 0),
  );

  return ProviderScope(
    overrides: [
      shiftListProvider.overrideWith((ref) async => [shift]),
      projectListProvider.overrideWith((ref) async => [project]),
      taskListProvider.overrideWith((ref) async => [task]),
    ],
    child: MaterialApp(
      locale: const Locale('pl'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const WorkerHomeScreen(
        profile: ProfileModel(
          id: 'e1',
          companyId: 'c1',
          role: UserRole.worker,
          fullName: 'Anna Testowa',
        ),
      ),
    ),
  );
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('phone: greeting, today card and the four sections', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_host(withShiftToday: true));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Witaj, Anna'), findsOneWidget);
    expect(find.text('DZIŚ'), findsOneWidget);
    expect(find.text('08:00 – 16:00'), findsOneWidget);
    expect(find.text('Wylewanie fundamentów'), findsOneWidget);
    for (final label in [
      'Mój grafik',
      'Moje zadania',
      'Projekty',
      'Instrukcje',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    // Sections open as full pages on a phone.
    await tester.tap(find.text('Projekty'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Budowa domu'), findsOneWidget);
  });

  testWidgets('shows the next shift when today is free', (tester) async {
    _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_host(withShiftToday: false));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('NAJBLIŻSZA ZMIANA'), findsOneWidget);
    expect(find.text('08:00 – 16:00'), findsOneWidget);
  });

  testWidgets('desktop: sidebar stays while sections swap in the pane', (
    tester,
  ) async {
    _setSize(tester, const Size(1400, 900));
    await tester.pumpWidget(_host(withShiftToday: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    for (final label in ['Mój grafik', 'Moje zadania', 'Projekty']) {
      // The label is in the sidebar and on the overview card; the sidebar
      // one is always the first.
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: label);
    }

    await tester.tap(find.text('Strona główna').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Witaj, Anna'), findsOneWidget);
  });
}
