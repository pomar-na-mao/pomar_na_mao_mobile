import 'package:flutter/material.dart';

import '../authentication_view_model.dart';

Future<bool> showAuthenticationDialog({
  required BuildContext context,
  required AuthenticationViewModel viewModel,
  required String title,
  required String description,
}) async {
  if (viewModel.isAuthenticated) return true;
  viewModel.clearError();
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AuthenticationDialog(
          viewModel: viewModel,
          title: title,
          description: description,
        ),
      ) ??
      false;
}

class AuthenticationDialog extends StatefulWidget {
  const AuthenticationDialog({
    required this.viewModel,
    required this.title,
    required this.description,
    super.key,
  });

  final AuthenticationViewModel viewModel;
  final String title;
  final String description;

  @override
  State<AuthenticationDialog> createState() => _AuthenticationDialogState();
}

class _AuthenticationDialogState extends State<AuthenticationDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final theme = Theme.of(context);
      final screenSize = MediaQuery.sizeOf(context);
      final dialogHeight = (screenSize.height * 0.68).clamp(500.0, 620.0);
      return Dialog(
        key: const ValueKey('authentication-dialog'),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        insetAnimationDuration: const Duration(milliseconds: 220),
        insetAnimationCurve: Curves.easeOutCubic,
        child: SizedBox(
          width: 520,
          height: dialogHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 16, 18),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cancelar autenticação',
                      onPressed: widget.viewModel.authenticating
                          ? null
                          : () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: AutofillGroup(
                  child: SingleChildScrollView(
                    key: const ValueKey('authentication-dialog-scroll'),
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          key: const ValueKey('authentication-email'),
                          controller: _emailController,
                          enabled: !widget.viewModel.authenticating,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          key: const ValueKey('authentication-password'),
                          controller: _passwordController,
                          enabled: !widget.viewModel.authenticating,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            prefixIcon: const Icon(Icons.password_outlined),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Mostrar senha'
                                  : 'Ocultar senha',
                              onPressed: widget.viewModel.authenticating
                                  ? null
                                  : () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        if (widget.viewModel.error case final error?) ...[
                          const SizedBox(height: 16),
                          Container(
                            key: const ValueKey('authentication-error'),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              error,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: widget.viewModel.authenticating
                          ? null
                          : () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      key: const ValueKey('authentication-submit'),
                      onPressed: widget.viewModel.authenticating
                          ? null
                          : _submit,
                      icon: widget.viewModel.authenticating
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.login),
                      label: const Text('Entrar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final authenticated = await widget.viewModel.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted || !authenticated) return;
    Navigator.pop(context, true);
  }
}
