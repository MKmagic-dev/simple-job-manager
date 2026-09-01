import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/project_repository.dart';
import '../domain/project_model.dart';
import 'add_project_screen.dart';
import 'project_detail_screen.dart';

class ProjectListScreen extends ConsumerWidget {
  const ProjectListScreen({super.key, required this.companyId});

  final String companyId;

  Future<void> _deleteProject(
    BuildContext context,
    WidgetRef ref,
    ProjectModel project,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteProjectTooltip),
        content: Text(l10n.deleteProjectConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deleteButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(projectRepositoryProvider).deleteProject(project.id);
    ref.invalidate(projectListProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.projectDeletedSuccess)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final projectsAsync = ref.watch(projectListProvider);
    final noticesAsync = ref.watch(projectCompletionNoticeListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.projectsTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(projectListProvider.future),
        child: projectsAsync.when(
          data: (projects) {
            if (projects.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(child: Text(l10n.noProjectsYet)),
                  ),
                ),
              );
            }
            final notices = noticesAsync.valueOrNull ?? const [];
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: projects.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final project = projects[index];
                final noticeCount = notices
                    .where((n) => n.projectId == project.id)
                    .length;
                return ListTile(
                  leading: Badge(
                    label: Text('$noticeCount'),
                    isLabelVisible: noticeCount > 0,
                    child: const CircleAvatar(child: Icon(Icons.work_outline)),
                  ),
                  title: Text(project.name),
                  subtitle: project.address != null
                      ? Text(project.address!)
                      : null,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ProjectDetailScreen(
                          companyId: companyId,
                          project: project,
                          isOwner: true,
                        ),
                      ),
                    );
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: l10n.deleteProjectTooltip,
                    onPressed: () => _deleteProject(context, ref, project),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addProjectTooltip,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddProjectScreen(companyId: companyId),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
