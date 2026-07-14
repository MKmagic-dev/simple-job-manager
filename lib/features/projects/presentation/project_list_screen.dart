import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/project_repository.dart';
import 'add_project_screen.dart';

class ProjectListScreen extends ConsumerWidget {
  const ProjectListScreen({super.key, required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final projectsAsync = ref.watch(projectListProvider);

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
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(child: Text(l10n.noProjectsYet)),
                  ),
                ),
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: projects.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final project = projects[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.work_outline)),
                  title: Text(project.name),
                  subtitle: project.address != null ? Text(project.address!) : null,
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
            MaterialPageRoute(builder: (context) => AddProjectScreen(companyId: companyId)),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
