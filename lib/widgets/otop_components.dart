import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

//ไฟล์นี้เป็นไฟล์ที่เก็บองค์ประกอบดีไซน์ใหม่ของแบรนด์ ประกอบด้วยฮีโร่หัวโค้งมนพร้อมลายเพชร
//โลโก้ OTOP และภาพประกอบสินค้าชุมชนแบบ isometric วาดด้วย CustomPainter เพื่อให้ทุกหน้าตรงสไตล์เดียวกัน

/// Jade hero header with rounded bottom corners and the diamond lattice.
///
/// The signature header of the jade/gold revamp: a jade band that clips its
/// bottom corners to a 32px radius and paints the light lattice motif, so
/// every flagship screen (Home, auth, seller) shares the same opening.
/// ฮีโร่หัวโค้งมนสีเขียวมรกตพร้อมลายเพชร ใช้เป็นหัวหน้าจอหลักทั้งหมด
class OtopHeroHeader extends StatelessWidget {
  const OtopHeroHeader({
    super.key,
    required this.child,
    this.height,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double? height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: Container(
        height: height,
        width: double.infinity,
        color: AppColors.jade,
        child: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: CustomPaint(painter: DiamondPatternPainter()),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}
 //ไฟล์นี้ประกอบด้วย Widget สำหรับแสดงสถานะต่าง ๆ ของหน้าจอที่ทำงานแบบ Async (เช่น การโหลดข้อมูลจากเครือข่าย) โดยมี Widget สำหรับสถานะการโหลด, สถานะว่าง, สถานะผิดพลาด และสถานะข้อมูลสำเร็จ
/// Light diamond lattice used behind jade headers (and splash).
class DiamondPatternPainter extends CustomPainter {
  const DiamondPatternPainter({
    this.color = const Color(0x552A8A77),
    this.cell = 36,
  });

  final Color color;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    final double h = cell / 2;
    final double r = cell * 0.39;
    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        final Offset c = Offset(x + h, y + h);
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - r)
            ..lineTo(c.dx + r, c.dy)
            ..lineTo(c.dx, c.dy + r)
            ..lineTo(c.dx - r, c.dy)
            ..close(),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant DiamondPatternPainter old) =>
      old.color != color || old.cell != cell;
}

/// "OTOP." wordmark — the jade/gold brand lock-up.
class OtopWordmark extends StatelessWidget {
  const OtopWordmark({
    super.key,
    this.size = 40,
    this.color = Colors.white,
    this.dotColor = AppColors.gold,
  });

  final double size;
  final Color color;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: 'OTOP',
        style: AppTextStyles.displayMedium.copyWith(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1,
          letterSpacing: -size / 40,
        ),
        children: <TextSpan>[
          TextSpan(
            text: '.',
            style: TextStyle(color: dotColor),
          ),
        ],
      ),
    );
  }
}

/// Isometric stack of OTOP goods (crates, woven basket, ceramic jar).
///
/// Drawn on a 220x200 canvas and scaled to [width]. Used in the auth hero and
/// the clay promo banner. No image decode cost, so it is safe in scrollables.
/// ภาพประกอบ isometric กล่องไม้/ตะกร้าสาน/โอ่งเซรามิก วาดเองตามสไตล์แบรนด์
class OtopIllustration extends StatelessWidget {
  const OtopIllustration({super.key, this.width = 200, this.onClay = false});

  final double width;

  /// Use true on the clay promo banner (re-colours crate + basket for contrast).
  final bool onClay;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 200 / 220,
      child: CustomPaint(painter: _OtopPainter(onClay: onClay)),
    );
  }
}

class _OtopPainter extends CustomPainter {
  _OtopPainter({required this.onClay});
  final bool onClay;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 220);

    void poly(List<double> p, Color c) {
      final Path path = Path()..moveTo(p[0], p[1]);
      for (int i = 2; i < p.length; i += 2) {
        path.lineTo(p[i], p[i + 1]);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = c);
    }

    void line(double x1, double y1, double x2, double y2, Color c, double w) {
      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        Paint()
          ..color = c
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round,
      );
    }

    // ground shadow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(110, 190), width: 176, height: 18),
      Paint()..color = const Color.fromRGBO(0, 0, 0, 0.2),
    );

    // clay crate (bottom-left) 
    poly([40, 120, 80, 140, 80, 184, 40, 164], const Color(0xFFA53A28));
    poly([
      80,
      140,
      120,
      120,
      120,
      164,
      80,
      184,
    ], onClay ? const Color(0xFF8F2E1E) : const Color(0xFFC1462F));
    line(40, 142, 80, 162, const Color(0xFF8A2C1C), 2);

    // cream crate (stacked) //คือกล่องไม้สีครีมที่วางซ้อนกัน
    poly([80, 64, 120, 84, 80, 104, 40, 84], const Color(0xFFFBF3DC));
    poly([40, 84, 80, 104, 80, 140, 40, 120], const Color(0xFFE3D4AC));
    poly([80, 104, 120, 84, 120, 120, 80, 140], const Color(0xFFF0E3BE));

    // gold crate (front-right)
    poly([150, 115, 190, 135, 150, 155, 110, 135], const Color(0xFFF2B83A));
    poly([110, 135, 150, 155, 150, 195, 110, 175], const Color(0xFFC98A10));
    poly([150, 155, 190, 135, 190, 175, 150, 195], AppColors.gold);
    line(110, 157, 150, 177, const Color(0xFFA8730C), 2);

    // woven basket
    final Path basket = Path()
      ..moveTo(56, 86)
      ..quadraticBezierTo(56, 60, 80, 60)
      ..quadraticBezierTo(104, 60, 104, 86)
      ..quadraticBezierTo(104, 92, 80, 92)
      ..quadraticBezierTo(56, 92, 56, 86)
      ..close();
    canvas.drawPath(
      basket,
      Paint()..color = onClay ? AppColors.jade : AppColors.gold,
    );
    final Paint weave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = onClay ? AppColors.jadeDark : const Color(0xFFA8730C);
    canvas.drawPath(
      Path()
        ..moveTo(60, 78)
        ..quadraticBezierTo(80, 86, 100, 78)
        ..moveTo(58, 85)
        ..quadraticBezierTo(80, 94, 102, 85),
      weave,
    );
    canvas.drawCircle(
      const Offset(80, 58),
      4,
      Paint()..color = onClay ? AppColors.gold : AppColors.clay,
    );

    // ceramic jar
    final Path jar = Path()
      ..moveTo(137, 114)
      ..lineTo(163, 114)
      ..quadraticBezierTo(169, 120, 169, 130)
      ..lineTo(169, 136)
      ..quadraticBezierTo(169, 144, 150, 144)
      ..quadraticBezierTo(131, 144, 131, 136)
      ..lineTo(131, 130)
      ..quadraticBezierTo(131, 120, 137, 114)
      ..close();
    canvas.drawPath(jar, Paint()..color = AppColors.jadeDark);
    canvas.drawRRect(
      RRect.fromLTRBR(139, 108, 161, 115, const Radius.circular(3)),
      Paint()..color = AppColors.clay,
    );
    line(131, 129, 169, 129, AppColors.gold, 3);

    // leaf + sun
    final Path leaf = Path()
      ..moveTo(178, 92)
      ..quadraticBezierTo(194, 70, 208, 86)
      ..quadraticBezierTo(194, 106, 178, 92)
      ..close();
    canvas.drawPath(leaf, Paint()..color = const Color(0xFF7FBF9A));
    canvas.drawCircle(
      const Offset(182, 48),
      11,
      Paint()..color = AppColors.gold,
    );
  }

  @override
  bool shouldRepaint(covariant _OtopPainter old) => old.onClay != onClay;
}

/// Round translucent icon button for jade headers (like the reference design).
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, color: Colors.white, size: 22),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.jadeLight,
        fixedSize: const Size(44, 44),
      ),
    );
  }
}

/// Section heading with an optional "ดูทั้งหมด" action, in the new style.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(title, style: AppTextStyles.headlineMedium.copyWith(fontSize: 20)),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.jade,
              minimumSize: const Size(44, 44),
              padding: EdgeInsets.zero,
            ),
            child: Text(
              actionLabel!,
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.jade),
            ),
          ),
      ],
    );
  }
}

/// Small helper for the auth screens' jade hero (wordmark + tagline).
class AuthHero extends StatelessWidget {
  const AuthHero({
    super.key,
    required this.tagline,
    this.wordmarkSize = 40,
    this.height,
  });

  final String tagline;
  final double wordmarkSize;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    return OtopHeroHeader(
      height: height ?? 200 + top,
      padding: EdgeInsets.fromLTRB(AppSpacing.xxl, 24 + top, AppSpacing.xxl, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          OtopWordmark(size: wordmarkSize),
          const SizedBox(height: AppSpacing.sm + 2),
          Text(
            tagline,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.onPrimaryMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Jade header used by the buyer Home screen.
class OtopHomeHeader extends StatefulWidget {
  const OtopHomeHeader({
    super.key,
    this.addressLabel,
    this.userName,
    this.onAddressTap,
    this.onNotifications,
    this.unreadCount = 0,
    this.showLogin = false,
    this.onLogin,
    this.showLogout = false,
    this.onLogout,
    this.onSearchChanged,
    this.searchHint = AppStrings.searchHint,
    this.bottom,
  });

  final String? addressLabel;

  /// ชื่อผู้ใช้ที่ล็อกอินอยู่ — เมื่อมีค่า จะแสดงแทนที่อยู่จัดส่ง
  /// (หัวข้อ "สวัสดี" + ชื่อผู้ใช้) เพื่อให้ผู้ใช้รู้ว่ากำลังใช้งานบัญชีไหน
  final String? userName;
  final VoidCallback? onAddressTap;
  final int unreadCount;
  final VoidCallback? onNotifications;
  final bool showLogin;
  final VoidCallback? onLogin;
  final bool showLogout;
  final VoidCallback? onLogout;
  final ValueChanged<String>? onSearchChanged;
  final String searchHint;
  final Widget? bottom;

  @override
  State<OtopHomeHeader> createState() => _OtopHomeHeaderState();
}

class _OtopHomeHeaderState extends State<OtopHomeHeader> {
  static const Duration _debounce = Duration(milliseconds: 350);

  final TextEditingController _controller = TextEditingController();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(_debounce, () => widget.onSearchChanged?.call(value));
  }

  void _clear() {
    _timer?.cancel();
    _controller.clear();
    widget.onSearchChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    final String name = (widget.userName ?? '').trim();
    final bool hasUser = name.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: OtopHeroHeader(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          top + AppSpacing.lg,
          AppSpacing.gutter,
          AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.cream,
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.jade,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: InkWell(
                    onTap: widget.onAddressTap,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          hasUser ? AppStrings.greeting : AppStrings.deliveryTo,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.gold,
                          ),
                        ),
                        Text(
                          hasUser
                              ? name
                              : (widget.addressLabel ??
                                    AppStrings.selectDeliveryAddress),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Badge(
                  isLabelVisible: widget.unreadCount > 0,
                  backgroundColor: AppColors.gold,
                  textColor: AppColors.onGold,
                  label: Text(
                    widget.unreadCount > 9 ? '9+' : '${widget.unreadCount}',
                  ),
                  child: HeaderIconButton(
                    icon: Icons.notifications_none_rounded,
                    tooltip: AppStrings.navNotifications,
                    onPressed: widget.onNotifications,
                  ),
                ),
                if (widget.showLogin) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(
                    onPressed: widget.onLogin,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.onGold,
                      visualDensity: VisualDensity.compact,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(AppStrings.login),
                  ),
                ] else if (widget.showLogout) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(
                    onPressed: widget.onLogout,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      visualDensity: VisualDensity.compact,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(AppStrings.logout),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _controller,
              onChanged: _onChanged,
              onSubmitted: widget.onSearchChanged,
              textInputAction: TextInputAction.search,
              style: AppTextStyles.bodyMedium,
              cursorColor: AppColors.jade,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                hintStyle: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.hint,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.jade,
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder:
                      (
                        BuildContext context,
                        TextEditingValue value,
                        Widget? child,
                      ) {
                        if (value.text.isEmpty) return const SizedBox.shrink();
                        return IconButton(
                          tooltip: AppStrings.clearSearch,
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: _clear,
                        );
                      },
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.pillRadius,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (widget.bottom != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              widget.bottom!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Five-tab navigation bar shared by buyer-facing screens.
class OtopBottomNav extends StatelessWidget {
  const OtopBottomNav({
    super.key,
    required this.currentIndex,
    required this.onChanged,
    this.cartCount = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;
  final int cartCount;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onChanged,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: <Widget>[
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'หน้าแรก',
        ),
        const NavigationDestination(
          icon: Icon(Icons.favorite_border_rounded),
          selectedIcon: Icon(Icons.favorite_rounded),
          label: 'ถูกใจ',
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: cartCount > 0,
            label: Text(cartCount > 9 ? '9+' : '$cartCount'),
            child: const Icon(Icons.shopping_bag_outlined),
          ),
          selectedIcon: Badge(
            isLabelVisible: cartCount > 0,
            label: Text(cartCount > 9 ? '9+' : '$cartCount'),
            child: const Icon(Icons.shopping_bag_rounded),
          ),
          label: 'ตะกร้า',
        ),
        const NavigationDestination(
          icon: Icon(Icons.confirmation_number_outlined),
          selectedIcon: Icon(Icons.confirmation_number_rounded),
          label: 'คูปอง',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'โปรไฟล์',
        ),
      ],
    );
  }
}
