import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import 'design_system.dart';

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

/// Shimmering bars that match the shape of the real content, so the layout
/// does not jump when data arrives.
class SkeletonListView extends StatelessWidget {
  const SkeletonListView({
    super.key,
    this.itemCount = 6,
    this.height = 120,
    this.cardRadius,
    this.padding,
  });

  final int itemCount;
  final double height;
  final BorderRadius? cardRadius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = cardRadius ?? AppRadius.cardRadius;

    return ListView.separated(
      padding: padding ?? const EdgeInsets.all(AppSpacing.gutter),
      itemCount: itemCount,
      separatorBuilder: (BuildContext context, int _) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (BuildContext context, int index) => Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: radius,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

/// Shimmering card placeholders laid out in a plain column.
///
/// [SkeletonListView] is a `ListView`, so it cannot be nested inside another
/// scroll view. This variant is for screens that already own their scrolling —
/// it fills the same slot without adding a second one.
class SkeletonCards extends StatelessWidget {
  const SkeletonCards({
    super.key,
    this.itemCount = 3,
    this.height = 110,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.cardGutter,
    ),
  });

  final int itemCount;
  final double height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final Color fill = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Padding(
      padding: padding,
      child: Column(
        children: <Widget>[
          for (int i = 0; i < itemCount; i++)
            Container(
              height: height,
              margin: EdgeInsets.only(
                bottom: i == itemCount - 1 ? 0 : AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
            ),
        ],
      ),
    );
  }
}

/// Multi-line shimmering text block, matching `.skel` in the design set.
///
/// Preferred over [SkeletonListView] when the real content is a short list of
/// text rows, so the placeholder has the same rhythm as the loaded screen.
class SkeletonTextBlock extends StatefulWidget {
  const SkeletonTextBlock({super.key, this.lines = 5, this.label});

  final int lines;

  /// Announced by screen readers while the block is on screen.
  final String? label;

  @override
  State<SkeletonTextBlock> createState() => _SkeletonTextBlockState();
}

class _SkeletonTextBlockState extends State<SkeletonTextBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Widths alternate so the block does not read as a solid block of grey.
  static const List<double> _widths = <double>[0.62, 0.88, 1.0, 0.74, 0.52];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: widget.label ?? AppStrings.loading,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardGutter,
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int i = 0; i < widget.lines; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _widths[i % _widths.length],
                        child: Container(
                          height: 15,
                          decoration: BoxDecoration(
                            color: AppColors.border.withValues(
                              alpha: 0.35 + _controller.value * 0.35,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Shown when a query failed, with a retry that re-runs the same provider.
///
/// [detail] carries the raw error for when the user needs it (logs, support),
/// but it stays hidden behind [showDetail] because a Firebase permission error
/// means nothing to a seller — they cannot act on it either way.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    this.message,
    this.detail,
    this.onRetry,
    this.showDetail = false,
  });

  final String? message;
  final String? detail;
  final VoidCallback? onRetry;
  final bool showDetail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const AppIconPlate(
              icon: Icons.error_outline_rounded,
              color: AppColors.clayDark,
              background: AppColors.dangerLight,
              iconSize: 32,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppStrings.errorTitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message ?? AppStrings.errorBody,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (showDetail && detail != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.inkSubtle,
                ),
              ),
            ],
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: 210,
                child: AppChunkyButton(
                  label: AppStrings.retry,
                  onPressed: onRetry,
                ),
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
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.compact = false,
  });

  final String title;
  final String? body;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  /// Drops the outer padding for an empty state rendered *inside* a list that
  /// already provides section padding — otherwise it floats in the middle of
  /// the screen instead of sitting under its heading.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppIconPlate(icon: icon),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (body != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                body!,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: 210,
                child: AppChunkyButton(
                  label: actionLabel!,
                  onPressed: onAction,
                ),
              ),
            ],
            if (secondaryActionLabel != null &&
                onSecondaryAction != null) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 210,
                child: AppChunkyButton.outlined(
                  label: secondaryActionLabel!,
                  height: AppSizes.chipHeight,
                  onPressed: onSecondaryAction,
                ),
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
  const InlineErrorBanner({
    super.key,
    required this.message,
    this.detail,
    this.onRetry,
  });

  final String message;
  final String? detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.cardGutter,
        AppSpacing.sm,
        AppSpacing.cardGutter,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.clayDark,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.clayDark,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: AppColors.clayDark,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text(AppStrings.retry)),
        ],
      ),
    );
  }
}
