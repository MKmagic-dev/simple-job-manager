import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/password_recovery.dart';
import '../../../core/config/branding_config.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/auth_repository.dart';

/// Shown instead of the app when the user arrives from a "reset your
/// password" email link: they're already signed in by the link, and must
/// choose a new password before continuing.
class SetNewPasswordScreen extends ConsumerStatefulWidget {
  const SetNewPasswordScreen({super.key});

  @override
  ConsumerState<SetNewPasswordScreen> createState() =>
      _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends ConsumerState<SetNewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .updatePassword(_passwordController.text);
      if (!mounted) return;
      ref.read(passwordRecoveryPendingProvider.notifier).state = false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.passwordChangedSuccess)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(BrandingConfig.logoAssetPath, height: 100),
                    const SizedBox(height: 16),
                    Text(
                      l10n.setNewPasswordTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.setNewPasswordSubtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_saving,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.newPasswordLabel,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (value) => (value ?? '').length < 6
                          ? l10n.passwordTooShortError
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmController,
                      enabled: !_saving,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: l10n.confirmPasswordLabel,
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      validator: (value) => value != _passwordController.text
                          ? l10n.passwordsDoNotMatchError
                          : null,
                      onFieldSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.saveNewPasswordButton),
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
