// Opens every screen of the app with realistic data (long names, archived
// items, a 14-person team, events, requests...) at phone / tablet / desktop
// widths and in all four languages, and fails on any Flutter error —
// overflows, layout assertions, build exceptions. Also taps through the tabs
// and view switchers of the busiest screens.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_job_manager/core/supabase/supabase_providers.dart';
import 'package:simple_job_manager/core/theme/app_theme.dart';
import 'package:simple_job_manager/features/auth/presentation/login_screen.dart';
import 'package:simple_job_manager/features/auth/presentation/register_company_screen.dart';
import 'package:simple_job_manager/features/auth/presentation/set_new_password_screen.dart';
import 'package:simple_job_manager/features/calendar_events/data/calendar_event_repository.dart';
import 'package:simple_job_manager/features/calendar_events/domain/calendar_event_model.dart';
import 'package:simple_job_manager/features/calendar_events/presentation/event_form_screen.dart';
import 'package:simple_job_manager/features/employees/data/employee_repository.dart';
import 'package:simple_job_manager/features/employees/presentation/add_employee_screen.dart';
import 'package:simple_job_manager/features/employees/presentation/employee_detail_screen.dart';
import 'package:simple_job_manager/features/employees/presentation/employee_list_screen.dart';
import 'package:simple_job_manager/features/home/presentation/boss_home_screen.dart';
import 'package:simple_job_manager/features/home/presentation/notes_hub_screen.dart';
import 'package:simple_job_manager/features/home/presentation/worker_home_screen.dart';
import 'package:simple_job_manager/features/instructions/data/instruction_repository.dart';
import 'package:simple_job_manager/features/instructions/domain/instruction_model.dart';
import 'package:simple_job_manager/features/instructions/presentation/add_instruction_screen.dart';
import 'package:simple_job_manager/features/instructions/presentation/instruction_list_screen.dart';
import 'package:simple_job_manager/features/language/presentation/language_select_screen.dart';
import 'package:simple_job_manager/features/profile/data/profile_repository.dart';
import 'package:simple_job_manager/features/profile/domain/profile_model.dart';
import 'package:simple_job_manager/features/profile/presentation/my_account_screen.dart';
import 'package:simple_job_manager/features/projects/data/project_repository.dart';
import 'package:simple_job_manager/features/projects/domain/project_completion_notice_model.dart';
import 'package:simple_job_manager/features/projects/domain/project_member_model.dart';
import 'package:simple_job_manager/features/projects/domain/project_model.dart';
import 'package:simple_job_manager/features/projects/presentation/add_project_screen.dart';
import 'package:simple_job_manager/features/projects/presentation/project_detail_screen.dart';
import 'package:simple_job_manager/features/projects/presentation/project_list_screen.dart';
import 'package:simple_job_manager/features/projects/presentation/project_workspace_screen.dart';
import 'package:simple_job_manager/features/projects/presentation/worker_project_list_screen.dart';
import 'package:simple_job_manager/features/shifts/data/shift_change_request_repository.dart';
import 'package:simple_job_manager/features/shifts/data/shift_repository.dart';
import 'package:simple_job_manager/features/shifts/domain/shift_change_request_model.dart';
import 'package:simple_job_manager/features/shifts/domain/shift_model.dart';
import 'package:simple_job_manager/features/shifts/presentation/add_shift_screen.dart';
import 'package:simple_job_manager/features/shifts/presentation/general_calendar_screen.dart';
import 'package:simple_job_manager/features/shifts/presentation/worker_schedule_screen.dart';
import 'package:simple_job_manager/features/tasks/data/task_repository.dart';
import 'package:simple_job_manager/features/tasks/domain/project_task_model.dart';
import 'package:simple_job_manager/features/tasks/domain/task_assignment_model.dart';
import 'package:simple_job_manager/features/tasks/domain/task_completion_notice_model.dart';
import 'package:simple_job_manager/features/tasks/presentation/my_tasks_screen.dart';
import 'package:simple_job_manager/features/tasks/presentation/task_detail_screen.dart';
import 'package:simple_job_manager/features/tasks/presentation/task_form_screen.dart';
import 'package:simple_job_manager/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _longName = 'Maksymilian Przemysław Wiśniewski-Kowalczykiewicz';

DateTime _day(int offset) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).add(Duration(days: offset));
}

final _boss = ProfileModel(
  id: 'b1',
  companyId: 'c1',
  role: UserRole.boss,
  fullName: 'Jan Testowy',
  phone: '+48 600 100 200',
);
final _worker = ProfileModel(
  id: 'e0',
  companyId: 'c1',
  role: UserRole.worker,
  fullName: 'Anna Testowa',
);
final _people = [
  _worker,
  for (var i = 1; i < 14; i++)
    ProfileModel(
      id: 'e$i',
      companyId: 'c1',
      role: UserRole.worker,
      fullName: i == 3 ? _longName : 'Pracownik Numer$i',
      phone: i.isEven ? '+48 500 000 0$i' : null,
    ),
];

final _projects = [
  ProjectModel(
    id: 'p1',
    companyId: 'c1',
    name: 'Budowa domu',
    address: 'ul. Długa 12, Warszawa',
    description: 'Dom jednorodzinny, stan surowy zamknięty.',
    startDate: _day(-10),
    endDate: _day(60),
  ),
  ProjectModel(
    id: 'p2',
    companyId: 'c1',
    name:
        'Bardzo długa nazwa projektu remontowego ze sprzątaniem po budowie i wywozem',
    address:
        'ul. Bardzo Długiej Nazwy Ulicy Imienia Kogoś Ważnego 123/45, Kraków',
    startDate: _day(-3),
    endDate: _day(200),
  ),
  ProjectModel(
    id: 'p3',
    companyId: 'c1',
    name: 'Stary remont',
    startDate: _day(-90),
    endDate: _day(-40),
    archivedAt: _day(-30),
  ),
  ProjectModel(id: 'p4', companyId: 'c1', name: 'Bez dat'),
];

ProjectTaskModel _task(
  String id,
  String title, {
  String projectId = 'p1',
  int from = 0,
  int length = 3,
  bool hours = false,
  bool archived = false,
}) => ProjectTaskModel(
  id: id,
  companyId: 'c1',
  projectId: projectId,
  title: title,
  description: 'Opis zadania $title',
  startDate: _day(from),
  endDate: _day(from + length - 1),
  startTime: hours ? const TimeOfDay(hour: 8, minute: 0) : null,
  endTime: hours ? const TimeOfDay(hour: 16, minute: 0) : null,
  createdAt: _day(-5),
  archivedAt: archived ? _day(-1) : null,
);

final _tasks = [
  _task('t1', 'Wylewanie fundamentów', hours: true),
  _task(
    't2',
    'Bardzo długie zadanie obejmujące montaż zbrojenia, szalunków i dylatacji',
    from: 2,
    length: 9,
  ),
  _task('t3', 'Zarchiwizowane zadanie', from: -20, length: 5, archived: true),
  _task('t4', 'Zadanie w drugim projekcie', projectId: 'p2', from: 1),
];

ShiftModel _shift(String id, String employee, int dayOffset, {String? task}) =>
    ShiftModel(
      id: id,
      companyId: 'c1',
      employeeId: employee,
      projectId: 'p1',
      taskId: task,
      workDate: _day(dayOffset),
      startTime: const TimeOfDay(hour: 8, minute: 0),
      endTime: const TimeOfDay(hour: 16, minute: 30),
      notes: 'Notatka do zmiany',
    );

final _shifts = [
  for (var i = 0; i < 4; i++) _shift('s$i', 'e$i', 0, task: 't1'),
  for (var i = 0; i < 3; i++) _shift('s1$i', 'e$i', 1, task: 't2'),
  _shift('s20', 'e0', 3),
];

final _events = [
  CalendarEventModel(
    id: 'ev1',
    companyId: 'c1',
    title: 'Spotkanie z inwestorem w sprawie odbioru',
    notes: 'Zabrać dokumenty',
    startDate: _day(0),
    endDate: _day(0),
    startTime: const TimeOfDay(hour: 9, minute: 0),
    endTime: const TimeOfDay(hour: 10, minute: 30),
  ),
  CalendarEventModel(
    id: 'ev2',
    companyId: 'c1',
    title: 'Urlop',
    startDate: _day(1),
    endDate: _day(4),
  ),
];

List<Override> _overrides({required ProfileModel me}) => [
  supabaseClientProvider.overrideWithValue(
    SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    ),
  ),
  currentProfileProvider.overrideWith((ref) async => me),
  employeeListProvider.overrideWith((ref) async => _people),
  ownerListProvider.overrideWith((ref) async => [_boss]),
  projectListProvider.overrideWith((ref) async => _projects),
  projectMembersProvider.overrideWith(
    (ref) async => [
      for (var i = 0; i < 6; i++)
        ProjectMemberModel(projectId: 'p1', employeeId: 'e$i'),
      const ProjectMemberModel(projectId: 'p2', employeeId: 'e0'),
    ],
  ),
  projectCompletionNoticeListProvider.overrideWith(
    (ref) async => [
      ProjectCompletionNoticeModel(
        id: 'n1',
        projectId: 'p1',
        employeeId: 'e1',
        createdAt: _day(0),
      ),
    ],
  ),
  projectAttachmentsProvider.overrideWith((ref, id) async => []),
  projectTaskAttachmentsProvider.overrideWith((ref, id) async => []),
  taskListProvider.overrideWith((ref) async => _tasks),
  taskAssignmentsProvider.overrideWith(
    (ref) async => const [
      TaskAssignmentModel(taskId: 't1', employeeId: 'e0'),
      TaskAssignmentModel(taskId: 't1', employeeId: 'e1'),
      TaskAssignmentModel(taskId: 't2', employeeId: 'e2'),
    ],
  ),
  taskCompletionNoticeListProvider.overrideWith(
    (ref) async => [
      TaskCompletionNoticeModel(
        id: 'tn1',
        taskId: 't1',
        employeeId: 'e1',
        createdAt: _day(0),
      ),
    ],
  ),
  taskAttachmentsProvider.overrideWith((ref, id) async => []),
  shiftListProvider.overrideWith((ref) async => _shifts),
  shiftAttachmentsProvider.overrideWith((ref, id) async => []),
  calendarEventListProvider.overrideWith((ref) async => _events),
  instructionListProvider.overrideWith(
    (ref) async => [
      InstructionModel(
        id: 'i1',
        companyId: 'c1',
        projectId: 'p1',
        title: 'Instrukcja BHP na budowie',
        content: 'Kaski obowiązkowe. ' * 8,
        createdAt: _day(-2),
      ),
    ],
  ),
  instructionAttachmentsProvider.overrideWith((ref, id) async => []),
  shiftChangeRequestListProvider.overrideWith(
    (ref) async => [
      ShiftChangeRequestModel(
        id: 'r1',
        shiftId: 's0',
        employeeId: 'e1',
        message:
            'Czy mogę zmienić godziny na późniejsze, bo mam wizytę u lekarza?',
        createdAt: _day(0),
      ),
    ],
  ),
  myCompanyNameProvider.overrideWith((ref, id) async => 'Testowa Firma'),
];

class _Case {
  const _Case(this.name, this.build, {this.me, this.taps = const []});
  final String name;
  final Widget Function() build;
  final ProfileModel? me;

  /// Texts (Polish) tapped in order on the Polish run, checking for errors
  /// after each tap.
  final List<String> taps;
}

final _cases = <_Case>[
  _Case('language picker', () => const LanguageSelectScreen()),
  _Case('login', () => const LoginScreen()),
  _Case('register company', () => const RegisterCompanyScreen()),
  _Case('set new password', () => const SetNewPasswordScreen()),
  _Case('boss home', () => BossHomeScreen(profile: _boss)),
  _Case('team list', () => const EmployeeListScreen()),
  _Case(
    'team member details',
    () => EmployeeDetailScreen(member: _people[3], canRemove: true),
  ),
  _Case('add person', () => const AddEmployeeScreen()),
  _Case(
    'project list',
    () => const ProjectListScreen(companyId: 'c1'),
    taps: ['Archiwum (1)', 'Aktywne (3)'],
  ),
  _Case('add project', () => const AddProjectScreen(companyId: 'c1')),
  _Case(
    'edit project',
    () => AddProjectScreen(companyId: 'c1', existingProject: _projects[0]),
  ),
  _Case(
    'project workspace',
    () => ProjectWorkspaceScreen(companyId: 'c1', project: _projects[0]),
    taps: [
      'Grafik',
      'Tydzień',
      'Miesiąc',
      'Rok',
      'Dzień',
      'Zadania',
      'Archiwum (1)',
      'Aktywne (2)',
      'Zdjęcia i notatki',
      'Przegląd',
    ],
  ),
  _Case(
    'archived project workspace',
    () => ProjectWorkspaceScreen(companyId: 'c1', project: _projects[2]),
    taps: ['Zadania', 'Grafik'],
  ),
  _Case(
    'long-named project workspace',
    () => ProjectWorkspaceScreen(companyId: 'c1', project: _projects[1]),
    taps: ['Zadania', 'Grafik'],
  ),
  _Case(
    'task form (new)',
    () => TaskFormScreen(companyId: 'c1', project: _projects[0]),
  ),
  _Case(
    'task form (edit)',
    () => TaskFormScreen(
      companyId: 'c1',
      project: _projects[0],
      existingTask: _tasks[0],
    ),
  ),
  _Case(
    'task details (boss)',
    () => TaskDetailScreen(task: _tasks[0], isOwner: true),
  ),
  _Case(
    'task details (long title, boss)',
    () => TaskDetailScreen(task: _tasks[1], isOwner: true),
  ),
  _Case(
    'task details (archived, boss)',
    () => TaskDetailScreen(task: _tasks[2], isOwner: true),
  ),
  _Case(
    'task details (worker)',
    () => TaskDetailScreen(task: _tasks[0], isOwner: false),
    me: _worker,
  ),
  _Case('add shift', () => const AddShiftScreen(companyId: 'c1')),
  _Case(
    'add shift (project + task)',
    () => const AddShiftScreen(
      companyId: 'c1',
      preselectedProjectId: 'p1',
      preselectedTaskId: 't1',
    ),
  ),
  _Case(
    'edit shift',
    () => AddShiftScreen(companyId: 'c1', existingShift: _shifts.first),
  ),
  _Case(
    'notes and requests',
    () => const NotesHubScreen(companyId: 'c1'),
    taps: ['Prośby o zmianę', 'Instrukcje'],
  ),
  _Case(
    'add instruction',
    () => AddInstructionScreen(
      companyId: 'c1',
      projectId: 'p1',
      employeeOptions: _people,
    ),
  ),
  _Case(
    'general calendar',
    () => const GeneralCalendarScreen(companyId: 'c1'),
    taps: [
      'Tydzień',
      'Dzień',
      'Rok',
      'Miesiąc',
      'Oś projektów',
      'Dzień',
      'Tydzień',
      'Miesiąc',
      'Rok',
      'Kalendarz',
    ],
  ),
  _Case('new event', () => const EventFormScreen(companyId: 'c1')),
  _Case(
    'edit event',
    () => EventFormScreen(companyId: 'c1', existing: _events.first),
  ),
  _Case('my account', () => MyAccountScreen(profile: _boss)),
  _Case('worker home', () => WorkerHomeScreen(profile: _worker), me: _worker),
  _Case(
    'worker schedule',
    () => const WorkerScheduleScreen(),
    me: _worker,
    taps: ['Tydzień', 'Dzień', 'Rok', 'Miesiąc'],
  ),
  _Case('my tasks', () => const MyTasksScreen(), me: _worker),
  _Case(
    'worker projects',
    () => const WorkerProjectListScreen(companyId: 'c1'),
    me: _worker,
  ),
  _Case(
    'worker project details',
    () => ProjectDetailScreen(companyId: 'c1', project: _projects[0]),
    me: _worker,
  ),
  _Case(
    'worker instructions',
    () => const InstructionListScreen(companyId: 'c1', isOwner: false),
    me: _worker,
  ),
];

const _phone = Size(360, 740);
const _tablet = Size(768, 1024);
const _desktop = Size(1400, 900);

/// Pumps a few frames without waiting for endless animations to settle.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Every Flutter error raised, summarised as "message @ lib/file.dart:line".
final _collected = <String>[];

String _summarize(FlutterErrorDetails details) {
  final text = details.toString();
  final headline = details.exceptionAsString().split('\n').first;
  final where = RegExp(r'(lib/[\w/]+\.dart:\d+)').firstMatch(text)?.group(1);
  return where == null ? headline : '$headline @ $where';
}

List<String> _drain(WidgetTester tester) {
  // Exceptions the test binding itself caught (takeException) plus every one
  // our handler saw.
  while (tester.takeException() != null) {}
  final errors = {..._collected}.toList();
  _collected.clear();
  return errors;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'locale_code': 'pl'});
    _collected.clear();
  });

  Future<List<String>> run(
    WidgetTester tester,
    _Case c,
    Locale locale,
    Size size, {
    bool tap = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Installed inside the test body (the binding sets its own handler just
    // before the body runs) and put back before returning (the binding checks
    // that it is restored before the body ends).
    final previousHandler = FlutterError.onError;
    FlutterError.onError = (details) => _collected.add(_summarize(details));
    final errors = <String>[];
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(me: c.me ?? _boss),
          child: MaterialApp(
            theme: AppTheme.dark,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: c.build(),
          ),
        ),
      );
      await _settle(tester);
      errors.addAll(_drain(tester));

      if (tap) {
        for (final label in c.taps) {
          final target = find.text(label);
          if (target.evaluate().isEmpty) {
            errors.add('missing tap target "$label"');
            continue;
          }
          await tester.tap(target.first, warnIfMissed: false);
          await _settle(tester);
          errors.addAll(
            _drain(tester).map((e) => 'after tapping "$label": $e'),
          );
        }
      }
    } finally {
      FlutterError.onError = previousHandler;
    }
    return errors;
  }

  for (final c in _cases) {
    testWidgets('${c.name}: phone, all languages', (tester) async {
      final problems = <String>[];
      for (final locale in AppLocalizations.supportedLocales) {
        final errors = await run(tester, c, locale, _phone);
        problems.addAll(errors.map((e) => '[${locale.languageCode}] $e'));
      }
      expect(problems, isEmpty, reason: '${c.name}: ${problems.join('\n')}');
    });

    testWidgets('${c.name}: tablet and desktop + interactions', (tester) async {
      final problems = <String>[];
      for (final size in [_tablet, _desktop]) {
        final errors = await run(
          tester,
          c,
          const Locale('pl'),
          size,
          tap: true,
        );
        problems.addAll(errors.map((e) => '[${size.width.toInt()}px] $e'));
      }
      // The interactions again on a phone, where layouts are tightest.
      final phoneErrors = await run(
        tester,
        c,
        const Locale('pl'),
        _phone,
        tap: true,
      );
      problems.addAll(phoneErrors.map((e) => '[360px, taps] $e'));
      expect(problems, isEmpty, reason: '${c.name}: ${problems.join('\n')}');
    });
  }
}
