import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/image/image_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/category_model.dart';
import '../../../models/product_draft.dart';
import '../../../models/product_model.dart';
import '../../../models/store_model.dart';
import '../../../providers/catalog_provider.dart';
import '../../../providers/image_storage_provider.dart';
import '../../../providers/seller_catalog_provider.dart';
import '../../../widgets/design_system.dart';
import '../../../widgets/state_views.dart';

/// Create or edit one product, as the HTML design's four-step flow.
///
///   1. ข้อมูล   — name, price, category, province
///   2. รูปภาพ — photos; the first one is the cover
///   3. ตัวเลือก — variants with their own stock
///   4. เรื่องราว — the four-question product story
///
/// Create mode ([storeId]) and edit mode ([productId]) share the one form on
/// purpose, so the seller never learns two versions of "product". The draft can
/// be saved from any step — an OTOP seller frequently gets partway through and
/// comes back, and losing that would be the fastest way to lose them.
/// ฟอร์มเพิ่ม/แก้สินค้า 4 ขั้นตอน พร้อมบันทึกเป็นฉบับร่างได้ทุกขั้น
class ProductEditScreen extends ConsumerStatefulWidget {
  const ProductEditScreen({super.key, this.productId, this.storeId});

  /// Empty when creating a new product.
  final String? productId;

  /// The store to add the product to, when creating.
  final String? storeId;

  @override
  ConsumerState<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends ConsumerState<ProductEditScreen> {
  /// The four steps, in order. Kept as one list because the step bar, the
  /// "ขั้นตอนที่ N จาก 4" caption and the next/back logic all read from it —
  /// three copies of the step names is three chances to forget one.
  static const List<String> _steps = <String>[
    'ข้อมูล',
    'รูปภาพ',
    'ตัวเลือก',
    'เรื่องราว',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _storyCommunity = TextEditingController();
  final TextEditingController _storyIngredients = TextEditingController();
  final TextEditingController _storyMethod = TextEditingController();
  final TextEditingController _storyUniqueness = TextEditingController();

  List<String> _imageUrls = <String>[];
  List<VariantDraft> _variants = <VariantDraft>[];

  /// Stable per-row identity for the variants editor.
  ///
  /// A new variant has no stored id yet, so keying rows on index would make
  /// Flutter reuse a removed row's state (and its typed text) — this parallel
  /// list keeps each row a distinct widget keyed by object identity.
  List<Object> _variantKeys = <Object>[];
  String? _categoryId;
  ProductStatus _status = ProductStatus.draft;
  String? _error;

  int _step = 0;

  /// Set once the edit-form data has been copied into the controllers.
  bool _seeded = false;

  /// In create mode the product id is allocated up-front so uploads can live
  /// under `stores/{storeId}/products/{id}` before the doc exists.
  String? _newProductId;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _storyCommunity.dispose();
    _storyIngredients.dispose();
    _storyMethod.dispose();
    _storyUniqueness.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.productId != null && widget.productId!.isNotEmpty;

  String _productId() {
    if (_isEdit) return widget.productId!;
    return _newProductId ??= ref
        .read(sellerCatalogRepositoryProvider)
        .allocateProductId();
  }

  void _seedEdit(ProductModel product, List<ProductVariantModel> variants) {
    if (_seeded) return;
    _name.text = product.name;
    _description.text = product.description;
    _price.text = product.priceBaht.toString();
    _categoryId = product.categoryId;
    _status = product.status;
    _imageUrls = List<String>.of(product.imageUrls);
    _storyCommunity.text = product.story.community;
    _storyIngredients.text = product.story.ingredients;
    _storyMethod.text = product.story.productionMethod;
    _storyUniqueness.text = product.story.uniqueness;
    _variants = <VariantDraft>[
      for (final ProductVariantModel v in variants) VariantDraft.fromModel(v),
    ];
    _variantKeys = List<Object>.generate(_variants.length, (int _) => Object());
    _seeded = true;
  }

  @override
  Widget build(BuildContext context) {
    // Create mode: resolve the store from the id (falling back to the seller's
    // own store when navigated to without one).
    if (!_isEdit) {
      final storeState = ref.watch(myStoreProvider);
      if (widget.storeId != null && widget.storeId!.isNotEmpty) {
        final explicitStore = ref.watch(storeProvider(widget.storeId!));
        if (explicitStore.isLoading) return _scaffold(const LoadingView());
        if (explicitStore.hasError) {
          return _scaffold(
            ErrorView(
              message: 'โหลดร้านค้าไม่สำเร็จ',
              detail: '${explicitStore.error}',
              onRetry: () =>
                  ref.invalidate(storeProvider(widget.storeId!)),
            ),
          );
        }
        final StoreModel? store = explicitStore.value;
        if (store != null) return _form(store);
        return _scaffold(
          const EmptyView(
            icon: Icons.storefront_outlined,
            title: AppStrings.sellerNoStoreTitle,
            body: AppStrings.sellerNoStoreHint,
          ),
        );
      }

      // ไม่มี store ใน URL — ใช้ร้านของผู้ขายเอง เพื่อให้ฟอร์มพร้อมใช้ทันที
      if (storeState.isLoading) return _scaffold(const LoadingView());
      if (storeState.hasError) {
        return _scaffold(
          ErrorView(
            message: 'โหลดร้านค้าไม่สำเร็จ',
            detail: '${storeState.error}',
            onRetry: () => ref.invalidate(myStoreProvider),
          ),
        );
      }
      final StoreModel? myStore = storeState.value;
      if (myStore != null) return _form(myStore);
      return _scaffold(
        const EmptyView(
          icon: Icons.storefront_outlined,
          title: AppStrings.sellerNoStoreTitle,
          body: AppStrings.sellerNoStoreHint,
        ),
      );
    }

    // Edit mode: wait for the product and its variants, then seed the form
    // once. Re-seeding on every rebuild would fight the user's typing.
    final productState = ref.watch(productProvider(widget.productId!));
    final variantsState = ref.watch(
      productVariantsProvider(widget.productId!),
    );
    if (productState.isLoading || variantsState.isLoading) {
      return _scaffold(const LoadingView());
    }
    if (productState.hasError) {
      return _scaffold(
        ErrorView(
          detail: '${productState.error}',
          onRetry: () => ref.invalidate(productProvider(widget.productId!)),
        ),
      );
    }
    if (variantsState.hasError) {
      return _scaffold(
        ErrorView(
          message: 'โหลดตัวเลือกสินค้าไม่สำเร็จ',
          detail: '${variantsState.error}',
          onRetry: () =>
              ref.invalidate(productVariantsProvider(widget.productId!)),
        ),
      );
    }
    final ProductModel? product = productState.value;
    final List<ProductVariantModel>? variants = variantsState.value;
    if (product == null || variants == null) {
      return _scaffold(
        const EmptyView(
          icon: Icons.inventory_2_outlined,
          title: 'ไม่พบสินค้า',
          body: 'สินค้าถูกถูกลบไปแล้วหรือยังไม่เข้าสู่ระบบ',
        ),
      );
    }
    _seedEdit(product, variants);
    final storeState = ref.watch(storeProvider(product.storeId));
    if (storeState.isLoading) return _scaffold(const LoadingView());
    if (storeState.hasError) {
      return _scaffold(
        ErrorView(
          message: 'โหลดร้านค้าไม่สำเร็จ',
          detail: '${storeState.error}',
          onRetry: () => ref.invalidate(storeProvider(product.storeId)),
        ),
      );
    }
    final StoreModel? store = storeState.value;
    if (store == null) {
      return _scaffold(
        const EmptyView(
          icon: Icons.storefront_outlined,
          title: AppStrings.sellerNoStoreTitle,
          body: AppStrings.sellerNoStoreHint,
        ),
      );
    }
    return _form(store);
  }

  Widget _scaffold(Widget body) => Scaffold(
    appBar: AppBar(title: const Text(AppStrings.sellerEditProduct)),
    body: body,
  );

  Widget _form(StoreModel store) {
    final categories = ref.watch(categoriesProvider);
    final bool busy = ref.watch(saveProductProvider);
    final List<CategoryModel> categoryList =
        categories.asData?.value ?? const <CategoryModel>[];

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.sellerEditProduct)),
      body: Form(
        key: _formKey,
        child: Column(
          children: <Widget>[
            AppStepBar(steps: _steps, currentIndex: _step),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                children: <Widget>[
                  // Only the visible step is built. Building all four would mean
                  // four sets of text controllers fighting for focus, and the
                  // image grid would decode images the seller cannot see.
                  switch (_step) {
                    0 => _basicsStep(categoryList, categories.hasError, store),
                    1 => _imagesStep(store),
                    2 => _variantsStep(),
                    _ => _storyStep(),
                  },
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    InlineErrorBanner(message: _error!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _dock(store, busy),
    );
  }

  /// The bottom bar: step counter, next/back, and a draft save that is always
  /// available. The draft button is deliberately never disabled — losing
  /// progress is worse than publishing later.
  Widget _dock(StoreModel store, bool busy) {
    final bool isLast = _step == _steps.length - 1;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.cardGutter,
          AppSpacing.md,
          AppSpacing.cardGutter,
          AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'ขั้นตอนที่ ${_step + 1} จาก ${_steps.length}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (_step > 0)
                  TextButton(
                    onPressed: busy ? null : () => setState(() => _step--),
                    child: const Text('ย้อนกลับ'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              )
            else ...<Widget>[
              AppChunkyButton(
                label: isLast ? AppStrings.save : 'ขั้นตอนถัดไป',
                icon: isLast ? Icons.check_rounded : null,
                onPressed: () => _next(store, isLast: isLast),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppChunkyButton.outlined(
                label: 'บันทึกเป็นฉบับร่าง',
                height: 44,
                onPressed: () => _save(store, asDraft: true),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Advances a step, or saves on the last one.
  ///
  /// Each step has its own gate, and the gate is checked *before* moving so the
  /// seller is told what is missing while the offending field is still on
  /// screen. The form key only validates the fields currently mounted, so a
  /// step-local check is what makes "next" mean anything.
  void _next(StoreModel store, {required bool isLast}) {
    if (!_stepIsValid()) return;
    if (!isLast) {
      setState(() => _step++);
      return;
    }
    _save(store, asDraft: false);
  }

  bool _stepIsValid() {
    switch (_step) {
      case 0:
        // The description is optional, but name, price and category are not.
        // `validate()` only sees step 1's fields because that is all that is
        // mounted right now, which is exactly the gate we want here.
        return _formKey.currentState?.validate() ?? true;
      case 1:
        if (_imageUrls.isEmpty) {
          setState(() => _error = 'เพิ่มรูปอย่างน้อย 1 รูปก่อนไปขั้นตอนถัดไป');
          return false;
        }
        setState(() => _error = null);
        return true;
      default:
        return true;
    }
  }

  String? _saveError;

  /// The save gate. This cannot rely on `_formKey`, because only the visible
  /// step is mounted — validating from step 4 would find no fields at all and
  /// happily publish an unnamed product. So the basics are checked against
  /// their controllers instead, which works from any step.
  ///
  /// A draft needs a name, a price and a category — the same minimum the
  /// single-page form required, because a draft with no category cannot be
  /// listed anywhere. Publishing additionally needs an image, which step 2
  /// already enforced on the way past.
  bool _canSave({required bool asDraft}) {
    _saveError = null;

    if (_name.text.trim().isEmpty) {
      _saveError = 'กรุณากรอกชื่อสินค้าก่อนบันทึก';
      return false;
    }

    final int? price = int.tryParse(_price.text.trim());
    if (price == null || price < 0) {
      _saveError = AppStrings.errPriceInvalid;
      return false;
    }
    if (_categoryId == null || _categoryId!.isEmpty) {
      _saveError = AppStrings.errCategoryRequired;
      return false;
    }
    if (!asDraft &&
        _imageUrls.where((String u) => u.trim().isNotEmpty).isEmpty) {
      _saveError = 'เพิ่มรูปอย่างน้อย 1 รูปก่อนเผยแพร่';
      return false;
    }
    return true;
  }

  // --- Step 1: basics --------------------------------------------------------

  Widget _basicsStep(
    List<CategoryModel> categories,
    bool categoriesFailed,
    StoreModel store,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const AppSectionLabel('ชื่อสินค้า'),
        TextFormField(
          controller: _name,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: AppStrings.productNameHint,
            border: _inputBorder,
          ),
          validator: (String? v) =>
              (v == null || v.trim().isEmpty) ? AppStrings.errRequired : null,
        ),
        const AppSectionLabel('ราคา (บาท)'),
        TextFormField(
          controller: _price,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '250', border: _inputBorder),
          validator: (String? v) {
            if (v == null || v.trim().isEmpty) return AppStrings.errRequired;
            final int? amount = int.tryParse(v.trim());
            if (amount == null || amount < 0) return AppStrings.errPriceInvalid;
            return null;
          },
        ),
        const AppSectionLabel('หมวดสินค้า'),
        _categoryDropdown(categories, categoriesFailed),
        const AppSectionLabel('จังหวัดที่ผลิต'),
        // Province is not editable per product — it is copied from the store on
        // write (`SellerCatalogRepository._productData`), so showing the store's
        // province read-only is honest rather than a field that silently resets.
        _readonlyValue(store.province.isEmpty ? '-' : store.province),
        const AppSectionLabel('รายละเอียด'),
        TextFormField(
          controller: _description,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: AppStrings.productDescriptionHint,
            border: _inputBorder,
          ),
        ),
        const AppSectionLabel('สถานะ'),
        DropdownButtonFormField<ProductStatus>(
          key: ValueKey<Object?>('seller-status-$_status'),
          initialValue: _status,
          items: <DropdownMenuItem<ProductStatus>>[
            for (final ProductStatus status in ProductStatus.values)
              DropdownMenuItem<ProductStatus>(
                value: status,
                child: Text(status.label),
              ),
          ],
          onChanged: (ProductStatus? value) {
            if (value != null) setState(() => _status = value);
          },
        ),
      ],
    );
  }

  OutlineInputBorder get _inputBorder => const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );

  Widget _readonlyValue(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Text(value, style: AppTextStyles.bodyMedium),
    );
  }

  Widget _categoryDropdown(
    List<CategoryModel> categories,
    bool categoriesFailed,
  ) {
    return DropdownButtonFormField<String>(
      // Recreate the form field when the seeded category arrives (edit mode):
      // a DropdownButtonFormField latches its value in initState, so without a
      // value-key the field would stay null while the button already shows the
      // category — and validation would then reject a perfectly good product.
      key: ValueKey<String?>('seller-category-$_categoryId'),
      initialValue: _categoryId,
      isExpanded: true,
      items: <DropdownMenuItem<String>>[
        for (final CategoryModel category in categories)
          DropdownMenuItem<String>(
            value: category.id,
            child: Text(category.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (String? value) => setState(() => _categoryId = value),
      validator: (String? v) {
        if (categoriesFailed) return AppStrings.errorBody;
        return (v == null || v.isEmpty) ? AppStrings.errCategoryRequired : null;
      },
    );
  }

  // --- Step 2: images -------------------------------------------------------

  Widget _imagesStep(StoreModel store) {
    final bool canUpload = ref.watch(cloudinaryConfiguredProvider);
    final String? missingConfig = ref.watch(cloudinaryMissingConfigProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const AppSectionLabel('รูปสินค้า · รูปแรกเป็นปก'),
        if (_imageUrls.isEmpty)
          const AppHint('ยังไม่มีรูป กดเพิ่มรูปด้านล่างเพื่อเริ่ม')
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (int i = 0; i < _imageUrls.length; i++)
                _imageThumb(
                  url: _imageUrls[i],
                  isCover: i == 0,
                  onSetCover: () => setState(() {
                    // Re-insert at the front rather than swap in place: the cover
                    // is the head of `imageUrls`, so moving it there is what
                    // `ProductModel.coverImageUrl` actually reads.
                    final String picked = _imageUrls.removeAt(i);
                    _imageUrls.insert(0, picked);
                  }),
                  onRemove: () => setState(() => _imageUrls.removeAt(i)),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        AppChip(
          label: 'เพิ่มรูป',
          icon: Icons.add_photo_alternate_outlined,
          selected: true,
          onTap: () => _showImageOptions(store, canUpload, missingConfig),
        ),
        const AppHint('แตะรูปเพื่อตั้งเป็นปก · แตะ ✕ เพื่อลบ'),
        if (!canUpload)
          AppHint('$missingConfig\n${AppStrings.imageFallbackHint}'),
      ],
    );
  }

  Future<void> _showImageOptions(
    StoreModel store,
    bool canUpload,
    String? missingConfig,
  ) async {
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: AppSpacing.md),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text(AppStrings.addImageByUrl),
              onTap: () => Navigator.of(sheetContext).pop('url'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text(AppStrings.uploadFromDevice),
              subtitle: canUpload
                  ? null
                  : Text(missingConfig ?? AppStrings.imageFallbackHint),
              onTap: () => Navigator.of(sheetContext).pop('device'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) return;
    if (choice == 'url') {
      await _addImageByUrl();
    } else {
      await _uploadFromDevice(store);
    }
  }

  Widget _imageThumb({
    required String url,
    required bool isCover,
    required VoidCallback onSetCover,
    required VoidCallback onRemove,
  }) {
    return Semantics(
      label: isCover ? 'รูปปกสินค้า' : 'รูปสินค้า',
      button: true,
      onTap: onSetCover,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          GestureDetector(
            onTap: onSetCover,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: isCover ? AppColors.primary : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg - 2.5),
                child: CachedNetworkImage(
                  imageUrl: url,
                  width: 84,
                  height: 84,
                  fit: BoxFit.cover,
                  errorWidget: (BuildContext context, String _, Object _) =>
                      Container(
                        width: 84,
                        height: 84,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                ),
              ),
            ),
          ),
          if (isCover)
            Positioned(
              left: 0,
              bottom: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Text(
                  'ปก',
                  style: TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Positioned(
            top: -6,
            right: -6,
            child: Semantics(
              label: 'ลบรูปนี้',
              button: true,
              child: InkWell(
                onTap: onRemove,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.clayDark,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 3: variants -----------------------------------------------------

  Widget _variantsStep() {
    final int total = _variants.fold<int>(
      0,
      (int s, VariantDraft v) => s + (v.stock < 0 ? 0 : v.stock),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const AppSectionLabel('ตัวเลือกสินค้า · สต็อกแยกกันทุกตัวเลือก'),
        if (_variants.isEmpty)
          const AppHint(
            'ยังไม่มีตัวเลือก สินค้าจะถูกขายเป็นแบบเดียว · '
            'กดเพิ่มตัวเลือกด้านล่างถ้าสีหรือขนาดต่างกัน',
          )
        else
          for (int i = 0; i < _variants.length; i++) ...<Widget>[
            _VariantRow(
              key: ValueKey<Object>(_variantKeys[i]),
              index: i,
              initial: _variants[i],
              onChanged: (VariantDraft draft) =>
                  setState(() => _variants[i] = draft),
              onRemove: () => setState(() {
                _variants.removeAt(i);
                _variantKeys.removeAt(i);
              }),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        const SizedBox(height: AppSpacing.xs),
        AppChip(
          label: AppStrings.addVariant,
          icon: Icons.add_rounded,
          selected: true,
          onTap: () => setState(() {
            _variants = <VariantDraft>[
              ..._variants,
              const VariantDraft(name: ''),
            ];
            _variantKeys = <Object>[..._variantKeys, Object()];
          }),
        ),
        if (_variants.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.cardGutter,
              vertical: AppSpacing.md,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  AppStrings.stockTotalLabel,
                  style: AppTextStyles.labelLarge,
                ),
                Text(
                  '$total ชิ้น',
                  style: AppTextStyles.priceMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        // The design spells out what the dashboard will do with a low number,
        // because a seller setting stock to 2 should know that is a warning.
        if (_variants.any((VariantDraft v) => v.stock <= lowStockThreshold))
          const AppHint(
            'สต็อกตัวเลือกไหนเหลือไม่ถึง 3 ชิ้น ระบบจะเตือนที่แดชบอร์ดผู้ขายให้เติมสต็อก',
            isWarning: true,
          ),
      ],
    );
  }

  // --- Step 4: story --------------------------------------------------------

  Widget _storyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const AppSectionLabel('Product Story'),
        _storyField(AppStrings.community, _storyCommunity),
        _storyField(AppStrings.ingredients, _storyIngredients),
        _storyField(AppStrings.productionMethod, _storyMethod),
        _storyField(AppStrings.uniqueness, _storyUniqueness),
        const AppHint(
          'เรื่องราวช่วยให้ลูกค้าเข้าใจที่มาและตัดสินใจซื้อง่ายขึ้น',
        ),
      ],
    );
  }

  /// One story question as a labelled block: the question is the heading, the
  /// answer is the field. This mirrors the design's `dt`/`dd` definition list,
  /// which is why it is not a plain "Product Story" textarea.
  Widget _storyField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.cardGutter,
        0,
        AppSpacing.cardGutter,
        AppSpacing.md,
      ),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'ชุมชนบ้าน…',
                border: _inputBorder,
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Actions --------------------------------------------------------------

  Future<void> _addImageByUrl() async {
    final String? url = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => const _UrlPromptDialog(),
    );
    if (url == null || url.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _imageUrls.add(url);
      _error = null;
    });
  }

  Future<void> _uploadFromDevice(StoreModel store) async {
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (file == null) return;
      final UploadedImage uploaded = await ref
          .read(imageStorageServiceProvider)
          .uploadImage(
            file: file,
            folder: ImageUploadPolicy.folderForProduct(
              storeId: store.id,
              productId: _productId(),
            ),
          );
      if (!mounted) return;
      setState(() {
        _imageUrls.add(uploaded.url);
        _error = null;
      });
    } on ImageUploadException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'เลือกหรืออัปโหลดรูปไม่สำเร็จ: $e');
    }
  }

  /// Writes the product. [asDraft] forces `draft` status, which is what the
  /// always-available dock button does; the last step publishes instead.
  Future<void> _save(StoreModel store, {required bool asDraft}) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    if (!_canSave(asDraft: asDraft)) {
      // Send the seller back to the step that is wrong, so the field they need
      // to fix is on screen instead of behind a step tap.
      setState(() {
        _step = 0;
        _error = _saveError;
      });
      return;
    }

    final int? price = int.tryParse(_price.text.trim());
    if (price == null || price < 0) {
      setState(() {
        _error = AppStrings.errPriceInvalid;
        _step = 0;
      });
      return;
    }

    final ProductDraft draft = ProductDraft(
      name: _name.text.trim(),
      description: _description.text.trim(),
      price: price.toDouble(),
      categoryId: _categoryId ?? '',
      imageUrls: _imageUrls.where((String u) => u.trim().isNotEmpty).toList(),
      status: asDraft ? ProductStatus.draft : _status,
      story: ProductStory(
        community: _storyCommunity.text,
        ingredients: _storyIngredients.text,
        productionMethod: _storyMethod.text,
        uniqueness: _storyUniqueness.text,
      ),
      variants: _variants,
    );

    final ProductModel? existing = _isEdit
        ? ref.read(productProvider(widget.productId!)).asData?.value
        : null;

    final String? id = await ref
        .read(saveProductProvider.notifier)
        .save(
          productId: _productId(),
          store: store,
          draft: draft,
          existing: existing,
        );
    if (!mounted) return;

    if (id == null) {
      setState(() => _error = AppStrings.saveProductFailed);
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          asDraft
              ? 'บันทึกเป็นฉบับร่างแล้ว กลับมาแก้ต่อได้ทุกเมื่อ'
              : AppStrings.productSaved,
        ),
      ),
    );

    // Guarded because the screen can be the app root (deep link straight into
    // the form), where popping would leave a blank frame behind.
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }
}

/// Asks for an image URL.
///
/// The controller belongs to this widget rather than to `_addImageByUrl`: the
/// dialog's exit animation outlives `showDialog`'s future, so a controller
/// disposed when the future completed was still attached to a `TextField` that
/// rebuilt during the fade-out.
class _UrlPromptDialog extends StatefulWidget {
  const _UrlPromptDialog();

  @override
  State<_UrlPromptDialog> createState() => _UrlPromptDialogState();
}

class _UrlPromptDialogState extends State<_UrlPromptDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.addImageByUrl),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.url,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: AppStrings.imageUrlHint,
          border: OutlineInputBorder(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text(AppStrings.addImage),
        ),
      ],
    );
  }
}

/// One editable variant row: a colour swatch, the name, and a −/+ stock stepper.
///
/// The stepper replaces the stock text box because the design's row is built
/// around it and because stock is a small, bounded number that a seller
/// adjusts by single units — typing it invites typos like 200 for 2. The text
/// fields for name/colour/size stay as typed inputs, since those are free text.
class _VariantRow extends StatefulWidget {
  const _VariantRow({
    super.key,
    required this.index,
    required this.initial,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final VariantDraft initial;
  final ValueChanged<VariantDraft> onChanged;
  final VoidCallback onRemove;

  @override
  State<_VariantRow> createState() => _VariantRowState();
}

class _VariantRowState extends State<_VariantRow> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial.name,
  );
  late final TextEditingController _color = TextEditingController(
    text: widget.initial.color ?? '',
  );
  late final TextEditingController _size = TextEditingController(
    text: widget.initial.size ?? '',
  );
  late int _stock = widget.initial.stock;

  @override
  void dispose() {
    _name.dispose();
    _color.dispose();
    _size.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      VariantDraft(
        id: widget.initial.id,
        name: _name.text.trim(),
        color: _color.text.trim().isEmpty ? null : _color.text.trim(),
        size: _size.text.trim().isEmpty ? null : _size.text.trim(),
        priceDelta: widget.initial.priceDelta,
        stock: _stock,
        imageUrl: widget.initial.imageUrl,
      ),
    );
  }

  void _bumpStock(int delta) {
    setState(() => _stock = (_stock + delta).clamp(0, 9999999));
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final bool low = _stock > 0 && _stock <= lowStockThreshold;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.cardGutter),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                // A colour swatch beside the name, so a row is recognisable
                // without reading it.
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: _swatchColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: _name,
                    onChanged: (String _) => _emit(),
                    decoration: InputDecoration(
                      hintText: AppStrings.variantNameExample,
                      border: _rowBorder,
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: AppStrings.removeVariant,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.clayDark,
                  ),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _color,
                    // The swatch beside the name reads `_color`, so this needs a
                    // repaint as well as an emit — and it must emit, or a
                    // colour-only edit never reaches the parent's draft and is
                    // silently dropped on save.
                    onChanged: (String _) {
                      setState(() {});
                      _emit();
                    },
                    decoration: _rowDecoration(AppStrings.variantColorHint),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: _size,
                    onChanged: (String _) => _emit(),
                    decoration: _rowDecoration(AppStrings.variantSizeHint),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                _stepButton(
                  key: ValueKey<String>('stock-down-${widget.index}'),
                  icon: Icons.remove_rounded,
                  label: 'ลดสต็อก${widget.initial.name.trim()}',
                  onPressed: _stock <= 0 ? null : () => _bumpStock(-1),
                ),
                Container(
                  width: 52,
                  alignment: Alignment.center,
                  child: Text(
                    '$_stock',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: low ? AppColors.clayDark : null,
                    ),
                  ),
                ),
                _stepButton(
                  key: ValueKey<String>('stock-up-${widget.index}'),
                  icon: Icons.add_rounded,
                  label: 'เพิ่มสต็อก${widget.initial.name.trim()}',
                  onPressed: () => _bumpStock(1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Maps a Thai/English colour name to a swatch. A miss falls back to indigo
  /// rather than transparent, so the swatch is never an invisible hole.
  Color get _swatchColor => _swatchFor(_color.text.trim());

  static Color _swatchFor(String name) {
    const Map<String, Color> known = <String, Color>{
      'สีคราม': AppColors.regionNorth,
      'สีน้ำเงิน': AppColors.primary,
      'คราม': AppColors.regionNorth,
      'น้ำเงิน': AppColors.primary,
      'indigo': AppColors.primary,
      'blue': AppColors.primary,
      'ขมิ้น': AppColors.accentDark,
      'แดง': AppColors.clay,
      'red': AppColors.clay,
      'เขียว': AppColors.regionWest,
      'green': AppColors.regionWest,
      'ขาว': Color(0xFFFFFFFF),
      'ดำ': AppColors.ink,
      'เทา': AppColors.inkMuted,
    };
    return known[name.toLowerCase()] ?? AppColors.primary;
  }

  /// A 44px square stepper button — the min tap target, not a 32px icon
  /// button, because stock is adjusted one unit at a time.
  Widget _stepButton({
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final bool enabled = onPressed != null;
    return Semantics(
      key: key,
      button: true,
      enabled: enabled,
      label: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled
                ? Theme.of(context).colorScheme.surface
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: enabled
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }

  static final OutlineInputBorder _rowBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
  );

  InputDecoration _rowDecoration(String label) =>
      InputDecoration(labelText: label, border: _rowBorder, isDense: true);
}
