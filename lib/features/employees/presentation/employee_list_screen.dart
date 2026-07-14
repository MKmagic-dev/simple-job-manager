import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/employee_repository.dart';
import 'add_employee_screen.dart';

class EmployeeListScreen extends ConsumerWidget {
  const EmployeeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final employeesAsync = ref.watch(employeeListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.employeesTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(employeeListProvider.future),
        child: employeesAsync.when(
          data: (employees) {
            if (employees.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(child: Text(l10n.noEmployeesYet)),
                  ),
                ),
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: employees.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final employee = employees[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                  title: Text(employee.fullName),
                  subtitle: employee.phone != null ? Text(employee.phone!) : null,
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addEmployeeTooltip,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddEmployeeScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
