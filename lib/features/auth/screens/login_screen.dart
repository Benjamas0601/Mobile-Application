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

/// Entry screen for every role (customer / seller / affiliate).
///
/// One screen serves all roles on purpose: the brief's four roles share the
/// same identity, and role selection happens after sign-in, not before —
/// asking for a role up front is the most common drop-off in Thai
/// marketplace apps.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.redirect});

  /// Where to go after a successful sign-in.
  ///
  /// Set when the login screen was reached from a gate such as checkout, so the
  /// user resumes the flow they interrupted instead of being dumped on Home.
  /// Null means "go home", which is the normal browsing case.
  final String? redirect;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Validation runs first so the button gives immediate feedback instead of
    // a network round-trip.
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final user = await ref
          .read(authRepositoryProvider)
          .signIn(
            email: _emailController.text,
            password: _passwordController.text,
          );
      if (!mounted) return;

      // Resume the interrupted flow when there was one; otherwise sellers go
      // to Seller Hub and buyers go to marketplace home.
      final String? redirect = widget.redirect;
      if (redirect != null && redirect.isNotEmpty) {
        context.go(redirect);
      } else if (user.isSeller || user.isAdmin) {
        context.go(AppRoutes.sellerRoot);
      } else {
        context.go(AppRoutes.home);
      }
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'เข้าสู่ระบบไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final String email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'กรุณากรอกอีเมลก่อน แล้วกดลืมรหัสผ่าน');
      return;
    }
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่งลิงก์ตั้งรหัสผ่านใหม่ไปที่อีเมลแล้ว')),
      );
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  /// Fills the demo account so the app can be tried without typing.
  void _fillDemo() {
    _emailController.text = 'customer@example.com';
    _passwordController.text = 'OtopDemo123';
    setState(() => _error = null);
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
                        const Center(child: _Hero()),
                        const SizedBox(height: AppSpacing.xl),
                        _buildHeadline(),
                        const SizedBox(height: AppSpacing.xxl),
                        if (_error != null) ...<Widget>[
                          _ErrorBanner(message: _error!),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        _buildForm(),
                        const SizedBox(height: AppSpacing.lg),
                        _buildDemoHint(),
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
        Text(
          AppStrings.appName,
          style: AppTextStyles.displayMedium,
          textAlign: TextAlign.center,
        ),
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
            enabled: !_busy,
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
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: AppStrings.password,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
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
              onPressed: _busy ? null : _forgotPassword,
              child: const Text(AppStrings.forgotPassword),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
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
                : const Text(AppStrings.login),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoHint() {
    return Center(
      child: TextButton.icon(
        onPressed: _busy ? null : _fillDemo,
        icon: const Icon(Icons.bolt_rounded, size: 18),
        label: const Text('ลองบัญชีสาธิต (ลูกค้า)'),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(AppStrings.dontHaveAccount, style: AppTextStyles.bodyMedium),
        TextButton(
          onPressed: _busy ? null : () => context.push(AppRoutes.register),
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact stand-in for the 3D hero, so the login screen builds even if the
/// 3D widget is unavailable on a platform.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        gradient: AppColors.gradient(const <int>[0xFF146356, 0xFF2E7D6F]),
        borderRadius: AppRadius.cardRadius,
      ),
      alignment: Alignment.center,
      child: const Text('🇹🇭', style: TextStyle(fontSize: 40)),
    );
  }
}
