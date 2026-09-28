import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_otop_marketplace/core/constants/app_enums.dart';
import 'package:thai_otop_marketplace/providers/catalog_provider.dart';

void main() {
  group('ProductFilter', () {
    late ProviderContainer container;
    late ProductFilterNotifier filter;

    setUp(() {
      container = ProviderContainer();
      filter = container.read(productFilterProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('starts wide open', () {
      final ProductFilter state = container.read(productFilterProvider);
      expect(state.categoryId, isNull);
      expect(state.region, isNull);
      expect(state.search, isNull);
    });

    test('a search term is kept', () {
      filter.setSearch('กาแฟ');
      expect(container.read(productFilterProvider).search, 'กาแฟ');
    });

    test('whitespace-only input clears the term', () {
      filter.setSearch('กาแฟ');
      filter.setSearch('   ');
      expect(container.read(productFilterProvider).search, isNull);
    });

    test('a term is trimmed before it reaches the query', () {
      filter.setSearch('  ผ้าไหม  ');
      expect(container.read(productFilterProvider).search, 'ผ้าไหม');
    });

    test('searching does not drop the category or region filter', () {
      filter.toggleCategory('c-herb');
      filter.toggleRegion(ThaiRegion.north);
      filter.setSearch('กาแฟ');

      final ProductFilter state = container.read(productFilterProvider);
      expect(state.categoryId, 'c-herb');
      expect(state.region, ThaiRegion.north);
      expect(state.search, 'กาแฟ');
    });

    test('changing the category does not drop the search term', () {
      filter.setSearch('กาแฟ');
      filter.toggleCategory('c-coffee');

      final ProductFilter state = container.read(productFilterProvider);
      expect(state.categoryId, 'c-coffee');
      expect(state.search, 'กาแฟ');
    });

    test('tapping the active category clears it but keeps the search', () {
      filter.toggleCategory('c-coffee');
      filter.toggleCategory('c-coffee');
      expect(container.read(productFilterProvider).categoryId, isNull);
    });

    test('a null category is ignored rather than treated as a clear-all', () {
      filter.toggleCategory('c-coffee');
      filter.toggleCategory(null);
      expect(container.read(productFilterProvider).categoryId, 'c-coffee');
    });

    test('clear resets every dimension', () {
      filter.toggleCategory('c-coffee');
      filter.toggleRegion(ThaiRegion.south);
      filter.setSearch('กาแฟ');

      filter.clear();

      final ProductFilter state = container.read(productFilterProvider);
      expect(state.categoryId, isNull);
      expect(state.region, isNull);
      expect(state.search, isNull);
    });
  });
}
