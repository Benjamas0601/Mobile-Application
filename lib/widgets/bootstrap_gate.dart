import 'package:flutter/material.dart';

import '../core/config/firebase_bootstrap.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// Wraps the app and blocks it when Firebase could not start.
///
/// Why this exists: the brief says "ห้ามปล่อยหน้าขาวหรือ Crash". Without this
/// gate, a missing `firebase_options.dart` produces a black screen and a
/// stack trace the teacher cannot act on.
class BootstrapGate extends StatelessWidget {
  const BootstrapGate({super.key, required this.startup, required this.child});

  final FirebaseStartupResult startup;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return switch (startup) {
      FirebaseReady() => child ?? const SizedBox.shrink(),
      FirebaseUnavailable(:final reason, :final isConfigurationMissing) => _StartupErrorScreen(
          reason: reason,
          isConfigurationMissing: isConfigurationMissing,
        ),
    };
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.reason, required this.isConfigurationMissing});

  final String reason;
  final bool isConfigurationMissing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isConfigurationMissing ? AppColors.warningLight : AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      isConfigurationMissing ? Icons.build_circle_outlined : Icons.cloud_off_outlined,
                      color: isConfigurationMissing ? AppColors.warning : AppColors.danger,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    isConfigurationMissing ? 'ยังตั้งค่าไม่เสร็จ' : AppStrings.errorTitle,
                    style: AppTextStyles.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    reason,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'หน้าจอนี้จะหายไปเมื่อเชื่อมต่อ Firebase สำเร็จ',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
