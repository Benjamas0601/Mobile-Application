import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/coupon_model.dart';
import '../../../providers/coupon_provider.dart';
import '../../../widgets/state_views.dart';

/// หน้ารายการคูปองสำหรับผู้ซื้อ — แสดงเฉพาะคูปองที่ใช้งานได้ตอนนี้
/// (เปิดใช้งาน, ยังไม่เกินกำหนด, ยังเหลือจำนวน) โดยดึงแบบเรียลไทม์จาก
/// Firestore ผ่าน [adminCouponsProvider] (`.snapshots()` lifecycle) —
/// เมื่อแอดมินสร้าง/ปิด/ลบคูปอง รายการหน้านี้จะอัปเดตเองทันที
class CouponListScreen extends ConsumerWidget {
  const CouponListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: AppStrings.backToHome,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        title: const Text(AppStrings.coupon),
      ),
      body: ref
          .watch(adminCouponsProvider)
          .when(
            loading: () => const LoadingView(),
            error: (Object error, StackTrace stack) => ErrorView(
              message: '$error',
              onRetry: () => ref.invalidate(adminCouponsProvider),
            ),
            data: (List<CouponModel> all) {
              final List<CouponModel> usable = all
                  .where((CouponModel coupon) => _usableNow(coupon))
                  .toList();
              if (usable.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const <Widget>[
                    SizedBox(
                      height: 320,
                      child: EmptyView(
                        icon: Icons.local_offer_outlined,
                        title: 'ยังไม่มีคูปอง',
                        body: 'คูปองจากผู้ดูแลระบบจะแสดงที่นี่ '
                            'เมื่อมีโปรโมชัน',
                      ),
                    ),
                  ],
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(adminCouponsProvider);
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  itemCount: usable.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (BuildContext context, int index) =>
                      _CouponCard(coupon: usable[index]),
                ),
              );
            },
          ),
    );
  }

  bool _usableNow(CouponModel coupon) {
    if (!coupon.active) return false;
    final DateTime now = DateTime.now();
    if (coupon.startsAt != null && now.isBefore(coupon.startsAt!)) return false;
    if (coupon.expiresAt != null && now.isAfter(coupon.expiresAt!)) return false;
    if (coupon.usageLimit != null && coupon.usedCount >= coupon.usageLimit!) {
      return false;
    }
    return true;
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.coupon});

  final CouponModel coupon;

  @override
  Widget build(BuildContext context) {
    final String discount = switch (coupon.type) {
      CouponType.percentage => 'ลด ${coupon.value.toStringAsFixed(0)}%',
      CouponType.fixed => 'ลด ${coupon.value.toStringAsFixed(0)} บาท',
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.clayLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.local_offer_rounded, color: AppColors.ink),
                const SizedBox(height: 2),
                Text(
                  discount,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  coupon.code,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.jade,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _conditions(coupon),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _conditions(CouponModel coupon) {
    final List<String> parts = <String>[];
    if (coupon.storeId != null) parts.add('เฉพาะร้านที่กำหนด');
    if (coupon.minSpend > 0) {
      parts.add('ขั้นต่ำ ${coupon.minSpend.toStringAsFixed(0)} บาท');
    }
    if (coupon.expiresAt != null) {
      parts.add('หมดอายุ ${_formatDate(coupon.expiresAt!)}');
    }
    if (coupon.usageLimit != null) {
      parts.add('เหลือ ${coupon.usageLimit! - coupon.usedCount} ใบ');
    }
    return parts.isEmpty ? 'ใช้ได้ทุกคำสั่งซื้อ' : parts.join(' · ');
  }

  String _formatDate(DateTime date) {
    final String year = (date.year + 543).toString();
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '$day/$month/$year';
  }
}