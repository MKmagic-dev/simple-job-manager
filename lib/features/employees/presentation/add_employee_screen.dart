import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../profile/data/profile_repository.dart';
import '../../projects/data/project_repository.dart';
import '../../shifts/presentation/add_shift_screen.dart';
import 'add_employee_controller.dart';

/// Adds a person to the team: their details, a temporary password (with a
/// one-tap generator), and optionally a project — picking one jumps straight
/// into scheduling their first shift on it.
class AddEmployeeScreen extends ConsumerStatefulWidget {
  const AddEmployeeScreen({super.key});

  @override
  ConsumerState<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends ConsumerState<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _assignProjectId;

  /// A random 10-character password without look-alike characters
  /// (0/O, 1/l/I), easy to read out or type from a phone screen.
  String _generatePassword() {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(10, (_) => chars[random.nextInt(chars.length)]).join();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final newEmployeeId = await ref
        .read(addEmployeeControllerProvider.notifier)
        .submit(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _fullNameController.text.trim(),
          phone: _phoneController.text.trim(),
        );

    if (newEmployeeId != null && mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.employeeAddedSuccess)));

      if (_assignProjectId == null) {
        Navigator.of(context).pop();
        return;
      }

      // They picked a project to assign the new employee to — jump
      // straight into scheduling their first shift on it instead of just
      // closing the form.
      final companyId = ref.read(currentProfileProvider).valueOrNull?.companyId;
      if (companyId == null) {
        Navigator.of(context).pop();
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => AddShiftScreen(
            companyId: companyId,
            preselectedEmployeeId: newEmployeeId,
            preselectedProjectId: _assignProjectId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final submitState = ref.watch(addEmployeeControllerProvider);
    final isLoading = submitState.isLoading;
    final projectsAsync = ref
        .watch(projectListProvider)
        .whenData(
          (all) => [
            for (final p in all)
              if (!p.isArchived) p,
          ],
        );

    ref.listen<AsyncValue<void>>(addEmployeeControllerProvider, (
      previous,
      next,
    ) {
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(error.toString())));
        },
      );
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addEmployeeTitle)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FormCard(
                      icon: Icons.badge_outlined,
                      title: l10n.personDetailsSection,
                      children: [
                        TextFormField(
                          controller: _fullNameController,
                          enabled: !isLoading,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: l10n.fullNameLabel,
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.fullNameRequiredError;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          enabled: !isLoading,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: l10n.emailLabel,
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            final trimmed = value?.trim() ?? '';
                            if (trimmed.isEmpty) {
                              return l10n.emailRequiredError;
                            }
                            if (!trimmed.contains('@')) {
                              return l10n.emailInvalidError;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          enabled: !isLoading,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: l10n.phoneLabel,
                            prefixIcon: const Icon(Icons.phone_outlined),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FormCard(
                      icon: Icons.lock_outline,
                      title: l10n.signInAccessSection,
                      children: [
                        TextFormField(
                          controller: _passwordController,
                          enabled: !isLoading,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: l10n.temporaryPasswordLabel,
                            helperText: l10n.temporaryPasswordHelperText,
                            helperMaxLines: 2,
                            prefixIcon: const Icon(Icons.key_outlined),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.autorenew),
                                  tooltip: l10n.generatePasswordTooltip,
                                  onPressed: isLoading
                                      ? null
                                      : () => setState(() {
                                          _passwordController.text =
                                              _generatePassword();
                                          _obscurePassword = false;
                                        }),
                                ),
                                IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.passwordRequiredError;
                            }
                            if (value.length < 6) {
                              return l10n.passwordTooShortError;
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _submit(),
                        ),
                      ],
                    ),
                    projectsAsync.when(
                      data: (projects) => projects.isEmpty
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: _FormCard(
                                icon: Icons.work_outline,
                                title: l10n.projectsTitle,
                                children: [
                                  DropdownButtonFormField<String?>(
                                    initialValue: _assignProjectId,
                                    decoration: InputDecoration(
                                      labelText:
                                          l10n.assignToProjectOptionalLabel,
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: null,
                                        child: Text(l10n.noProjectOption),
                                      ),
                                      for (final project in projects)
                                        DropdownMenuItem(
                                          value: project.id,
                                          child: Text(project.name),
                                        ),
                                    ],
                                    onChanged: isLoading
                                        ? null
                                        : (value) => setState(
                                            () => _assignProjectId = value,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                      loading: () => const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: LinearProgressIndicator(),
                      ),
                      error: (error, stackTrace) => Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(l10n.couldNotLoadProjectsError),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: isLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.saveButton),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled, bordered section of the form.
class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
