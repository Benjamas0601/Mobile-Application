import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:thai_otop_marketplace/core/constants/app_enums.dart';
import 'package:thai_otop_marketplace/core/constants/app_strings.dart';
import 'package:thai_otop_marketplace/features/seller/screens/product_edit_screen.dart';
import 'package:thai_otop_marketplace/features/seller/screens/seller_product_list_screen.dart';
import 'package:thai_otop_marketplace/models/category_model.dart';
import 'package:thai_otop_marketplace/models/product_draft.dart';
import 'package:thai_otop_marketplace/models/product_model.dart';
import 'package:thai_otop_marketplace/models/store_model.dart';
import 'package:thai_otop_marketplace/models/store_profile_draft.dart';
import 'package:thai_otop_marketplace/models/user_model.dart';
import 'package:thai_otop_marketplace/providers/auth_provider.dart';
import 'package:thai_otop_marketplace/providers/catalog_provider.dart';
import 'package:thai_otop_marketplace/providers/seller_catalog_provider.dart';
import 'package:thai_otop_marketplace/repositories/seller_catalog_repository.dart';
import 'package:thai_otop_marketplace/widgets/design_system.dart';

const UserModel _seller = UserModel(
  uid: 's1',
  displayName: 'ผู้ขาย',
  email: 'seller.north@example.com',
  roles: <UserRole>[UserRole.seller],
);

const UserModel _customer = UserModel(
  uid: 'u1',
  displayName: 'สมชาย ใจดี',
  email: 'customer@example.com',
);

const StoreModel _store = StoreModel(
  id: 's1',
  ownerUid: 'o1',
  name: 'ร้านชิงไทร',
  province: 'เชียงใหม่',
  region: 'north',
  community: 'บ้านมะคำ',
  description: 'ร้านขายของฝากจากลำพูน',
  coverImageUrl: '',
);

const CategoryModel _category = CategoryModel(
  id: 'c1',
  name: 'ของฝาก',
  slug: 'souvenir',
  icon: '🎁',
  sortOrder: 1,
);

const ProductModel _product = ProductModel(
  id: 'p1',
  storeId: 's1',
  name: 'ผ้าไหมบ้านชิงไทร',
  description: '',
  price: 1290,
  categoryId: 'c1',
  province: 'เชียงใหม่',
  region: 'north',
  imageUrls: <String>[],
  stockTotal: 5,
  status: ProductStatus.draft,
  story: ProductStory(),
);

/// Records what the seller screens asked the repository to do, without a
/// Firestore, mirroring the order test's fake.
class _FakeSellerCatalogRepository implements SellerCatalogRepository {
  final List<String> created = <String>[];
  final List<String> updated = <String>[];
  final List<String> deleted = <String>[];

  /// Store profile writes, captured so the controller tests can assert what
  /// the form asked for without a Firestore.
  final List<({String storeId, StoreProfileDraft draft})> storeProfileWrites =
      <({String storeId, StoreProfileDraft draft})>[];

  /// When set, `createProduct` parks until released — the busy-guard test
  /// fires a second save while the first is mid-flight.
  Completer<void>? holdCreate;

  /// Same, for the store profile write.
  Completer<void>? holdStoreProfile;

  /// When set, the next write throws (a denied permission, a quota error).
  Object? failWith;

  List<StoreModel> stores = <StoreModel>[];
  List<ProductModel> products = <ProductModel>[];
  Map<String, List<ProductVariantModel>> variantsByProduct =
      <String, List<ProductVariantModel>>{};
  int _allocated = 0;

  StoreModel? lastCreateStore;
  ProductDraft? lastCreateDraft;
  ProductModel? lastUpdatedExisting;
  ProductDraft? lastUpdateDraft;

  @override
  String allocateProductId() => 'new-p${++_allocated}';

  @override
  Future<StoreModel?> getMyStore() async =>
      stores.isEmpty ? null : stores.first;

  @override
  Future<List<StoreModel>> listMyStores() async => stores;

  @override
  Future<List<ProductModel>> listMyProducts(String storeId) async =>
      products.where((ProductModel p) => p.storeId == storeId).toList();

  @override
  Future<List<ProductVariantModel>> listVariants(String productId) async =>
      variantsByProduct[productId] ?? const <ProductVariantModel>[];

  @override
  Future<String> createProduct({
    required String productId,
    required StoreModel store,
    required ProductDraft draft,
  }) async {
    if (holdCreate != null) await holdCreate!.future;
    if (failWith != null) throw failWith!;
    lastCreateStore = store;
    lastCreateDraft = draft;
    created.add(productId);
    return productId;
  }

  @override
  Future<void> updateProduct({
    required ProductModel existing,
    required ProductDraft draft,
  }) async {
    if (failWith != null) throw failWith!;
    lastUpdatedExisting = existing;
    lastUpdateDraft = draft;
    updated.add(existing.id);
  }

  @override
  Future<void> deleteProduct(String productId) async {
    if (failWith != null) throw failWith!;
    deleted.add(productId);
  }

  @override
  Future<void> updateStoreProfile({
    required StoreModel store,
    required StoreProfileDraft draft,
  }) async {
    if (failWith != null) throw failWith!;
    if (holdStoreProfile != null) await holdStoreProfile!.future;
    storeProfileWrites.add((storeId: store.id, draft: draft));
  }
}

ProviderContainer _container(
  _FakeSellerCatalogRepository repo, {
  UserModel user = _seller,
}) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      authUserProvider.overrideWith(
        (Ref ref) => Stream<UserModel?>.value(user),
      ),
      sellerCatalogRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

ProviderContainer _editContainer(
  _FakeSellerCatalogRepository repo, {
  UserModel user = _seller,
}) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      authUserProvider.overrideWith(
        (Ref ref) => Stream<UserModel?>.value(user),
      ),
      sellerCatalogRepositoryProvider.overrideWithValue(repo),
      storeProvider.overrideWith((Ref ref, String id) async => _store),
      categoriesProvider.overrideWith(
        (Ref ref) async => const <CategoryModel>[_category],
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Pumps the seller list inside a router-less app (the screen only navigates
/// when a seller taps something).
Future<void> _pumpList(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SellerProductListScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps the create form as a pushed route, so a successful save has a page
/// to pop back to instead of unwinding the only route.
Future<void> _pumpEdit(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext _) =>
                        const ProductEditScreen(storeId: 's1'),
                  ),
                ),
                child: const Text('open-form'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open-form'));
  await tester.pumpAndSettle();
}

/// Fills the wizard's step-1 name and price.
///
/// The form became a four-step wizard, so the fields are addressed by their
/// hint text: positional `find.byType(TextFormField).at(n)` silently filled the
/// description box once the layout changed, and the test still passed for the
/// wrong reason.
Future<void> _fillBasics(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, AppStrings.productNameHint),
    'ผ้าไหม',
  );
  await tester.enterText(find.widgetWithText(TextFormField, '250'), '1290');
}

ProductDraft _draft({
  String name = 'ผ้าไหม',
  double price = 1290,
  String categoryId = 'c1',
  List<VariantDraft> variants = const <VariantDraft>[],
}) {
  return ProductDraft(
    name: name,
    description: 'คำอธิบาย',
    price: price,
    categoryId: categoryId,
    imageUrls: const <String>[],
    status: ProductStatus.draft,
    story: const ProductStory(community: 'บ้านมะคำ', productionMethod: 'ทอมือ'),
    variants: variants,
  );
}

void main() {
  // ตรวจ draft สินค้าและพฤติกรรม CRUD ของหน้าจอผู้ขายด้วย repository ปลอม
  setUpAll(() async {
    await initializeDateFormatting('th');
  });

  group('ProductDraft / VariantDraft', () {
    test('stockTotal is the sum of every variant row, negatives ignored', () {
      final ProductDraft draft = _draft(
        variants: const <VariantDraft>[
          VariantDraft(name: 'สีแดง', stock: 3),
          VariantDraft(name: 'สีน้ำเงิน', stock: 5),
          VariantDraft(name: 'ยกเลิก', stock: -2),
        ],
      );
      expect(draft.stockTotal, 8);
    });

    test('refuses to be stored without the basics', () {
      expect(_draft().isValid, isTrue);
      expect(_draft(name: '   ').isValid, isFalse);
      expect(_draft(categoryId: '').isValid, isFalse);
      expect(_draft(price: -1).isValid, isFalse);
      expect(_draft(price: double.nan).isValid, isFalse);
    });

    test('fromModel carries the story and image list into the form', () {
      const ProductModel model = ProductModel(
        id: 'p1',
        storeId: 's1',
        name: 'ผ้าไหม',
        description: 'ทอมือ',
        price: 1290,
        categoryId: 'c1',
        province: 'เชียงใหม่',
        region: 'north',
        imageUrls: <String>['https://example.com/a.jpg'],
        stockTotal: 5,
        status: ProductStatus.active,
        story: ProductStory(uniqueness: 'ย้อมครั่ง'),
      );
      final ProductDraft draft = ProductDraft.fromModel(model);
      expect(draft.name, 'ผ้าไหม');
      expect(draft.story.uniqueness, 'ย้อมครั่ง');
      expect(draft.imageUrls, <String>['https://example.com/a.jpg']);
      expect(draft.stockTotal, 0, reason: 'a stored product has variants too');
    });

    test(
      'VariantDraft.toFirestore keeps the options shape and hides a null image',
      () {
        const VariantDraft plain = VariantDraft(name: 'แพ็คขวด');
        final Map<String, dynamic> data = plain.toFirestore(productId: 'p1');
        expect(data['productId'], 'p1');
        expect(data['options'], <String, dynamic>{'color': null, 'size': null});
        expect(
          data.containsKey('imageUrl'),
          isFalse,
          reason: 'an empty write must not fabricate an image field',
        );

        const VariantDraft pictured = VariantDraft(
          name: 'แพ็คขวด',
          color: 'แดง',
          imageUrl: 'https://example.com/v.jpg',
        );
        expect(pictured.toFirestore(productId: 'p1')['imageUrl'], isNotNull);
      },
    );

    test('a variant without a stored id is a new one', () {
      expect(const VariantDraft(name: 'ใหม่').isNew, isTrue);
      expect(const VariantDraft(name: 'x', id: '').isNew, isTrue);
      expect(const VariantDraft(name: 'x', id: 'v1').isNew, isFalse);
    });
  });

  group('the catalogue controllers', () {
    test(
      'save creates through the repository and writes the computed stock',
      () async {
        final _FakeSellerCatalogRepository repo =
            _FakeSellerCatalogRepository();
        final ProviderContainer container = _container(repo);

        final String? id = await container
            .read(saveProductProvider.notifier)
            .save(
              productId: 'new-p1',
              store: _store,
              draft: _draft(
                variants: const <VariantDraft>[
                  VariantDraft(name: 'สีแดง', stock: 2),
                  VariantDraft(name: 'สีน้ำเงิน', stock: 3),
                ],
              ),
            );

        expect(id, 'new-p1');
        expect(repo.created, <String>['new-p1']);
        expect(repo.lastCreateStore, _store);
        expect(repo.lastCreateDraft!.stockTotal, 5);
      },
    );

    test('a second save while the first is in flight is refused', () async {
      final _FakeSellerCatalogRepository repo = _FakeSellerCatalogRepository();
      final ProviderContainer container = _container(repo);
      final SaveProductController controller = container.read(
        saveProductProvider.notifier,
      );

      // Park the first write, then fire both — the busy flag must stop a
      // double-write the way it stops a double order.
      repo.holdCreate = Completer<void>();
      final Future<String?> first = controller.save(
        productId: 'new-p1',
        store: _store,
        draft: _draft(),
      );
      final Future<String?> second = controller.save(
        productId: 'new-p1',
        store: _store,
        draft: _draft(),
      );

      expect(await second, isNull);
      repo.holdCreate!.complete();
      expect(await first, 'new-p1');
      expect(repo.created, hasLength(1));

      // The controller settles back to idle so the next save can go through.
      expect(container.read(saveProductProvider), isFalse);
    });

    test(
      'an invalid draft is refused before the repository is called',
      () async {
        final _FakeSellerCatalogRepository repo =
            _FakeSellerCatalogRepository();
        final ProviderContainer container = _container(repo);

        final String? id = await container
            .read(saveProductProvider.notifier)
            .save(
              productId: 'new-p1',
              store: _store,
              draft: _draft(name: ''),
            );

        expect(id, isNull);
        expect(repo.created, isEmpty);
      },
    );

    test(
      'an empty product id is refused before the repository is called',
      () async {
        final _FakeSellerCatalogRepository repo =
            _FakeSellerCatalogRepository();
        final ProviderContainer container = _container(repo);

        final String? id = await container
            .read(saveProductProvider.notifier)
            .save(productId: '', store: _store, draft: _draft());

        expect(id, isNull);
        expect(repo.created, isEmpty);
      },
    );

    test('a failed write surfaces its failure instead of a success', () async {
      final _FakeSellerCatalogRepository repo = _FakeSellerCatalogRepository()
        ..failWith = const ProductWriteException('ไม่มีสิทธิ์แก้ไขร้านนี้');
      final ProviderContainer container = _container(repo);

      await expectLater(
        container
            .read(saveProductProvider.notifier)
            .save(productId: 'new-p1', store: _store, draft: _draft()),
        throwsA(isA<ProductWriteException>()),
      );
      expect(
        container.read(saveProductProvider),
        isFalse,
        reason: 'the busy flag must clear even when the write throws',
      );
    });

    test('delete removes by id and returns it', () async {
      final _FakeSellerCatalogRepository repo = _FakeSellerCatalogRepository();
      final ProviderContainer container = _container(repo);

      final String? id = await container
          .read(deleteProductProvider.notifier)
          .delete(_product);

      expect(id, 'p1');
      expect(repo.deleted, <String>['p1']);
    });
  });

  group('the seller product list', () {
    testWidgets('a plain customer is gated out, not shown a broken list', (
      WidgetTester tester,
    ) async {
      final _FakeSellerCatalogRepository repo = _FakeSellerCatalogRepository()
        ..stores = <StoreModel>[_store]
        ..products = <ProductModel>[_product];
      final ProviderContainer container = _container(repo, user: _customer);

      await _pumpList(tester, container);

      expect(find.text(AppStrings.errNotAuthorised), findsOneWidget);
      expect(find.text(AppStrings.sellerAddProduct), findsNothing);
      expect(find.text(_product.name), findsNothing);
    });

    testWidgets('a seller with a store but nothing yet sees the empty state', (
      WidgetTester tester,
    ) async {
      final _FakeSellerCatalogRepository repo = _FakeSellerCatalogRepository()
        ..stores = <StoreModel>[_store];
      final ProviderContainer container = _container(repo);

      await _pumpList(tester, container);

      expect(find.text(AppStrings.sellerNoProducts), findsOneWidget);
      expect(
        find.widgetWithText(FloatingActionButton, AppStrings.sellerAddProduct),
        findsOneWidget,
        reason: 'the empty state must not hide the button that fixes it',
      );
    });

    testWidgets('lists the seller products with their status and stock', (
      WidgetTester tester,
    ) async {
      final _FakeSellerCatalogRepository repo = _FakeSellerCatalogRepository()
        ..stores = <StoreModel>[_store]
        ..products = <ProductModel>[_product];
      final ProviderContainer container = _container(repo);

      await _pumpList(tester, container);

      expect(find.text(_product.name), findsOneWidget);
      expect(find.text(ProductStatus.draft.label), findsWidgets);
      expect(
        find.textContaining('5'),
        findsWidgets,
        reason: 'the row shows the remaining stock',
      );
    });
  });

  group('the product form (create mode)', () {
    testWidgets('renders for the chosen store without hitting Firestore', (
      WidgetTester tester,
    ) async {
      final _FakeSellerCatalogRepository repo = _FakeSellerCatalogRepository();
      final ProviderContainer container = _editContainer(repo);

      await _pumpEdit(tester, container);

      expect(find.text(AppStrings.productNameLabel), findsOneWidget);
      expect(find.text(AppStrings.productPriceLabel), findsOneWidget);
      expect(
        find.text(AppStrings.sellerEditProduct),
        findsWidgets,
        reason: 'the bar and the app bar both carry the screen name',
      );
    });

    testWidgets('refuses to write until the category is chosen', (
      WidgetTester tester,
    ) async {
      final _FakeSellerCatalogRepository repo = _FakeSellerCatalogRepository();
      final ProviderContainer container = _editContainer(repo);

      await _pumpEdit(tester, container);

      await _fillBasics(tester);
      // Step 1 is the basics step, so its primary button is "next", not save.
      await tester.tap(find.text('ขั้นตอนถัดไป'));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.errCategoryRequired), findsOneWidget);
      expect(
        repo.created,
        isEmpty,
        reason: 'a half-filled product must never reach the catalogue',
      );
    });

    testWidgets('a valid product is created with its variants and pops back', (
      WidgetTester tester,
    ) async {
      final _FakeSellerCatalogRepository repo = _FakeSellerCatalogRepository();
      final ProviderContainer container = _editContainer(repo);

      await _pumpEdit(tester, container);

      await _fillBasics(tester);

      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_category.name).last);
      await tester.pumpAndSettle();

      // Walk the wizard: basics -> images -> variants -> story, then publish.
      // Step 1 will not advance without an image, so add one by URL.
      await tester.tap(find.text('ขั้นตอนถัดไป'));
      await tester.pumpAndSettle();
      final Finder imageChip = find.ancestor(
        of: find.text('เพิ่มรูป'),
        matching: find.byType(AppChip),
      );
      expect(
        imageChip,
        findsOneWidget,
        reason: 'the image step offers exactly one เพิ่มรูป chip',
      );
      await tester.tap(imageChip);
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.addImageByUrl));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.imageUrlHint),
        'https://example.com/a.jpg',
      );
      // `addImage` and the chip's label are the same string, so the dialog's
      // confirm button has to be addressed inside the dialog.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(AppStrings.addImage),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ขั้นตอนถัดไป'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(AppStrings.addVariant));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.addVariant));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byWidgetPredicate(
          (Widget w) =>
              w is TextField &&
              w.decoration?.hintText == AppStrings.variantNameExample,
        ),
        'แพ็คขวด',
      );
      // Stock is a −/+ stepper, not a text box, so it is tapped up to 5.
      final Finder stockUp = find.byKey(const ValueKey<String>('stock-up-0'));
      for (int i = 0; i < 5; i++) {
        await tester.tap(stockUp);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('ขั้นตอนถัดไป'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();

      expect(repo.created, <String>['new-p1']);
      expect(repo.lastCreateDraft!.name, 'ผ้าไหม');
      expect(repo.lastCreateDraft!.stockTotal, 5);
      // A successful save pops back to the screen that opened the form.
      expect(find.text('open-form'), findsOneWidget);
    });
  });

  group('the product form (edit mode)', () {
    testWidgets('seeds the stored product into every field', (
      WidgetTester tester,
    ) async {
      final _FakeSellerCatalogRepository repo = _FakeSellerCatalogRepository()
        ..variantsByProduct = <String, List<ProductVariantModel>>{
          'p1': const <ProductVariantModel>[
            ProductVariantModel(
              id: 'v1',
              productId: 'p1',
              name: 'แพ็คขวด',
              color: null,
              size: null,
              priceDelta: 0,
              stock: 5,
            ),
          ],
        };
      final ProviderContainer container = ProviderContainer(
        overrides: [
          authUserProvider.overrideWith(
            (Ref ref) => Stream<UserModel?>.value(_seller),
          ),
          sellerCatalogRepositoryProvider.overrideWithValue(repo),
          storeProvider.overrideWith((Ref ref, String id) async => _store),
          categoriesProvider.overrideWith(
            (Ref ref) async => const <CategoryModel>[_category],
          ),
          productProvider.overrideWith((Ref ref, String id) async => _product),
          productVariantsProvider.overrideWith(
            (Ref ref, String id) async =>
                repo.variantsByProduct[id] ?? const <ProductVariantModel>[],
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProductEditScreen(productId: 'p1')),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(_product.name),
        findsOneWidget,
        reason: 'the seeded name must arrive in the name field',
      );
      expect(
        find.text('1290'),
        findsWidgets,
        reason: 'the seeded price must arrive in the price field (plain baht)',
      );
    });

    testWidgets(
      'an untouched seeded product still passes validation and saves',
      (WidgetTester tester) async {
        final _FakeSellerCatalogRepository repo =
            _FakeSellerCatalogRepository();
        final ProviderContainer container = ProviderContainer(
          overrides: [
            authUserProvider.overrideWith(
              (Ref ref) => Stream<UserModel?>.value(_seller),
            ),
            sellerCatalogRepositoryProvider.overrideWithValue(repo),
            storeProvider.overrideWith((Ref ref, String id) async => _store),
            categoriesProvider.overrideWith(
              (Ref ref) async => const <CategoryModel>[_category],
            ),
            productProvider.overrideWith(
              (Ref ref, String id) async => _product,
            ),
            productVariantsProvider.overrideWith(
              (Ref ref, String id) async => const <ProductVariantModel>[],
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: ProductEditScreen(productId: 'p1')),
          ),
        );
        await tester.pumpAndSettle();

        // Regression: the category validator used to report "choose a category"
        // no matter what, so editing a product that already had one was
        // impossible to save. The seeded product has a category, so the draft
        // save on step 1 must go through.
        await tester.tap(find.text('บันทึกเป็นฉบับร่าง'));
        await tester.pumpAndSettle();

        expect(repo.updated, <String>['p1']);
        expect(repo.lastUpdateDraft!.categoryId, _product.categoryId);
        expect(repo.lastUpdateDraft!.price, _product.price);
      },
    );
  });

  group('StoreProfileDraft', () {
    test('a name is the only required field', () {
      const StoreProfileDraft named = StoreProfileDraft(
        name: 'ร้านชิงไทร',
        description: '',
        province: '',
        region: 'north',
        community: '',
        coverImageUrl: '',
      );
      const StoreProfileDraft blank = StoreProfileDraft(
        name: '   ',
        description: 'มีคำอธิบายแต่ไม่มีชื่อ',
        province: 'เชียงใหม่',
        region: 'north',
        community: 'บ้านมะคำ',
        coverImageUrl: '',
      );

      expect(named.isValid, isTrue);
      expect(blank.isValid, isFalse);
    });

    test('fromModel carries the editable fields and leaves the rest out', () {
      final StoreProfileDraft draft = StoreProfileDraft.fromModel(_store);

      expect(draft.name, _store.name);
      expect(draft.province, _store.province);
      expect(draft.community, _store.community);
      expect(draft.coverImageUrl, _store.coverImageUrl);
      expect(draft.logoUrl, isNull);
    });
  });

  group('the store profile controller', () {
    ProviderContainer profileContainer(_FakeSellerCatalogRepository repo) =>
        _container(repo);

    test('writes the draft and invalidates the shared store list', () async {
      final _FakeSellerCatalogRepository repo = _FakeSellerCatalogRepository();
      final ProviderContainer container = profileContainer(repo);

      final bool ok = await container
          .read(saveStoreProfileProvider.notifier)
          .save(store: _store, draft: StoreProfileDraft.fromModel(_store));

      expect(ok, isTrue);
      expect(repo.storeProfileWrites.single.storeId, _store.id);
      expect(repo.storeProfileWrites.single.draft.name, _store.name);
      // The customer's store screen reads the same provider, so it has to
      // re-read after the seller renames the shop.
      expect(container.read(myStoresProvider).isLoading, isTrue);
    });

    test('refuses an empty name without writing', () async {
      final _FakeSellerCatalogRepository repo = _FakeSellerCatalogRepository();
      final ProviderContainer container = profileContainer(repo);

      final bool ok = await container
          .read(saveStoreProfileProvider.notifier)
          .save(
            store: _store,
            draft: const StoreProfileDraft(
              name: '  ',
              description: '',
              province: '',
              region: 'north',
              community: '',
              coverImageUrl: '',
            ),
          );

      expect(ok, isFalse);
      expect(repo.storeProfileWrites, isEmpty);
    });

    test('a denied write reports failure instead of throwing', () async {
      final _FakeSellerCatalogRepository repo = _FakeSellerCatalogRepository()
        ..failWith = StateError('PERMISSION_DENIED');
      final ProviderContainer container = profileContainer(repo);

      final bool ok = await container
          .read(saveStoreProfileProvider.notifier)
          .save(store: _store, draft: StoreProfileDraft.fromModel(_store));

      expect(ok, isFalse);
    });

    test('a second save while the first is in flight is ignored', () async {
      final _FakeSellerCatalogRepository repo = _FakeSellerCatalogRepository();
      final ProviderContainer container = profileContainer(repo);

      final Completer<void> gate = Completer<void>();
      repo.holdStoreProfile = gate;

      final Future<bool> first = container
          .read(saveStoreProfileProvider.notifier)
          .save(store: _store, draft: StoreProfileDraft.fromModel(_store));
      // Let the controller flip into its busy state before the second tap.
      await Future<void>.delayed(Duration.zero);
      final bool second = await container
          .read(saveStoreProfileProvider.notifier)
          .save(store: _store, draft: StoreProfileDraft.fromModel(_store));

      gate.complete();
      expect(await first, isTrue);

      expect(second, isFalse);
      expect(repo.storeProfileWrites, hasLength(1));
    });
  });
}
