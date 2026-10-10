import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart' show UserRole;
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../repositories/auth_repository.dart';
import '../../../widgets/state_views.dart';

/// หน้าแก้ไขข้อมูลส่วนตัว (/profile) — ผู้ล็อกอินแก้ชื่อและเบอร์โทรของตัวเองได้
/// ส่วนอีเมลใช้สำหรับล็อกอินจึงแสดงแบบอ่านอย่างเดียว
///
/// Router (`accountRequired`) กันคนที่ยังไม่ได้ล็อกอินไว้ก่อนหน้าอยู่แล้ว และ
/// `firestore.rules` users.update ยืนยันอีกชั้นว่าแก้ได้เฉพาะฟิลด์ที่อนุญาต
/// (ห้ามแตะ roles/email/createdAt) — ฟอร์มนี้จึงมีแต่ช่องที่กฎรับได้
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  /// ฟอร์ม + ตัวควบคุมช่องแก้ไข ใช้ดีไซน์เดียวกับฟอร์มสมัครสมาชิก
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _hydrated = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// คัดลอกค่าปัจจุบันจากโปรไฟล์ลงช่องแก้ไขครั้งเดียว ตอนข้อมูลโผล่ครั้งแรก
  /// (ทำใน build แทน initState เพราะ user มาจาก AsyncValue ที่โหลดไม่พร้อม)
  void _hydrate(UserModel? user) {
    if (user == null || _hydrated) return;
    _nameController.text = user.displayName;
    _phoneController.text = user.phone;
    _hydrated = true;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).updateProfile(
            displayName: _nameController.text,
            phone: _phoneController.text,
          );
      if (!mounted) return;

      // auth stream ไม่ปล่อย event ใหม่เมื่อแก้โปรไฟล์ (ไม่มี token refresh)
      // จึงต้อง invalidate เพื่อให้หน้า home ทักทายชื่อใหม่ได้ทันที
      ref.invalidate(authUserProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.profileSaved)),
      );
      context.pop();
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '${AppStrings.profileSaveFailed}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<UserModel?> auth = ref.watch(authUserProvider);
    final UserModel? user = auth.value;
    _hydrate(user);

    // ไม่ควรเกิดจริง (router บังคับล็อกอินแล้ว) แต่กันหน้าค้างเวลาโหลดช้า
    if (auth.isLoading || user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.profileEdit)),
        body: const LoadingView(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.profileEdit)),
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
                    _header(context, user),
                    const SizedBox(height: AppSpacing.lg),
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
                    // อีเมลกำหนดจากบัญชีล็อกอิน ไม่ใช่ช่องที่แก้ได้ —
                    // แสดงแบบปิดการแก้ไข เพื่อไม่ให้ดูเหมือนกดได้
                    TextFormField(
                      initialValue: user.email,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: AppStrings.email,
                        prefixIcon: Icon(Icons.alternate_email),
                        helperText: AppStrings.emailLockedHint,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: AppStrings.displayName,
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (String? v) =>
                          (v == null || v.trim().isEmpty)
                          ? AppStrings.errRequired
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: AppStrings.phone,
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: _validatePhone,
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
                          : const Text(AppStrings.saveProfile),
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

  /// หัวตาราง: อวตารจากอักษรแรกของชื่อ + ชื่อ + ป้ายบทบาททั้งหมดของบัญชี
  Widget _header(BuildContext context, UserModel user) {
    return Column(
      children: <Widget>[
        CircleAvatar(
          radius: 36,
          backgroundColor: AppColors.primaryLight,
          child: Text(
            user.displayName.isEmpty
                ? '👤'
                : user.shortName.characters.first,
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(user.displayName, style: AppTextStyles.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.xs,
          children: <Widget>[
            for (final UserRole role in user.roles)
              Chip(
                label: Text(role.label),
                visualDensity: VisualDensity.compact,
                labelStyle: AppTextStyles.labelSmall,
                backgroundColor: AppColors.surface,
              ),
          ],
        ),
      ],
    );
  }

  /// เบอร์โทรไทยขึ้นต้น 0 ยาว 9–10 หลัก (ขีด/เว้นวรรคตัดทิ้งก่อนตรวจ)
  /// ใช้กฎเดียวกับฟอร์มสมัคร เพื่อกันข้อมูลกระจัดกระจาย
  static String? _validatePhone(String? value) {
    final String phone = (value ?? '').replaceAll(RegExp(r'\s'), '');
    if (phone.isEmpty) {
      return AppStrings.errRequired;
    }
    if (!RegExp(r'^0\d{8,9}$').hasMatch(phone)) {
      return AppStrings.errPhoneFormat;
    }
    return null;
  }
}