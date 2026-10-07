import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// คอมโพเนนต์ UI ที่ใช้ร่วมกันเพื่อให้หน้าจอต่าง ๆ ใช้รูปแบบและระยะห่างเดียวกัน
///
/// รวมการ์ด ปุ่ม ป้าย และองค์ประกอบพื้นฐานอื่น ๆ โดยอิงค่าจาก design tokens
/// ใน `core/theme` เพื่อปรับหน้าตาแอปได้อย่างสอดคล้อง

/// Wraps a child in the design's rounded-square icon plate.
///
/// Used by [EmptyStateView] / [ErrorStateView] and the small warning tiles so
/// an icon always sits on the same soft disc instead of floating loose.
/// แสดงไอคอนบนพื้นหลังทรงมนที่มีสีและขนาดกำหนดได้
class AppIconPlate extends StatelessWidget {
  const AppIconPlate({
    super.key,
    required this.icon,
    this.color = AppColors.inkMuted,
    this.background = AppColors.primaryLight,
    this.size = AppSizes.stateIconPlate,
    this.iconSize = 30,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

/// Wraps a child in a subtle white card with the design's radius and hairline
/// border. Every console screen uses this instead of [Card] so padding and
/// radius stay identical across screens.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.radius = AppRadius.xl,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final BorderRadius shape = BorderRadius.circular(radius);

    final Widget content = Padding(padding: padding, child: child);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        borderRadius: shape,
        border: Border.all(
          color: borderColor ?? scheme.outlineVariant,
          width: borderWidth,
        ),
      ),
      child: onTap == null
          ? content
          : Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap, borderRadius: shape, child: content),
            ),
    );
  }
}

/// The design's signature button: solid fill with a hard drop-shadow edge that
/// collapses when pressed.
///
/// Flutter's [ElevatedButton] cannot express "translate down 4px and hide the
/// shadow", so the press effect is done with a Transform + a stacked
/// decoration. The full-height hit target is preserved — only the visual box
/// shrinks, which keeps the accessible target at [AppSizes.minTapTarget].
class AppChunkyButton extends StatefulWidget {
  const AppChunkyButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AppChunkyVariant.solid,
    this.height = AppSizes.chunkyButtonHeight,
    this.expand = true,
    this.shadowColor,
  });

  /// Solid indigo with a deep-indigo shadow — the primary action.
  const AppChunkyButton.outlined({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    double height = AppSizes.chunkyButtonHeight,
    bool expand = true,
  }) : this(
         key: key,
         label: label,
         onPressed: onPressed,
         icon: icon,
         variant: AppChunkyVariant.outlined,
         height: height,
         expand: expand,
       );

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppChunkyVariant variant;
  final double height;
  final bool expand;
  final Color? shadowColor;

  @override
  State<AppChunkyButton> createState() => _AppChunkyButtonState();
}

enum AppChunkyVariant { solid, outlined, disabled }

class _AppChunkyButtonState extends State<AppChunkyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isDisabled =
        widget.onPressed == null || widget.variant == AppChunkyVariant.disabled;
    final bool isOutlined = widget.variant == AppChunkyVariant.outlined;

    final Color fill = isDisabled
        ? AppColors.disabled
        : isOutlined
        ? Theme.of(context).colorScheme.surface
        : AppColors.primary;
    final Color foreground = isDisabled
        ? Theme.of(context).colorScheme.onSurface
        : isOutlined
        ? AppColors.primary
        : AppColors.onPrimary;
    final Color edge = isDisabled
        ? AppColors.disabledDark
        : isOutlined
        ? AppColors.border
        : (widget.shadowColor ?? AppColors.primaryDark);

    final double edgeWidth = isOutlined ? 4 : AppSizes.chunkyShadow;

    return Semantics(
      button: true,
      enabled: !isDisabled,
      child: GestureDetector(
        onTapDown: isDisabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: isDisabled ? null : (_) => setState(() => _pressed = false),
        onTapCancel: isDisabled ? null : () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
          padding: EdgeInsets.only(bottom: _pressed ? 0 : edgeWidth),
          child: Container(
            height: widget.height,
            width: widget.expand ? double.infinity : null,
            padding: widget.expand
                ? null
                : const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(AppRadius.chunky),
              border: isOutlined
                  ? Border.all(color: AppColors.primary, width: 1.5)
                  : null,
              boxShadow: _pressed
                  ? null
                  : <BoxShadow>[
                      BoxShadow(color: edge, offset: Offset(0, edgeWidth)),
                    ],
            ),
            child: Row(
              mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (widget.icon != null) ...<Widget>[
                  Icon(widget.icon, size: 20, color: foreground),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
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

/// Muted caption above a block of content, matching `.lbl` in the design.
class AppSectionLabel extends StatelessWidget {
  const AppSectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.cardGutter,
        AppSpacing.lg,
        AppSpacing.cardGutter,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Small helper text under a block, optionally styled as a warning.
class AppHint extends StatelessWidget {
  const AppHint(this.text, {super.key, this.isWarning = false, this.padding});

  final String text;
  final bool isWarning;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          padding ??
          const EdgeInsets.fromLTRB(
            AppSpacing.cardGutter + AppSpacing.xs,
            AppSpacing.sm,
            AppSpacing.cardGutter + AppSpacing.xs,
            0,
          ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          height: 1.5,
          color: isWarning
              ? AppColors.clay
              : Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: isWarning ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

/// The horizontal step tracker used by the 4-step product flow.
///
/// A dot per step with a connecting rail. Completed steps fill the rail in
/// indigo; the current step is turmeric with a soft halo so "you are here" is
/// not conveyed by colour alone — it is also the only bold label.
class AppStepBar extends StatelessWidget {
  const AppStepBar({
    super.key,
    required this.steps,
    required this.currentIndex,
  });

  final List<String> steps;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.cardGutter,
        AppSpacing.sm,
        AppSpacing.cardGutter,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < steps.length; i++) ...<Widget>[
            _StepDot(
              label: steps[i],
              isDone: i < currentIndex,
              isCurrent: i == currentIndex,
              doneColor: scheme.primary,
              railColor: scheme.primary,
              pendingRailColor: scheme.outlineVariant,
            ),
            if (i != steps.length - 1)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    height: 2,
                    color: i < currentIndex
                        ? scheme.primary
                        : scheme.outlineVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.doneColor,
    required this.railColor,
    required this.pendingRailColor,
  });

  final String label;
  final bool isDone;
  final bool isCurrent;
  final Color doneColor;
  final Color railColor;
  final Color pendingRailColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color dotColor = isDone
        ? doneColor
        : isCurrent
        ? AppColors.accent
        : pendingRailColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            boxShadow: isCurrent
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.35),
                      blurRadius: 0,
                      spreadRadius: 4,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 62),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.25,
              color: isCurrent ? scheme.onSurface : scheme.onSurfaceVariant,
              fontWeight: isCurrent || isDone
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

/// Status badge: a tinted pill with a leading dot.
///
/// Always carries its Thai label, so the state is legible without relying on
/// the colour (accessibility requirement from the design brief).
class AppStatusPill extends StatelessWidget {
  const AppStatusPill({
    super.key,
    required this.label,
    required this.color,
    required this.background,
    this.dense = false,
  });

  /// Fills itself from the theme, avoiding a hardcoded colour per call site.
  factory AppStatusPill.semantic({
    Key? key,
    required String label,
    required AppTone tone,
    bool dense = false,
  }) {
    return AppStatusPill(
      key: key,
      label: label,
      color: tone.foreground,
      background: tone.background,
      dense: dense,
    );
  }

  final String label;
  final Color color;
  final Color background;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.sm + 2,
        vertical: dense ? 3 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: dense ? 11 : 11.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The four semantic tones used by [AppStatusPill.semantic].
enum AppTone {
  wait(AppColors.warning, AppColors.warningLight),
  good(AppColors.success, AppColors.successLight),
  bad(AppColors.clayDark, AppColors.dangerLight),
  off(AppColors.inkMuted, AppColors.neutralLight),
  info(AppColors.info, AppColors.infoLight);

  const AppTone(this.foreground, this.background);

  final Color foreground;
  final Color background;
}

/// Progress rail made of N segments, matching `.stg` in the design.
///
/// `currentIndex` segments are filled, and the segment the order sits on is
/// turmeric so the "you are here" position is distinct from "already done".
class AppStageRail extends StatelessWidget {
  const AppStageRail({
    super.key,
    required this.total,
    required this.currentIndex,
    this.semanticsLabel,
  });

  final int total;
  final int currentIndex;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: semanticsLabel,
      value: semanticsLabel == null ? null : '$currentIndex จาก $total',
      child: Row(
        children: <Widget>[
          for (int i = 0; i < total; i++) ...<Widget>[
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: i < currentIndex
                      ? scheme.primary
                      : i == currentIndex
                      ? AppColors.accent
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            if (i != total - 1) const SizedBox(width: 5),
          ],
        ],
      ),
    );
  }
}

/// Vertical dashed timeline for a status chain, matching `.tl`.
class AppTimeline extends StatelessWidget {
  const AppTimeline({
    super.key,
    required this.items,
    required this.currentIndex,
  });

  /// Each entry is a label plus an optional sub-caption.
  final List<TimelineEntry> items;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < items.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  width: 26,
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: i == currentIndex
                              ? AppColors.accent
                              : scheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: i == currentIndex
                                ? AppColors.accent
                                : scheme.outline,
                            width: 2.5,
                          ),
                          boxShadow: i == currentIndex
                              ? <BoxShadow>[
                                  BoxShadow(
                                    color: AppColors.accent.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 0,
                                    spreadRadius: 5,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      if (i != items.length - 1)
                        Expanded(
                          child: CustomPaint(
                            painter: _DashedVerticalLinePainter(
                              color: scheme.outlineVariant,
                            ),
                            size: const Size(2, double.infinity),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i == items.length - 1 ? 0 : AppSpacing.lg,
                      top: 1,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          items[i].label,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: i <= currentIndex
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                            fontWeight: i == currentIndex
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        if (items[i].caption != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              items[i].caption!,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class TimelineEntry {
  const TimelineEntry(this.label, {this.caption});

  final String label;
  final String? caption;
}

/// Paints a vertical dashed line. A `CustomPainter` is used rather than a
/// column of small boxes so the dash spacing stays even at any height.
class _DashedVerticalLinePainter extends CustomPainter {
  const _DashedVerticalLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const double dash = 5;
    const double gap = 4;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, (y + dash).clamp(0, size.height)),
        paint,
      );
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedVerticalLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Woven-fabric placeholder used in place of product photography.
///
/// The design set uses texture rather than photos so a layout reads the same
/// with or without assets. Drawn with a painter so there is no image decode
/// cost on a scrolling grid.
class WeaveTexture extends StatelessWidget {
  const WeaveTexture({
    super.key,
    this.color = AppColors.weaveGreen,
    this.diagonal = false,
    this.width,
    this.height,
    this.radius = AppRadius.lg,
    this.child,
  });

  final Color color;
  final bool diagonal;
  final double? width;
  final double? height;
  final double radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            CustomPaint(
              painter: _WeavePainter(color: color, diagonal: diagonal),
            ),
            ?child,
          ],
        ),
      ),
    );
  }
}

class _WeavePainter extends CustomPainter {
  const _WeavePainter({required this.color, required this.diagonal});

  final Color color;
  final bool diagonal;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);

    final Paint light = Paint()
      ..color = Colors.white.withValues(alpha: diagonal ? 0.18 : 0.20)
      ..strokeWidth = 3;
    final Paint dark = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..strokeWidth = 3;

    if (diagonal) {
      for (double x = -size.height; x < size.width; x += 9) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x + size.height, size.height),
          light,
        );
      }
    } else {
      for (double y = 0; y < size.height; y += 7) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), light);
      }
      for (double x = 0; x < size.width; x += 7) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), dark);
      }
    }
  }

  @override
  bool shouldRepaint(_WeavePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.diagonal != diagonal;
}

/// Flat chip used for filters and inline actions, matching `.chip`.
///
/// 48px tall so it is a comfortable tap target, and it supports a selected
/// state that inverts to solid indigo.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.onTap,
    this.selected = false,
    this.icon,
    this.height = AppSizes.chipHeight,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? scheme.primary : scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.chunky),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.chunky),
          child: Container(
            height: height,
            constraints: const BoxConstraints(minWidth: AppSizes.minTapTarget),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.chunky),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? scheme.onPrimary : scheme.onSurface,
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: selected ? scheme.onPrimary : scheme.onSurface,
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

/// Inline confirmation toast that slides in from the top, matching `.toast`.
///
/// Used where a SnackBar would be wrong: the message confirms an action the
/// user just took on the current screen, and it must not cover the controls
/// they may want to use next.
class AppTopToast extends StatelessWidget {
  const AppTopToast({
    super.key,
    required this.visible,
    required this.message,
    this.icon = Icons.check_rounded,
  });

  final bool visible;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, -1.4),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.md,
              AppSpacing.gutter,
              0,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(AppRadius.chunky),
            ),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 18, color: AppColors.accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 14,
                      height: 1.35,
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

/// Info strip used for the MVP caveats ("no real payout yet") and the
/// low-stock warning tile.
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.child,
    this.tone = AppTone.wait,
    this.icon,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final Widget child;
  final AppTone tone;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: icon == null
          ? child
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon, size: 20, color: tone.foreground),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: child),
              ],
            ),
    );
  }
}
