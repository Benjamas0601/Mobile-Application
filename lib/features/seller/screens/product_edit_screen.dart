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
import '../../../widgets/state_views.dart';

/// Create or edit one product for one of the seller's stores.
///
/// Create mode ([StoreModel] by id) and edit mode ([productId]) share the same
/// form on purpose, so the seller never learns two versions of "product".
/// Images can come from a URL or from the device — the device path goes through
/// [ImageStorageService] so it can be swapped to Firebase Storage later.
/// ฟอร์มสร้างหรือแก้สินค้า พร้อม variant รูปภาพ และสต็อกของแต่ละแบบ
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
    return _newProductId ??=
        ref.read(sellerCatalogRepositoryProvider).allocateProductId();
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
    // Create mode: resolve the store from the id (falling back to the first
    // of the seller's stores when navigated to without one).
    if (!_isEdit) {
      final storeState = ref.watch(myStoreProvider);
      final store = ref
          .watch(storeProvider(widget.storeId ?? ''))
          .asData
          ?.value;

      if (store != null) return _form(store);
      final StoreModel? myStore = storeState.asData?.value;
      if (widget.storeId == null && myStore != null) {
        // No explicit store in the URL, but the seller has one — fall back to
        // it so the form is immediately usable.
        return _redirectStoreForm(myStore);
      }
      if (storeState.isLoading) {
        return _scaffold(const LoadingView());
      }
      if (storeState.hasError) {
        return _scaffold(
          ErrorView(
            message: '${storeState.error}',
            onRetry: () => ref.invalidate(myStoreProvider),
          ),
        );
      }
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
    final ProductModel? product = productState.asData?.value;
    final variants = ref
        .watch(productVariantsProvider(widget.productId!))
        .asData
        ?.value;
    if (product != null && variants != null) {
      _seedEdit(product, variants);
      final store = ref.watch(storeProvider(product.storeId)).asData?.value;
      if (store == null) {
        return _scaffold(const LoadingView());
      }
      return _form(store);
    }
    if (productState.isLoading) return _scaffold(const LoadingView());
    return _scaffold(
      ErrorView(
        message: '${productState.error}',
        onRetry: () => ref.invalidate(productProvider(widget.productId!)),
      ),
    );
  }

  /// Re-watches the concrete first store id so `storeProvider(storeId)`
  /// settles on it.
  Widget _redirectStoreForm(StoreModel store) => _form(store);

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
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: <Widget>[
            _basicCard(categoryList, categories.hasError),
            const SizedBox(height: AppSpacing.xl),
            _imagesCard(store),
            const SizedBox(height: AppSpacing.xl),
            _storyCard(),
            const SizedBox(height: AppSpacing.xl),
            _variantsCard(),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              InlineErrorBanner(message: _error!),
            ],
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : () => _save(store),
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isEdit
                          ? '${AppStrings.save} ${store.name}'
                          : AppStrings.sellerAddProduct,
                      style: AppTextStyles.labelLarge,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Sections -------------------------------------------------------------

  Widget _basicCard(
    List<CategoryModel> categories,
    bool categoriesFailed,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _sectionTitle(AppStrings.productNameLabel),
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
            const SizedBox(height: AppSpacing.md),
            _sectionTitle(AppStrings.productDescriptionLabel),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: AppStrings.productDescriptionHint,
                border: _inputBorder,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _sectionTitle(AppStrings.productPriceLabel),
                ),
                Expanded(child: _sectionTitle(AppStrings.productCategoryLabel)),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '1290',
                      border: _inputBorder,
                    ),
                    validator: (String? v) {
                      if (v == null || v.trim().isEmpty) {
                        return AppStrings.errRequired;
                      }
                      final int? amount = int.tryParse(v.trim());
                      if (amount == null || amount < 0) {
                        return AppStrings.errPriceInvalid;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _categoryDropdown(
                    categories,
                    categoriesFailed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _sectionTitle(AppStrings.productStatusLabel),
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
        ),
      ),
    );
  }

OutlineInputBorder get _inputBorder => const OutlineInputBorder(
  borderRadius: AppRadius.cardRadius,
);

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
            child: Text(
              category.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (String? value) => setState(() => _categoryId = value),
      validator: (String? v) {
        if (categoriesFailed) return AppStrings.errorBody;
        return (v == null || v.isEmpty) ? AppStrings.errCategoryRequired : null;
      },
    );
  }

  Widget _imagesCard(StoreModel store) {
    final bool canUpload = ref.watch(cloudinaryConfiguredProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _sectionTitle(AppStrings.productImages),
            const SizedBox(height: AppSpacing.sm),
            if (_imageUrls.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  AppStrings.productImagesEmptyHint,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              )
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (int i = 0; i < _imageUrls.length; i++)
                    _imageThumb(_imageUrls[i], () {
                      setState(() => _imageUrls.removeAt(i));
                    }),
                ],
              ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => _addImageByUrl(),
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: const Text(AppStrings.addImageByUrl),
                ),
                OutlinedButton.icon(
                  onPressed: canUpload
                      ? () => _uploadFromDevice(store)
                      : () => setState(() {
                          _error =
                              ref.read(cloudinaryMissingConfigProvider) ?? '';
                        }),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text(AppStrings.uploadFromDevice),
                ),
              ],
            ),
            if (!canUpload) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${ref.watch(cloudinaryMissingConfigProvider) ?? ''}\n${AppStrings.imageFallbackHint}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.inkSubtle,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _imageThumb(String url, VoidCallback onRemove) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        ClipRRect(
          borderRadius: AppRadius.cardRadius,
          child: CachedNetworkImage(
            imageUrl: url,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorWidget: (BuildContext context, String _, Object _) =>
                Container(
                  width: 72,
                  height: 72,
                  color: AppColors.surfaceMuted,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.inkSubtle,
                  ),
                ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _storyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _sectionTitle(AppStrings.productStory),
            const SizedBox(height: AppSpacing.sm),
            _storyField(AppStrings.community, _storyCommunity, 2),
            const SizedBox(height: AppSpacing.md),
            _storyField(AppStrings.ingredients, _storyIngredients, 2),
            const SizedBox(height: AppSpacing.md),
            _storyField(AppStrings.productionMethod, _storyMethod, 3),
            const SizedBox(height: AppSpacing.md),
            _storyField(AppStrings.uniqueness, _storyUniqueness, 3),
          ],
        ),
      ),
    );
  }

  Widget _storyField(String label, TextEditingController controller, int lines) {
    return TextFormField(
      controller: controller,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        border: _inputBorder,
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _variantsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _sectionTitle(AppStrings.variantsSection),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              AppStrings.variantsSectionHint,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.md),
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
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  _variants = <VariantDraft>[
                    ..._variants,
                    const VariantDraft(name: ''),
                  ];
                  _variantKeys = <Object>[..._variantKeys, Object()];
                }),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(AppStrings.addVariant),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  AppStrings.stockTotalLabel,
                  style: AppTextStyles.labelLarge,
                ),
                Text(
                  '${_variants.fold<int>(0, (int s, VariantDraft v) => s + (v.stock < 0 ? 0 : v.stock))} ชิ้น',
                  style: AppTextStyles.priceMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text(title, style: AppTextStyles.labelMedium),
  );

  // --- Actions --------------------------------------------------------------

  Future<void> _addImageByUrl() async {
    final TextEditingController controller = TextEditingController();
    final String? url = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text(AppStrings.addImageByUrl),
        content: TextField(
          controller: controller,
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
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text(AppStrings.addImage),
          ),
        ],
      ),
    );
    controller.dispose();
    if (url == null || url.isEmpty) return;
    if (!mounted) return;
    setState(() => _imageUrls.add(url));
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

  Future<void> _save(StoreModel store) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (!_formKey.currentState!.validate()) return;

    final int? price = int.tryParse(_price.text.trim());
    if (price == null || price < 0) {
      setState(() => _error = AppStrings.errPriceInvalid);
      return;
    }

    final ProductDraft draft = ProductDraft(
      name: _name.text.trim(),
      description: _description.text.trim(),
      price: price.toDouble(),
      categoryId: _categoryId ?? '',
      imageUrls: _imageUrls.where((String u) => u.trim().isNotEmpty).toList(),
      status: _status,
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

    final String? id = await ref.read(saveProductProvider.notifier).save(
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
    messenger.showSnackBar(const SnackBar(content: Text(AppStrings.productSaved)));
    Navigator.of(context).pop();
  }
}

/// One editable variant row. Owns its text controllers so typing stays smooth
/// while the parent keeps the authoritative [VariantDraft] list.
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
  late final TextEditingController _delta = TextEditingController(
    text: widget.initial.priceDelta == 0 ? '' : widget.initial.priceDelta.round().toString(),
  );
  late final TextEditingController _stock = TextEditingController(
    text: widget.initial.stock == 0 ? '' : '${widget.initial.stock}',
  );

  @override
  void dispose() {
    _name.dispose();
    _color.dispose();
    _size.dispose();
    _delta.dispose();
    _stock.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      VariantDraft(
        id: widget.initial.id,
        name: _name.text.trim(),
        color: _color.text.trim().isEmpty ? null : _color.text.trim(),
        size: _size.text.trim().isEmpty ? null : _size.text.trim(),
        priceDelta: (double.tryParse(_delta.text.trim()) ?? 0)
            .clamp(0, 9999999)
            .toDouble(),
        stock: (int.tryParse(_stock.text.trim()) ?? 0).clamp(0, 9999999),
        imageUrl: widget.initial.imageUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('${AppStrings.variantNameHint} ${widget.index + 1}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: AppStrings.removeVariant,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.danger,
                ),
                onPressed: widget.onRemove,
              ),
            ],
          ),
          TextField(
            controller: _name,
            onChanged: (String _) => _emit(),
            decoration: InputDecoration(
              hintText: AppStrings.variantNameExample,
              border: _rowBorder,
              isDense: true,
            ),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _color,
                  onChanged: (String _) => _emit(),
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
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _delta,
                  keyboardType: TextInputType.number,
                  onChanged: (String _) => _emit(),
                  decoration:
                      _rowDecoration(AppStrings.variantPriceDeltaHint),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _stock,
                  keyboardType: TextInputType.number,
                  onChanged: (String _) => _emit(),
                  decoration: _rowDecoration(AppStrings.variantStockHint),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static final OutlineInputBorder _rowBorder = OutlineInputBorder(
    borderRadius: AppRadius.cardRadius,
  );

  InputDecoration _rowDecoration(String label) => InputDecoration(
    labelText: label,
    border: _rowBorder,
    isDense: true,
  );
}