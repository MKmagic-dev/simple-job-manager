import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/branding_config.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'login_controller.dart';
import 'register_company_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    await ref
        .read(loginControllerProvider.notifier)
        .signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  String _errorMessage(AppLocalizations l10n, Object error) {
    if (error is AuthException) {
      switch (error.message) {
        case 'Invalid login credentials':
          return l10n.invalidCredentialsError;
        default:
          return error.message;
      }
    }
    return l10n.genericError;
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginControllerProvider);
    final isLoading = loginState.isLoading;
    final l10n = AppLocalizations.of(context)!;

    ref.listen<AsyncValue<void>>(loginControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(_errorMessage(l10n, error))));
        },
      );
    });

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
                    Image.asset(BrandingConfig.logoAssetPath, height: 120),
                    const SizedBox(height: 8),
                    Text(
                      BrandingConfig.appName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.loginSubtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      enabled: !isLoading,
                      autofillHints: const [AutofillHints.email],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.emailLabel,
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) return l10n.emailRequiredError;
                        if (!trimmed.contains('@')) {
                          return l10n.emailInvalidError;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !isLoading,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: l10n.passwordLabel,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.passwordRequiredError;
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: isLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.signInButton),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const RegisterCompanyScreen(),
                                ),
                              );
                            },
                      child: Text(l10n.registerCompanyLinkText),
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
