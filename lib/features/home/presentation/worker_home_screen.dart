import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/data/auth_repository.dart';
import '../../instructions/presentation/instruction_list_screen.dart';
import '../../profile/domain/profile_model.dart';
import '../../projects/data/project_repository.dart';
import '../../shifts/data/shift_repository.dart';
import '../../shifts/presentation/week_timeline_view.dart';
import '../../work_photos/presentation/work_photo_list_screen.dart';

class WorkerHomeScreen extends ConsumerWidget {
  const WorkerHomeScreen({super.key, required this.profile});

  final ProfileModel profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final title = '${l10n.workerScheduleTitle} — ${profile.fullName}';
    // Safe: WorkerHomeScreen is only ever built for UserRole.worker, and
    // only UserRole.admin profiles have a null companyId.
    final companyId = profile.companyId!;
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
                    companyId: companyId,
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
                    companyId: companyId,
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
      // Note: RLS already restricts these results to this employee's own
      // shifts (shifts_employee_select_own) and their own visible projects —
      // no extra filtering needed.
      body: shiftsAsync.when(
        data: (shifts) {
          if (shifts.isEmpty) {
            return Center(child: Text(l10n.noShiftsYet));
          }

          return WeekTimelineView(
            shifts: shifts,
            projects: projectsAsync.valueOrNull ?? [],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
      ),
    );
  }
}
