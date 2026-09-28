import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../providers/auth_provider.dart';
import '../../../repositories/auth_repository.dart';
import '../widgets/hero_3d.dart';

/// Sign-up.
///
/// New accounts always start as `customer`; a seller applies for the role
/// after the account exists, which keeps the registration form short and
/// matches the rule that a user cannot set their own roles.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.redirect});

  /// Mirrors [LoginScreen.redirect]: resume the flow that needed an account
  /// rather than bouncing to Home.
  final String? redirect;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .register(
            email: _emailController.text,
            password: _passwordController.text,
            displayName: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
          );
      if (!mounted) return;
      final String? redirect = widget.redirect;
      if (redirect != null && redirect.isNotEmpty) {
        context.go(redirect);
      } else {
        context.go(AppRoutes.home);
      }
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'สมัครสมาชิกไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.register)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Center(child: Hero3d()),
                    const SizedBox(height: AppSpacing.xl),
                    if (_error != null) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: AppRadius.cardRadius,
                        ),
                        child: Text(
                          _error!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: AppStrings.displayName,
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (String? v) => (v == null || v.trim().isEmpty)
                          ? AppStrings.errRequired
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: AppStrings.email,
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: AppStrings.phone,
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: _validatePhone,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.next,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: AppStrings.password,
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        labelText: AppStrings.confirmPassword,
                        prefixIcon: const Icon(Icons.lock_reset_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (String? v) => v != _passwordController.text
                          ? AppStrings.errPasswordMismatch
                          : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(AppStrings.register),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: _busy ? null : () => context.pop(),
                      child: const Text(AppStrings.alreadyHaveAccount),
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

  static String? _validateEmail(String? value) {
    final String email = (value ?? '').trim();
    if (email.isEmpty) return AppStrings.errRequired;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return AppStrings.errEmailFormat;
    }
    return null;
  }

  static String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) return AppStrings.errRequired;
    if (value!.length < 6) return AppStrings.errPasswordShort;
    return null;
  }

  static String? _validatePhone(String? value) {
    final String phone = (value ?? '').replaceAll(RegExp(r'\s'), '');
    if (phone.isEmpty) {
      return null; // optional field
    }
    if (!RegExp(r'^0\d{8,9}$').hasMatch(phone)) {
      return AppStrings.errPhoneFormat;
    }
    return null;
  }
}
