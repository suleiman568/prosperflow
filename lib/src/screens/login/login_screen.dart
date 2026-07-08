import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/filled_input.dart';
import '../../widgets/primary_button.dart';
import '../dashboard/dashboard_screen.dart';

/// Screen 1 — Login.
///
/// Centered logo circle (green gradient), title + tagline, email/password
/// filled inputs, "Forgot password?" link, primary Log In button, and a
/// "New trader? Create account" footer.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const route = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _logIn() {
    Navigator.of(context).pushReplacementNamed(DashboardScreen.route);
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
                  style:
                      AppText.style(FontWeight.w900, 26, AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your digital sales ledger',
                  style: AppText.style(
                      FontWeight.w500, 14, AppColors.textSecondary),
                ),
                const SizedBox(height: 28),
                FilledInput(
                  hint: 'prosper@market.ng',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
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
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Forgot password?',
                        style: AppText.style(
                            FontWeight.w600, 12, AppColors.primary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                PrimaryButton(label: 'Log In', onPressed: _logIn),
                const SizedBox(height: 18),
                Text.rich(
                  TextSpan(
                    text: 'New trader? ',
                    style: AppText.style(
                        FontWeight.w500, 13, AppColors.textSecondary),
                    children: [
                      TextSpan(
                        text: 'Create account',
                        style: AppText.style(
                            FontWeight.w700, 13, AppColors.primary),
                      ),
                    ],
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
