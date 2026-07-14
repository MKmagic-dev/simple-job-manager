import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/data/auth_repository.dart';
import '../../instructions/presentation/instruction_list_screen.dart';
import '../../profile/domain/profile_model.dart';
import '../../projects/data/project_repository.dart';
import '../../shifts/data/shift_repository.dart';
import '../../work_photos/presentation/work_photo_list_screen.dart';

class WorkerHomeScreen extends ConsumerWidget {
  const WorkerHomeScreen({super.key, required this.profile});

  final ProfileModel profile;

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final title = '${l10n.workerScheduleTitle} — ${profile.fullName}';
    final shiftsAsync = ref.watch(shiftListProvider);
    final projectsAsync = ref.watch(projectListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: l10n.instructionsTitle,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => InstructionListScreen(
                    companyId: profile.companyId,
                    isOwner: false,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.photo_camera_back_outlined),
            tooltip: l10n.workPhotosTitle,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => WorkPhotoListScreen(
                    companyId: profile.companyId,
                    employeeId: profile.id,
                    isOwner: false,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.signOutTooltip,
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(shiftListProvider.future),
        child: shiftsAsync.when(
          // Note: RLS already restricts these results to this employee's own
          // shifts (shifts_employee_select_own) — no extra filtering needed.
          data: (shifts) {
            if (shifts.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(child: Text(l10n.noShiftsYet)),
                  ),
                ),
              );
            }

            final projectNames = {
              for (final project in projectsAsync.valueOrNull ?? []) project.id: project.name,
            };

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: shifts.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final shift = shifts[index];
                final projectName = shift.projectId != null ? projectNames[shift.projectId] : null;
                return ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: Text(
                    '${_formatDate(shift.workDate)} · ${_formatTime(shift.startTime)}–${_formatTime(shift.endTime)}',
                  ),
                  subtitle: projectName != null ? Text(projectName) : null,
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
        ),
      ),
    );
  }
}
