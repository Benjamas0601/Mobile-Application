import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/services/auth/login_attempt_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../providers/auth_provider.dart';
import '../../../repositories/auth_repository.dart';
import '../../../widgets/otop_components.dart';

/// ไฟล์นี้เป็นไฟล์ที่เก็บหน้าจอเข้าสู่ระบบของแอป โดยมีฟอร์มให้กรอกอีเมลและรหัสผ่าน และปุ่มเข้าสู่ระบบ ปุ่มลืมรหัสผ่าน และปุ่มลงทะเบียน

/// Entry screen for every role (customer / seller / admin).
///
/// One screen serves all roles on purpose: the brief's roles share the
/// same identity, and role selection happens after sign-in, not before —
/// asking for a role up front is the most common drop-off in Thai
/// marketplace apps.
/// รับข้อมูลล็อกอินและพาผู้ใช้กลับไปยังปลายทางเดิมหลังยืนยันตัวตน
/// (บทบาทมี 3: customer / seller / admin — affiliate ถูกลบ 6 ต.ค. 2569)
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
  void initState() {
    super.initState();
    // The lock is keyed by email, so typing a different account while locked
    // must re-enable the button immediately instead of waiting for the ticker.
    _emailController.addListener(_refreshLockState);
  }

  void _refreshLockState() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _emailController.removeListener(_refreshLockState);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Validation runs first so the button gives immediate feedback instead of
    // a network round-trip.
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final LoginAttemptGuard guard = ref.read(loginAttemptGuardProvider);
    final String email = _emailController.text;
    // The keyboard "done" action can still submit while the button is disabled,
    // so the lock has to be checked here as well as in the button's onPressed.
    if (guard.isLocked(email)) return;

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

      // Correct password — forget earlier misses for this account.
      guard.recordSuccess(email);

      // Resume the interrupted flow when there was one; otherwise sellers go
      // to Seller Hub and buyers go to marketplace home. Tapping the profile
      // tab while signed out must NOT bounce the user back to the edit page
      // after signing in — land on Home instead.
      final String? redirect = widget.redirect;
      if (redirect != null &&
          redirect.isNotEmpty &&
          redirect != AppRoutes.profile) {
        context.go(redirect);
      } else if (user.isAdmin) {
        context.go(AppRoutes.adminRoot);
      } else if (user.isSeller) {
        context.go(AppRoutes.sellerRoot);
      } else {
        context.go(AppRoutes.home);
      }
    } on AuthFailure catch (e) {
      if (!mounted) return;
      if (e.kind == AuthFailureKind.invalidCredentials) {
        // Only a genuinely wrong email/password burns an attempt; a network
        // failure must not lock the user out.
        guard.recordFailure(email);
        final bool locked = guard.isLocked(email);
        setState(() {
          _error = locked
              ? null
              : AppStrings.loginAttemptsLeft(guard.attemptsLeft(email));
        });
      } else {
        setState(() => _error = e.message);
      }
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
    final LoginAttemptGuard guard = ref.watch(loginAttemptGuardProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      // Rebuilds once per second only while a lock is counting down, so the
      // banner and the button label stay in sync without extra plumbing.
      body: ListenableBuilder(
        listenable: guard,
        builder: (BuildContext context, Widget? child) {
          final String email = _emailController.text;
          final bool locked = guard.isLocked(email);
          final int lockSeconds = _secondsLeft(guard.remainingLock(email));
          return Column(
            children: <Widget>[
              // Jade hero band with the OTOP wordmark (revamped auth design).
              const AuthHero(tagline: AppStrings.appTagline),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl,
                    AppSpacing.xxl,
                    AppSpacing.xxl,
                    AppSpacing.xxl,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      // Keeps the form readable on tablets and wide Chrome windows
                      // instead of stretching a login form across 1920px.
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _buildHeadline(),
                          const SizedBox(height: AppSpacing.xxl),
                          if (locked) ...<Widget>[
                            _LockBanner(
                              message: AppStrings.loginLockedFor(
                                guard.maxAttempts,
                                lockSeconds,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ] else if (_error != null) ...<Widget>[
                            _ErrorBanner(message: _error!),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          _buildForm(locked: locked, lockSeconds: lockSeconds),
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
              ),
            ],
          );
        },
      ),
    );
  }

  /// Rounds up so the first second of the lock reads "60" rather than "59".
  static int _secondsLeft(Duration remaining) =>
      (remaining.inMilliseconds / 1000).ceil();

  Widget _buildHeadline() {
    return Text(
      'ยินดีต้อนรับกลับ',
      style: AppTextStyles.displayMedium.copyWith(fontSize: 28),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildForm({required bool locked, required int lockSeconds}) {
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
            // The email and password fields stay editable while locked so the
            // user can correct a typo and switch accounts; only signing in is
            // blocked until the countdown ends.
            onPressed: (_busy || locked) ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    locked
                        ? AppStrings.loginRetryIn(lockSeconds)
                        : AppStrings.login,
                  ),
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

/// Amber banner shown instead of the red error while the 3-strike cooldown is
/// running — the form is not broken, it is deliberately waiting.
class _LockBanner extends StatelessWidget {
  const _LockBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.lock_clock, color: AppColors.warning, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
