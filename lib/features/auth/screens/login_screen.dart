import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../widgets/hero_3d.dart';

/// Entry screen for every role (customer / seller / affiliate).
///
/// One screen serves all roles on purpose: the brief's four roles share the
/// same identity, and role selection happens after sign-in, not before —
/// asking for a role up front is the most common drop-off in Thai
/// marketplace apps.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    // TODO(week3): call AuthRepository.signIn(email, password) and route by role.
    // Validation runs first so the button gives immediate feedback instead of
    // a network round-trip.
    if (!(_formKey.currentState?.validate() ?? false)) return;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: ConstrainedBox(
                // Keeps the form readable on tablets and wide Chrome windows
                // instead of stretching a login form across 1920px.
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const SizedBox(height: AppSpacing.xl),
                        const Center(child: Hero3d()),
                        const SizedBox(height: AppSpacing.xl),
                        _buildHeadline(),
                        const SizedBox(height: AppSpacing.xxl),
                        _buildForm(),
                        const SizedBox(height: AppSpacing.xl),
                        _buildFooter(),
                        const SizedBox(height: AppSpacing.xxl),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeadline() {
    return Column(
      children: <Widget>[
        Text(AppStrings.appName, style: AppTextStyles.displayMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xs),
        Text(
          AppStrings.appTagline,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.inkMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: AppStrings.email,
              prefixIcon: Icon(Icons.alternate_email),
            ),
            validator: _validateEmail,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: AppStrings.password,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                tooltip: _obscurePassword ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
              ),
            ),
            validator: _validatePassword,
            onFieldSubmitted: (_) => _submit(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              // TODO(week3): wire to AuthRepository.sendPasswordReset.
              onPressed: () {},
              child: const Text(AppStrings.forgotPassword),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: _submit,
            child: const Text(AppStrings.login),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(AppStrings.dontHaveAccount, style: AppTextStyles.bodyMedium),
        TextButton(
          // TODO(week3): route to /register.
          onPressed: () {},
          child: const Text(AppStrings.register),
        ),
      ],
    );
  }

  // --- Validators ----------------------------------------------------------
  // Kept as plain functions so the same rules can be unit-tested in Week 5
  // without pumping a widget.

  static String? _validateEmail(String? value) {
    final String email = (value ?? '').trim();
    if (email.isEmpty) return AppStrings.errRequired;
    // Deliberately simple: reject the obvious mistakes, do not try to out-lawyer RFC 5322.
    final RegExp pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!pattern.hasMatch(email)) return AppStrings.errEmailFormat;
    return null;
  }

  static String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) return AppStrings.errRequired;
    if (value!.length < 6) return AppStrings.errPasswordShort;
    return null;
  }
}
