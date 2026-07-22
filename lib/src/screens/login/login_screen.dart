import 'package:flutter/material.dart';

import '../../data/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/filled_input.dart';
import '../../widgets/primary_button.dart';
import '../dashboard/dashboard_screen.dart';

/// Screen 1 — Login.
///
/// Centered logo circle (green gradient), title + tagline, email/password
/// filled inputs, "Forgot password?" link, primary Log In button, and a
/// "New trader? Create account" footer. Auth runs through [AppScope.authOf]
/// (Supabase on device); sessions persist so this screen only appears when
/// the trader is signed out.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const route = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _logIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      showAppToast(context, '⚠ Enter your email and password');
      return;
    }
    setState(() => _busy = true);
    final auth = AppScope.authOf(context);
    final navigator = Navigator.of(context);
    final error = await auth.signIn(email: email, password: password);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      showAppToast(context, '⚠ $error');
      return;
    }
    navigator.pushReplacementNamed(DashboardScreen.route);
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      showAppToast(context, '⚠ Enter your email above first');
      return;
    }
    final error = await AppScope.authOf(context).resetPassword(email);
    if (!mounted) return;
    showAppToast(
      context,
      error != null ? '⚠ $error' : '📧 Password reset email sent',
    );
  }

  void _openCreateAccount() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CreateAccountSheet(
        onDone: (message) {
          if (message != null) {
            showAppToast(context, message);
          } else {
            Navigator.of(context).pushReplacementNamed(DashboardScreen.route);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const BrandLogo(),
                const SizedBox(height: 18),
                Text(
                  'ProsperFlow',
                  style: AppText.style(
                    FontWeight.w900,
                    26,
                    AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppShape.gapSm),
                Text(
                  'Your digital sales ledger',
                  style: AppText.style(
                    FontWeight.w500,
                    14,
                    AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                FilledInput(
                  hint: 'prosper@market.ng',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppShape.gapMd),
                FilledInput(
                  hint: '••••••••',
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2, right: 4),
                    child: TextButton(
                      onPressed: _forgotPassword,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Forgot password?',
                        style: AppText.style(
                          FontWeight.w600,
                          12,
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                PrimaryButton(label: 'Log In', onPressed: _logIn, busy: _busy),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: _openCreateAccount,
                  child: Text.rich(
                    TextSpan(
                      text: 'New trader? ',
                      style: AppText.dialogBody,
                      children: [
                        TextSpan(
                          text: 'Create account',
                          style: AppText.style(
                            FontWeight.w700,
                            13,
                            AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateAccountSheet extends StatefulWidget {
  const _CreateAccountSheet({required this.onDone});

  /// Called after a sign-up attempt: `null` means signed in (go to the
  /// Dashboard); a message means show it and stay on Login.
  final ValueChanged<String?> onDone;

  @override
  State<_CreateAccountSheet> createState() => _CreateAccountSheetState();
}

class _CreateAccountSheetState extends State<_CreateAccountSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      showAppToast(context, '⚠ Fill in your name, email, and password');
      return;
    }
    setState(() => _busy = true);
    final auth = AppScope.authOf(context);
    final navigator = Navigator.of(context);
    final error = await auth.signUp(
      name: name,
      email: email,
      password: password,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    navigator.pop();
    widget.onDone(error);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create account', style: AppText.screenTitle),
          const SizedBox(height: AppShape.gapLg),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('YOUR NAME', style: AppText.fieldLabel),
          ),
          FilledInput(
            hint: 'Prosper Adeyemi',
            controller: _name,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppShape.cardGap),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('EMAIL', style: AppText.fieldLabel),
          ),
          FilledInput(
            hint: 'prosper@market.ng',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppShape.cardGap),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('PASSWORD', style: AppText.fieldLabel),
          ),
          FilledInput(
            hint: '••••••••',
            controller: _password,
            obscureText: true,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'Create Account',
            onPressed: _submit,
            busy: _busy,
          ),
        ],
      ),
    );
  }
}
