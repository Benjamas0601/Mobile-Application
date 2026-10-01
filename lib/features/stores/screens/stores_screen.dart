import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/store_model.dart';
import '../../../providers/catalog_provider.dart';
import '../../../widgets/state_views.dart';

/// Store directory. Public read, so a guest can see who they would be buying
/// from before deciding to make an account.
/// แสดงไดเรกทอรีร้านที่ guest เปิดดูได้โดยไม่ต้องล็อกอิน
class StoresScreen extends ConsumerWidget {
  const StoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<StoreModel>> stores = ref.watch(storesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.stores)),
      body: Builder(
        builder: (BuildContext context) {
          if (stores.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (stores.hasError) {
            return ErrorView(
              message: AppStrings.loadStoresFailed,
              onRetry: () => ref.invalidate(storesProvider),
            );
          }
          final List<StoreModel> items =
              stores.asData?.value ?? const <StoreModel>[];
          if (items.isEmpty) {
            return const EmptyView(
              icon: Icons.storefront_outlined,
              title: AppStrings.noStores,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            itemCount: items.length,
            separatorBuilder: (BuildContext context, int _) =>
                const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) =>
                _StoreCard(store: items[index]),
          );
        },
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store});

  final StoreModel store;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                store.name.characters.first,
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          store.name,
                          style: AppTextStyles.bodyLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (store.otopCertified) ...<Widget>[
                        const SizedBox(width: AppSpacing.xs),
                        const _OtopBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${store.community} · ${store.province}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtopBadge extends StatelessWidget {
  const _OtopBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Text(
        'OTOP',
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent),
      ),
    );
  }
}
