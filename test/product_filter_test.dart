import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_otop_marketplace/core/constants/app_enums.dart';
import 'package:thai_otop_marketplace/providers/catalog_provider.dart';

void main() {
  // ตรวจการกรองสินค้าตามหมวด ภูมิภาค และข้อความค้นหา
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

    // `null` is the "ทั้งหมด" chip: it must return to every category instead of
    // being ignored, otherwise tapping the first chip after picking one does
    // nothing (the reported bug).
    test('a null category clears the category (the "ทั้งหมด" chip)', () {
      filter.toggleCategory('c-coffee');
      filter.toggleCategory(null);
      expect(container.read(productFilterProvider).categoryId, isNull);
    });

    test('"ทั้งหมด" keeps the region and search while clearing the category', () {
      filter.toggleRegion(ThaiRegion.north);
      filter.setSearch('ไหม');
      filter.toggleCategory('c-fashion');

      filter.toggleCategory(null);

      final ProductFilter state = container.read(productFilterProvider);
      expect(state.categoryId, isNull);
      expect(state.region, ThaiRegion.north);
      expect(state.search, 'ไหม');
    });

    test('"ทั้งหมด" on an already-wide filter keeps the region', () {
      filter.toggleRegion(ThaiRegion.south);
      filter.toggleCategory(null);
      expect(container.read(productFilterProvider).region, ThaiRegion.south);
    });

    test('tapping the active region clears it', () {
      filter.toggleRegion(ThaiRegion.north);
      expect(container.read(productFilterProvider).region, ThaiRegion.north);

      filter.toggleRegion(ThaiRegion.north);
      expect(container.read(productFilterProvider).region, isNull);
    });

    test('switching category or region keeps the other dimension', () {
      filter.toggleRegion(ThaiRegion.south);
      filter.toggleCategory('c-coffee');
      filter.toggleCategory('c-health');
      expect(container.read(productFilterProvider).categoryId, 'c-health');
      expect(container.read(productFilterProvider).region, ThaiRegion.south);

      filter.toggleRegion(ThaiRegion.central);
      expect(container.read(productFilterProvider).region, ThaiRegion.central);
      expect(container.read(productFilterProvider).categoryId, 'c-health');
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
