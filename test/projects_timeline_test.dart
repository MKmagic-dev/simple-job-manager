import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_job_manager/features/projects/domain/project_model.dart';
import 'package:simple_job_manager/features/projects/presentation/projects_timeline.dart';
import 'package:simple_job_manager/l10n/generated/app_localizations.dart';

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

ProjectModel _project(String name, {int startOffset = -10, int length = 40}) {
  final start = _today().add(Duration(days: startOffset));
  return ProjectModel(
    id: name,
    companyId: 'c1',
    name: name,
    startDate: start,
    endDate: start.add(Duration(days: length)),
  );
}

Widget _host(List<ProjectModel> projects, {ValueChanged<ProjectModel>? onTap}) {
  return MaterialApp(
    locale: const Locale('pl'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ProjectsTimeline(projects: projects, onProjectTap: onTap ?? (_) {}),
    ),
  );
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('shows running projects in every view without errors', (
    tester,
  ) async {
    _setSize(tester, const Size(1000, 700));
    await tester.pumpWidget(
      _host([_project('Budowa domu'), _project('Panele', startOffset: -3)]),
    );
    await tester.pumpAndSettle();

    for (final label in ['Tydzień', 'Miesiąc', 'Rok', 'Dzień']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'view $label');
      expect(find.text('Budowa domu'), findsWidgets, reason: 'view $label');
      expect(find.text('Panele'), findsWidgets, reason: 'view $label');
    }
  });

  testWidgets('stays usable with 40 projects on a phone-sized screen', (
    tester,
  ) async {
    _setSize(tester, const Size(360, 800));
    final projects = [
      for (var i = 0; i < 40; i++)
        _project('Projekt ${i + 1}', startOffset: -20 + i * 3, length: 25),
    ];
    await tester.pumpWidget(_host(projects));
    await tester.pumpAndSettle();

    for (final label in ['Miesiąc', 'Rok', 'Tydzień']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'view $label');
    }

    // Rows scroll: the last running project isn't laid out until scrolled to.
    await tester.tap(find.text('Rok'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -3000),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('search narrows the rows and tapping a project reports it', (
    tester,
  ) async {
    _setSize(tester, const Size(1000, 700));
    ProjectModel? tapped;
    await tester.pumpWidget(
      _host([
        _project('Budowa domu'),
        _project('Panele'),
      ], onTap: (p) => tapped = p),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'pan');
    await tester.pumpAndSettle();
    expect(find.text('Budowa domu'), findsNothing);
    expect(find.text('Panele'), findsWidgets);

    await tester.tap(find.text('Panele').first);
    expect(tapped?.name, 'Panele');
  });

  testWidgets('hides projects outside the period unless the filter is off', (
    tester,
  ) async {
    _setSize(tester, const Size(1000, 700));
    await tester.pumpWidget(
      _host([_project('Stary', startOffset: -400, length: 30)]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Brak projektów w tym okresie.'), findsOneWidget);

    await tester.tap(find.text('Tylko aktywne w tym okresie'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Stary'), findsWidgets);
  });
}
