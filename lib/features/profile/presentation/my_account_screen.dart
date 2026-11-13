import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/files/image_bytes.dart';
import '../../../core/files/photo_cropper.dart';
import '../../../core/locale/app_languages.dart';
import '../../../core/locale/locale_controller.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/account_deletion_repository.dart';
import '../data/profile_repository.dart';
import '../domain/profile_model.dart';
import 'change_password_controller.dart';
import 'update_profile_controller.dart';

class MyAccountScreen extends ConsumerStatefulWidget {
  const MyAccountScreen({super.key, required this.profile});

  final ProfileModel profile;

  @override
  ConsumerState<MyAccountScreen> createState() => _MyAccountScreenState();
}

class _MyAccountScreenState extends ConsumerState<MyAccountScreen> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _imagePicker = ImagePicker();

  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.profile.fullName);
    _phoneController = TextEditingController(text: widget.profile.phone ?? '');
    _avatarUrl = widget.profile.avatarUrl;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final l10n = AppLocalizations.of(context)!;
    final xFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (xFile == null) return;
    final bytes = await xFile.readAsBytes();
    if (!mounted) return;

    // Frame the photo in a round guide before it becomes the avatar.
    final framed = await cropPhoto(
      context,
      bytes,
      aspectRatio: 1,
      circle: true,
    );
    if (framed == null) return;

    final success = await ref
        .read(updateProfileControllerProvider.notifier)
        .uploadAvatar(bytes: framed, fileExtension: 'png');

    // The new URL reaches _avatarUrl via the currentProfileProvider listener
    // below, once the controller's own invalidate() call lands.
    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.avatarUpdatedSuccess)));
    }
  }

  /// Frames the photo that is already set (without picking a new one).
  Future<void> _adjustAvatar() async {
    final l10n = AppLocalizations.of(context)!;
    final url = _avatarUrl;
    if (url == null) return;
    final Uint8List bytes;
    try {
      bytes = await fetchImageBytes(url);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyErrorText(l10n, error))));
      }
      return;
    }
    if (!mounted) return;
    final framed = await cropPhoto(
      context,
      bytes,
      aspectRatio: 1,
      circle: true,
    );
    if (framed == null) return;

    final success = await ref
        .read(updateProfileControllerProvider.notifier)
        .uploadAvatar(bytes: framed, fileExtension: 'png');
    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.avatarUpdatedSuccess)));
    }
  }

  Future<void> _saveDetails() async {
    final l10n = AppLocalizations.of(context)!;
    final success = await ref
        .read(updateProfileControllerProvider.notifier)
        .saveDetails(
          fullName: _fullNameController.text.trim(),
          phone: _phoneController.text.trim(),
        );
    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileUpdatedSuccess)));
    }
  }

  /// Owner only. The company and every login in it are deleted, but only
  /// after the owner types a one-time code that is e-mailed to them.
  Future<void> _startCompanyDeletion() async {
    final l10n = AppLocalizations.of(context)!;
    final repository = ref.read(accountDeletionRepositoryProvider);

    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteCompanyTitle),
        content: Text(l10n.deleteCompanyWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deleteCompanySendCodeButton),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    try {
      await repository.sendCode();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(context, error))));
      }
      return;
    }
    if (!mounted) return;

    final codeController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteCompanyCodeTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.deleteCompanyCodeSent),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: l10n.deleteCompanyCodeLabel,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deleteCompanyConfirmButton),
          ),
        ],
      ),
    );
    final code = codeController.text.trim();
    codeController.dispose();
    if (confirmed != true || !mounted) return;

    try {
      await repository.confirmCode(code);
      await repository.deleteCompany();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(context, error))));
      }
    }
  }

  Future<void> _changePassword() async {
    final l10n = AppLocalizations.of(context)!;
    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.passwordTooShortError)));
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.passwordsDoNotMatchError)));
      return;
    }

    final success = await ref
        .read(changePasswordControllerProvider.notifier)
        .submit(_newPasswordController.text);
    if (success && mounted) {
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.passwordChangedSuccess)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profileState = ref.watch(updateProfileControllerProvider);
    final passwordState = ref.watch(changePasswordControllerProvider);
    final companyId = widget.profile.companyId;
    final companyNameAsync = companyId != null
        ? ref.watch(myCompanyNameProvider(companyId))
        : null;

    ref.listen<AsyncValue<void>>(updateProfileControllerProvider, (
      previous,
      next,
    ) {
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(friendlyError(context, error))),
            );
        },
      );
    });
    ref.listen<AsyncValue<void>>(changePasswordControllerProvider, (
      previous,
      next,
    ) {
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(friendlyError(context, error))),
            );
        },
      );
    });

    // Keep the on-screen avatar in sync once the profile refetch lands.
    ref.listen<AsyncValue<ProfileModel?>>(currentProfileProvider, (
      previous,
      next,
    ) {
      final url = next.valueOrNull?.avatarUrl;
      if (url != null && url != _avatarUrl) {
        setState(() => _avatarUrl = url);
      }
    });

    // Only an administrator edits people's details — including their own;
    // an employee's name, phone and photo are set by their admin.
    final canEditProfile = widget.profile.role != UserRole.worker;
    final isProfileLoading = profileState.isLoading;
    final isPasswordLoading = passwordState.isLoading;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myAccountTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: isProfileLoading || !canEditProfile
                      ? null
                      : _pickAndUploadAvatar,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundImage: _avatarUrl != null
                            ? NetworkImage(_avatarUrl!)
                            : null,
                        child: _avatarUrl == null
                            ? const Icon(Icons.person_outline, size: 40)
                            : null,
                      ),
                      if (canEditProfile)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            child: Icon(
                              Icons.camera_alt_outlined,
                              size: 18,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  canEditProfile
                      ? l10n.changePhotoTooltip
                      : l10n.profileManagedByAdminNote,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (canEditProfile && _avatarUrl != null)
                Center(
                  child: TextButton.icon(
                    onPressed: isProfileLoading ? null : _adjustAvatar,
                    icon: const Icon(Icons.crop, size: 18),
                    label: Text(l10n.cropPhotoAdjustButton),
                  ),
                ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _fullNameController,
                enabled: !isProfileLoading,
                readOnly: !canEditProfile,
                decoration: InputDecoration(labelText: l10n.fullNameLabel),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                enabled: !isProfileLoading,
                readOnly: !canEditProfile,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: l10n.phoneLabel),
              ),
              if (companyNameAsync != null) ...[
                const SizedBox(height: 16),
                TextFormField(
                  enabled: false,
                  decoration: InputDecoration(labelText: l10n.companyNameLabel),
                  controller: TextEditingController(
                    text: companyNameAsync.valueOrNull ?? '',
                  ),
                ),
              ],
              if (canEditProfile) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: isProfileLoading ? null : _saveDetails,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: isProfileLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.saveChangesButton),
                ),
              ],
              if (widget.profile.role == UserRole.boss) ...[
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  l10n.deleteCompanyTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.deleteCompanyWarning,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _startCompanyDeletion,
                  icon: Icon(
                    Icons.delete_forever_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  label: Text(
                    l10n.deleteCompanyButton,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                l10n.appLanguageLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue:
                    ref
                        .watch(localeControllerProvider)
                        .valueOrNull
                        ?.languageCode ??
                    'pl',
                items: [
                  for (final option in appLanguageOptions)
                    DropdownMenuItem(
                      value: option.code,
                      child: Text(option.label),
                    ),
                ],
                onChanged: (code) {
                  if (code == null) return;
                  ref
                      .read(localeControllerProvider.notifier)
                      .setLocale(Locale(code));
                },
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                l10n.changePasswordTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                enabled: !isPasswordLoading,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.newPasswordLabel),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                enabled: !isPasswordLoading,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.confirmPasswordLabel,
                ),
                onFieldSubmitted: (_) => _changePassword(),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: isPasswordLoading ? null : _changePassword,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: isPasswordLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.changePasswordTitle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
