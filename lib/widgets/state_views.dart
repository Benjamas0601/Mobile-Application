import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// The four states every async screen must render, per the brief.
///
/// A screen that only handles the success case looks broken the first time
/// the network drops, so these three widgets are the default branches and
/// the data branch is the only one that has to be written per screen.

/// Shown while the first page loads.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(label ?? AppStrings.loading, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

/// Placeholder cards that match the shape of the real content, so the layout
/// does not jump when data arrives.
class SkeletonListView extends StatelessWidget {
  const SkeletonListView({super.key, this.itemCount = 6, this.height = 120});

  final int itemCount;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      itemCount: itemCount,
      separatorBuilder: (BuildContext context, int _) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (BuildContext context, int _) => Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: AppRadius.cardRadius,
        ),
      ),
    );
  }
}

/// Shown when a query failed, with a retry that re-runs the same provider.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppColors.inkSubtle,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppStrings.errorTitle,
              style: AppTextStyles.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message ?? AppStrings.errorBody,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.inkMuted,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text(AppStrings.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown when a query succeeded but returned nothing.
///
/// Always offers a way forward — a dead end is the failure mode the brief
/// explicitly calls out.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.body,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? body;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: AppColors.inkSubtle),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: AppTextStyles.headlineSmall,
              textAlign: TextAlign.center,
            ),
            if (body != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                body!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.inkMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A one-line banner for a non-fatal problem, e.g. "โหลดสินค้าเพิ่มไม่สำเร็จ"
/// while the already-loaded list stays on screen.
class InlineErrorBanner extends StatelessWidget {
  const InlineErrorBanner({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text(AppStrings.retry)),
        ],
      ),
    );
  }
}
