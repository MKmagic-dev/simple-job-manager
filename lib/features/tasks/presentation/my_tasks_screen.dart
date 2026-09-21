import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../projects/data/project_repository.dart';
import '../../shifts/presentation/calendar_shared.dart';
import '../data/task_repository.dart';
import '../domain/project_task_model.dart';
import 'task_detail_screen.dart';

/// The employee's list of tasks assigned to them (RLS already limits the
/// task list to those), newest work first: in progress, then upcoming, then
/// finished. Tapping one opens it, where they can add photos or PDFs.
class MyTasksScreen extends ConsumerWidget {
  const MyTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final tasksAsync = ref.watch(taskListProvider);
    final projects = ref.watch(projectListProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myTasksTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(taskListProvider);
          await ref.read(taskListProvider.future);
        },
        child: tasksAsync.when(
          data: (tasks) {
            if (tasks.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(child: Text(l10n.noMyTasksYet)),
                  ),
                ),
              );
            }

            final today = DateTime.now();
            int rank(ProjectTaskModel task) => switch (task.phaseOn(today)) {
              TaskPhase.active => 0,
              TaskPhase.upcoming => 1,
              TaskPhase.done => 2,
            };
            final sorted = [...tasks]
              ..sort((a, b) {
                final byPhase = rank(a).compareTo(rank(b));
                return byPhase != 0
                    ? byPhase
                    : a.startDate.compareTo(b.startDate);
              });
            final dateFormat = DateFormat.MMMd(locale);

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: sorted.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final task = sorted[index];
                    final project = projects
                        .where((p) => p.id == task.projectId)
                        .firstOrNull;
                    final phase = task.phaseOn(today);
                    final (phaseLabel, phaseColor) = switch (phase) {
                      TaskPhase.active => (
                        l10n.taskPhaseActive,
                        const Color(0xFF4C8B14),
                      ),
                      TaskPhase.upcoming => (
                        l10n.taskPhaseUpcoming,
                        const Color(0xFF1E88E5),
                      ),
                      TaskPhase.done => (l10n.taskPhaseDone, Colors.grey),
                    };
                    final dateLabel = task.startDate == task.endDate
                        ? dateFormat.format(task.startDate)
                        : '${dateFormat.format(task.startDate)} – ${dateFormat.format(task.endDate)}';

                    return Material(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                TaskDetailScreen(task: task, isOwner: false),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (project != null) ...[
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: colorForProject(project),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        project.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelMedium,
                                      ),
                                    ),
                                  ] else
                                    const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: phaseColor.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      phaseLabel,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: phaseColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                task.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$dateLabel · ${task.hasHours ? '${formatTime(task.startTime!)}–${formatTime(task.endTime!)}' : l10n.taskWholeDayLabel}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
        ),
      ),
    );
  }
}
