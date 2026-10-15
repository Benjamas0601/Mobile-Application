import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_otop_marketplace/core/constants/app_enums.dart'
    show ProductStatus;
import 'package:thai_otop_marketplace/core/constants/app_strings.dart';
import 'package:thai_otop_marketplace/features/favorites/screens/favorites_screen.dart';
import 'package:thai_otop_marketplace/features/favorites/widgets/favorite_button.dart';
import 'package:thai_otop_marketplace/models/product_model.dart';
import 'package:thai_otop_marketplace/models/user_model.dart';
import 'package:thai_otop_marketplace/providers/auth_provider.dart';
import 'package:thai_otop_marketplace/providers/favorite_provider.dart';
import 'package:thai_otop_marketplace/repositories/favorite_repository.dart';

const UserModel _customer = UserModel(
  uid: 'u1',
  displayName: 'สมชาย ใจดี',
  email: 'customer@example.com',
);

final ProductModel _product = ProductModel(
  id: 'p1',
  storeId: 's1',
  name: 'กาแฟดอยอารามี',
  description: '',
  price: 480,
  categoryId: 'c1',
  province: 'เชียงใหม่',
  region: 'north',
  imageUrls: <String>[],
  stockTotal: 20,
  status: ProductStatus.active,
  story: ProductStory(),
);

/// A favourite repository that answers from an in-memory set, so the provider
/// graph can be driven without a live Firestore.
class _FakeFavoriteRepository implements FavoriteRepository {
  _FakeFavoriteRepository({Set<String>? initial})
    : ids = <String>{...?initial};

  final Set<String> ids;
  bool watchCalled = false;
  int addCalls = 0;
  int removeCalls = 0;

  @override
  Stream<List<String>> watchMyFavoriteIds() {
    watchCalled = true;
    return Stream<List<String>>.value(ids.toList());
  }

  @override
  Future<void> add(String productId) async {
    addCalls++;
    ids.add(productId);
  }

  @override
  Future<void> remove(String productId) async {
    removeCalls++;
    ids.remove(productId);
  }

  @override
  Future<void> setFavorite(String productId, bool favorite) =>
      favorite ? add(productId) : remove(productId);
}

ProviderContainer _container({
  required UserModel? user,
  required _FakeFavoriteRepository repository,
}) => ProviderContainer(
  overrides: [
    authUserProvider.overrideWith((Ref ref) => Stream<UserModel?>.value(user)),
    favoriteRepositoryProvider.overrideWithValue(repository),
  ],
);

void main() {
  group('favorite providers', () {
    test('a guest sees an empty list and never opens a Firestore listener', () async {
      final _FakeFavoriteRepository repository = _FakeFavoriteRepository(
        initial: <String>{'p1'},
      );
      final ProviderContainer container = _container(
        user: null,
        repository: repository,
      );
      addTearDown(container.dispose);
      final ProviderSubscription<AsyncValue<List<String>>> sub = container
          .listen(myFavoriteIdsProvider, (_, _) {});
      addTearDown(sub.close);

      final List<String> ids = await container.read(
        myFavoriteIdsProvider.future,
      );

      expect(ids, isEmpty);
      expect(
        repository.watchCalled,
        isFalse,
        reason: 'guests must not trigger a favourite query',
      );
    });

    test('a signed-in user sees their favourite ids, newest first', () async {
      final _FakeFavoriteRepository repository = _FakeFavoriteRepository(
        initial: <String>{'p1', 'p2'},
      );
      final ProviderContainer container = _container(
        user: _customer,
        repository: repository,
      );
      addTearDown(container.dispose);
      final ProviderSubscription<AsyncValue<List<String>>> sub = container
          .listen(myFavoriteIdsProvider, (_, _) {});
      addTearDown(sub.close);

      final List<String> ids = await container.read(
        myFavoriteIdsProvider.future,
      );

      expect(ids, <String>['p1', 'p2']);
      expect(container.read(isFavoriteProvider('p1')), isTrue);
      expect(container.read(isFavoriteProvider('p9')), isFalse);
    });

    test('toggling removes an existing favourite and adds a new one', () async {
      final _FakeFavoriteRepository repository = _FakeFavoriteRepository(
        initial: <String>{'p1'},
      );
      final ProviderContainer container = _container(
        user: _customer,
        repository: repository,
      );
      addTearDown(container.dispose);
      final ProviderSubscription<AsyncValue<List<String>>> sub = container
          .listen(myFavoriteIdsProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(myFavoriteIdsProvider.future);

      await container.read(toggleFavoriteProvider)('p1');
      expect(repository.removeCalls, 1);
      expect(repository.ids, isNot(contains('p1')));

      await container.read(toggleFavoriteProvider)('p2');
      expect(repository.addCalls, 1);
      expect(repository.ids, contains('p2'));
    });
  });

  group('favorites screen', () {
    testWidgets('lists the saved products', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authUserProvider.overrideWith(
              (Ref ref) => Stream<UserModel?>.value(_customer),
            ),
            favoriteRepositoryProvider.overrideWithValue(
              _FakeFavoriteRepository(),
            ),
            favoriteProductsProvider.overrideWith(
              (Ref ref) =>
                  Stream<List<ProductModel>>.value(<ProductModel>[_product]),
            ),
          ],
          child: const MaterialApp(home: FavoritesScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.favoritesTitle), findsOneWidget);
      expect(find.text(_product.name), findsOneWidget);
    });

    testWidgets('shows the empty state when nothing is saved', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authUserProvider.overrideWith(
              (Ref ref) => Stream<UserModel?>.value(_customer),
            ),
            favoriteRepositoryProvider.overrideWithValue(
              _FakeFavoriteRepository(),
            ),
            favoriteProductsProvider.overrideWith(
              (Ref ref) => Stream<List<ProductModel>>.value(
                const <ProductModel>[],
              ),
            ),
          ],
          child: const MaterialApp(home: FavoritesScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.favoritesEmpty), findsOneWidget);
    });
  });

  group('favorite button', () {
    testWidgets('asks a guest to sign in instead of writing', (
      WidgetTester tester,
    ) async {
      final _FakeFavoriteRepository repository = _FakeFavoriteRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authUserProvider.overrideWith(
              (Ref ref) => Stream<UserModel?>.value(null),
            ),
            favoriteRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: FavoriteButton(productId: 'p1')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FavoriteButton));
      await tester.pump();

      expect(find.text(AppStrings.loginToFavorite), findsOneWidget);
      expect(repository.addCalls, 0);
      expect(repository.removeCalls, 0);
    });

    testWidgets('a signed-in tap saves the product', (
      WidgetTester tester,
    ) async {
      final _FakeFavoriteRepository repository = _FakeFavoriteRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authUserProvider.overrideWith(
              (Ref ref) => Stream<UserModel?>.value(_customer),
            ),
            favoriteRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: FavoriteButton(productId: 'p1')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FavoriteButton));
      await tester.pumpAndSettle();

      expect(repository.addCalls, 1);
      expect(repository.ids, contains('p1'));
    });
  });
}
