import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/favorite_provider.dart';

/// ปุ่มหัวใจสำหรับกด "ถูกใจ" ใช้ซ้ำได้ทั้งการ์ดสินค้าและหน้ารายละเอียด
///
/// ผู้ที่ยังไม่ล็อกอินจะได้รับการบอกให้เข้าสู่ระบบก่อน และจะไม่มีการเขียน
/// Firestore เลย — เก็บความปลอดภัยไว้ที่ `firestore.rules` อีกชั้นหนึ่ง
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    super.key,
    required this.productId,
    this.size = 20,
    this.onCard = false,
  });

  final String productId;
  final double size;

  /// true = ปุ่มลอยบนภาพการ์ด (พื้นวงกลมทึบให้เห็นบนรูป), false = ปุ่มในแถบด้านบน
  final bool onCard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isFavorite = ref.watch(isFavoriteProvider(productId));
    final String label = isFavorite
        ? AppStrings.removeFromFavorites
        : AppStrings.addToFavorites;

    final Widget icon = Icon(
      isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      size: size,
      color: onCard
          ? (isFavorite ? AppColors.clay : Colors.white)
          : (isFavorite ? AppColors.clay : null),
      semanticLabel: label,
    );

    if (onCard) {
      return Material(
        color: const Color(0x60000000),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _toggle(context, ref),
          child: Padding(padding: EdgeInsets.all(size * 0.28), child: icon),
        ),
      );
    }

    return IconButton(
      tooltip: label,
      icon: icon,
      onPressed: () => _toggle(context, ref),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    // จับ messenger ไว้ก่อน await เพื่อไม่ให้ใช้ context ข้าม async gap
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final UserModel? user = ref.read(authUserProvider).asData?.value;
    if (user == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(AppStrings.loginToFavorite)),
        );
      return;
    }

    try {
      await ref.read(toggleFavoriteProvider)(productId);
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(AppStrings.favoriteFailed)));
    }
  }
}
