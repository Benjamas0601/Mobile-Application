import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/image/image_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/store_model.dart';
import '../../../models/store_profile_draft.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/image_storage_provider.dart';
import '../../../providers/seller_catalog_provider.dart';
import '../../../widgets/state_views.dart';

/// Edits the fields of a store the signed-in seller owns.
///
/// Read-only fields (`ownerUid`, `ratingAvg`, `commissionRate`) have no control
/// here by design: they are written by the seed, the platform, or a Cloud
/// Function, and `firestore.rules` refuses an update that touches `ownerUid`
/// anyway. The form is the write half of the store the seller's product form
/// already treats as its parent.
class SellerStoreEditScreen extends ConsumerStatefulWidget {
  const SellerStoreEditScreen({super.key});

  @override
  ConsumerState<SellerStoreEditScreen> createState() =>
      _SellerStoreEditScreenState();
}

class _SellerStoreEditScreenState extends ConsumerState<SellerStoreEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _province = TextEditingController();
  final TextEditingController _region = TextEditingController();
  final TextEditingController _community = TextEditingController();
  final TextEditingController _cover = TextEditingController();
  final TextEditingController _logo = TextEditingController();

  String? _loadedStoreId;
  String? _error;
  bool _uploading = false;

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _name,
      _description,
      _province,
      _region,
      _community,
      _cover,
      _logo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Seeds the fields once per store.
  ///
  /// Keyed on the store id rather than run on every build, because re-seeding
  /// while the seller types would discard what they just typed — the same
  /// mistake the category/status dropdowns had with a missing key.
  void _seed(StoreModel store) {
    if (_loadedStoreId == store.id) return;
    _loadedStoreId = store.id;
    _name.text = store.name;
    _description.text = store.description;
    _province.text = store.province;
    _region.text = store.regionEnum?.value ?? store.region;
    _community.text = store.community;
    _cover.text = store.coverImageUrl;
    _logo.text = store.logoUrl ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final UserModel? user = ref.watch(authUserProvider).asData?.value;

    if (user == null || (!user.isSeller && !user.isAdmin)) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.navSellerStore)),
        body: const EmptyView(
          icon: Icons.lock_outline_rounded,
          title: AppStrings.errNotAuthorised,
        ),
      );
    }

    final storeState = ref.watch(myStoreProvider);
    if (storeState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.navSellerStore)),
        body: const LoadingView(),
      );
    }
    if (storeState.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.navSellerStore)),
        body: ErrorView(
          message: '${storeState.error}',
          onRetry: () => ref.invalidate(myStoreProvider),
        ),
      );
    }

    final StoreModel? store = storeState.asData?.value;
    if (store == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.navSellerStore)),
        body: const EmptyView(
          icon: Icons.storefront_outlined,
          title: AppStrings.sellerNoStoreTitle,
          body: AppStrings.sellerNoStoreHint,
        ),
      );
    }

    _seed(store);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.sellerStoreProfileTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: <Widget>[
            _textField(_name, AppStrings.sellerStoreNameLabel),
            _textField(
              _description,
              AppStrings.sellerStoreDescriptionLabel,
              maxLines: 4,
            ),
            _textField(_province, AppStrings.sellerStoreProvinceLabel),
            _regionField(),
            _textField(_community, AppStrings.sellerStoreCommunityLabel),
            const SizedBox(height: AppSpacing.sm),
            _imageField(
              controller: _cover,
              label: AppStrings.sellerStoreCoverLabel,
              folder: ImageUploadPolicy.folderForStoreCover(storeId: store.id),
            ),
            _imageField(
              controller: _logo,
              label: AppStrings.sellerStoreLogoLabel,
              folder: ImageUploadPolicy.folderForStoreLogo(storeId: store.id),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.danger,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _saveButton(store),
          ],
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        // Only the name is required; the rest of the store is still browsable
        // with a missing province or community.
        validator: label == AppStrings.sellerStoreNameLabel
            ? (String? value) => (value ?? '').trim().isEmpty
                  ? AppStrings.sellerStoreNameRequired
                  : null
            : null,
      ),
    );
  }

  /// Region as a fixed list of choices.
  ///
  /// A dropdown, not free text: `region` is a filter key shared with the
  /// customer-facing product grid, so a typo like "North" would silently drop
  /// every product of the store out of the northern filter. [ThaiRegion] is the
  /// single source of those values.
  Widget _regionField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DropdownButtonFormField<ThaiRegion>(
        initialValue: _currentRegion(),
        decoration: const InputDecoration(
          labelText: AppStrings.sellerStoreRegionLabel,
          border: OutlineInputBorder(),
        ),
        items: <DropdownMenuItem<ThaiRegion>>[
          for (final ThaiRegion r in ThaiRegion.values)
            DropdownMenuItem<ThaiRegion>(value: r, child: Text(r.label)),
        ],
        onChanged: (ThaiRegion? value) {
          if (value != null) _region.text = value.value;
        },
      ),
    );
  }

  /// The stored region if it is a known value, else the first option.
  ThaiRegion? _currentRegion() {
    final ThaiRegion? parsed = ThaiRegion.fromValue(_region.text.trim());
    return parsed ?? ThaiRegion.values.first;
  }

  Widget _imageField({
    required TextEditingController controller,
    required String label,
    required String folder,
  }) {
    final bool canUpload = ref.watch(cloudinaryConfiguredProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: label,
              hintText: AppStrings.imageUrlHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (_uploading)
            const Row(
              children: <Widget>[
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: AppSpacing.sm),
                Text(AppStrings.uploadingImage),
              ],
            )
          else ...<Widget>[
            OutlinedButton.icon(
              onPressed: canUpload
                  ? () => _upload(controller: controller, folder: folder)
                  : () => setState(() {
                      _error = ref.read(cloudinaryMissingConfigProvider) ?? '';
                    }),
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text(AppStrings.uploadFromDevice),
            ),
            if (!canUpload)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  AppStrings.imageFallbackHint,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.inkSubtle,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Uploads a picked image into [controller].
  ///
  /// The target is passed in rather than guessed afterwards: which field the
  /// seller last typed in says nothing about which button they pressed, and a
  /// logo that silently overwrote the cover URL would be very hard to notice.
  Future<void> _upload({
    required TextEditingController controller,
    required String folder,
  }) async {
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (file == null) return;
      if (mounted) setState(() => _uploading = true);
      final UploadedImage uploaded = await ref
          .read(imageStorageServiceProvider)
          .uploadImage(file: file, folder: folder);
      if (!mounted) return;
      setState(() {
        _uploading = false;
        controller.text = uploaded.url;
        _error = null;
      });
    } on ImageUploadException catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = e.message;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = '${AppStrings.uploadFailed}: $e';
      });
    }
  }

  Widget _saveButton(StoreModel store) {
    final bool busy = ref.watch(saveStoreProfileProvider);
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: busy ? null : () => _save(store),
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text(AppStrings.save),
      ),
    );
  }

  Future<void> _save(StoreModel store) async {
    if (!_formKey.currentState!.validate()) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final StoreProfileDraft draft = StoreProfileDraft(
      name: _name.text,
      description: _description.text,
      province: _province.text,
      region: _region.text,
      community: _community.text,
      coverImageUrl: _cover.text.trim(),
      logoUrl: _logo.text.trim(),
    );

    final bool ok = await ref
        .read(saveStoreProfileProvider.notifier)
        .save(store: store, draft: draft);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok ? AppStrings.sellerStoreSaved : AppStrings.sellerStoreSaveFailed,
        ),
      ),
    );
    if (ok && mounted) context.pop();
  }
}
