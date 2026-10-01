import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_otop_marketplace/core/constants/app_enums.dart';
import 'package:thai_otop_marketplace/core/constants/app_strings.dart';
import 'package:thai_otop_marketplace/features/home/screens/home_screen.dart';
import 'package:thai_otop_marketplace/models/category_model.dart';
import 'package:thai_otop_marketplace/models/product_model.dart';
import 'package:thai_otop_marketplace/models/user_model.dart';
import 'package:thai_otop_marketplace/providers/auth_provider.dart';
import 'package:thai_otop_marketplace/providers/catalog_provider.dart';

final ProductModel _product = ProductModel(
  id: 'p-herb',
  storeId: 's1',
  name: 'สมุนไพรแก้ปวดเมื่อย',
  description: '',
  price: 480,
  categoryId: 'c1',
  province: 'นครศรีธรรมราช',
  region: ThaiRegion.south.value,
  imageUrls: <String>[],
  stockTotal: 70,
  status: ProductStatus.active,
  story: ProductStory(),
);

const CategoryModel _category = CategoryModel(
  id: 'c1',
  name: 'หัตถกรรม',
  slug: 'handicraft',
  icon: '🧶',
  sortOrder: 1,
);

/// Stands in for Firestore: the search field only needs the grid to exist.
ProviderContainer _container() => ProviderContainer(
  overrides: [
    categoriesProvider.overrideWith(
      (Ref ref) async => <CategoryModel>[_category],
    ),
    productsProvider.overrideWith((Ref ref) async => <ProductModel>[_product]),
    authUserProvider.overrideWith((Ref ref) => Stream<UserModel?>.value(null)),
  ],
);

void main() {
    // ตรวจ debounce และการล้างคำค้นโดยใช้ข้อมูลจำลองแทน Firestore
  group('home search', () {
    late ProviderContainer container;

    setUp(() => container = _container());
    tearDown(() => container.dispose());

    Future<void> pumpHome(WidgetTester tester) async {
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a guest is offered a search field with no sign-in in the way', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);

      expect(find.byType(TextField), findsOneWidget);
      // The field carries the prompt, and the login entry point is still there.
      expect(find.text(AppStrings.searchHint), findsOneWidget);
      expect(find.text(AppStrings.login), findsOneWidget);
    });

    testWidgets('typing reaches the filter after the debounce', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);

      await tester.enterText(find.byType(TextField), 'กาแฟ');
      // Nothing happens yet: the query is debounced.
      expect(container.read(productFilterProvider).search, isNull);

      await tester.pump(const Duration(milliseconds: 400));
      expect(container.read(productFilterProvider).search, 'กาแฟ');
    });

    testWidgets('the section header switches to results while searching', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);
      expect(find.text(AppStrings.navExplore), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'กาแฟ');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.searchResults), findsOneWidget);
      expect(find.text(AppStrings.navExplore), findsNothing);
    });

    testWidgets('the clear button resets the term and restores the header', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);

      await tester.enterText(find.byType(TextField), 'กาแฟ');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(AppStrings.clearSearch));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(container.read(productFilterProvider).search, isNull);
      expect(find.text(AppStrings.navExplore), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
