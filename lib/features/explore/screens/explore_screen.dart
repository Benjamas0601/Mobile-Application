import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// `app_enums` declares its own AsyncValue for the offline layer, which collides
// with Riverpod's. Explore only uses Riverpod's.
import '../../../core/constants/app_enums.dart' hide AsyncValue;
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/store_model.dart';
import '../../../providers/catalog_provider.dart';
import '../../../repositories/product_index_repository.dart';
import '../../../widgets/design_system.dart';
import '../../../widgets/state_views.dart';

/// "Explore Thailand" — browse by place, not by product.
///
/// The screen answers three questions in order: *where* am I looking (the
/// map), *how many* places are there (province cards), and *what* is there
/// (the store list for the chosen province). Tapping a dot on the map and
/// tapping a province card do the same thing, so the two halves stay in sync
/// instead of behaving like two separate features.
///
/// The map is a stylised 2D outline with a dot per province — no 3D, no map
/// tiles — so it renders instantly, scales to any width, and stays legible in
/// dark mode.
/// หน้าสำรวจตามภูมิภาค ค้นหา แผนที่ 2D และรายชื่อร้านในจังหวัด
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key, this.showBackButton = true});

  /// False when the screen is the first route of a tab shell, which brings its
  /// own way back.
  final bool showBackButton;

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  ThaiRegion? _region;
  String? _province;

  /// The search field owns the text, so every clear path has to go through
  /// the controller — resetting only the filter string leaves the glyphs on
  /// screen while the results below reset.
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearQuery() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<StoreModel>> stores = ref.watch(storesProvider);
    final AsyncValue<List<ProductProvinceSummary>> products = ref.watch(
      exploreProductIndexProvider,
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBackButton,
        title: const Text('สำรวจไทย'),
      ),
      body: Builder(
        builder: (BuildContext context) {
          if (stores.isLoading || products.isLoading) {
            return const SkeletonTextBlock(lines: 6);
          }
          if (stores.hasError) {
            return ErrorView(
              message: 'โหลดรายชื่อร้านไม่สำเร็จ',
              onRetry: () {
                ref.invalidate(storesProvider);
                ref.invalidate(exploreProductIndexProvider);
              },
            );
          }

          final List<StoreModel> allStores =
              stores.asData?.value ?? const <StoreModel>[];
          final List<ProductProvinceSummary> allProducts =
              products.asData?.value ?? const <ProductProvinceSummary>[];

          final String term = _query.trim().toLowerCase();
          final bool matchesTerm =
              term.isEmpty ||
              allStores.any(
                (StoreModel s) =>
                    s.province.toLowerCase().contains(term) ||
                    s.name.toLowerCase().contains(term),
              ) ||
              kExploreProvinces.any(
                (ExploreProvince p) => p.name.toLowerCase().contains(term),
              );

          final List<StoreModel> visibleStores = allStores
              .where(
                (StoreModel s) =>
                    (_region == null || s.regionEnum == _region) &&
                    (term.isEmpty ||
                        s.province.toLowerCase().contains(term) ||
                        s.name.toLowerCase().contains(term)),
              )
              .toList();
          final List<ProductProvinceSummary> visibleProducts = allProducts
              .where(
                (ProductProvinceSummary p) =>
                    (_region == null || p.regionEnum == _region) &&
                    (term.isEmpty || p.province.toLowerCase().contains(term)),
              )
              .toList();

          final Map<String, int> storeCount = _countBy(
            visibleStores.map((StoreModel s) => s.province),
          );
          final Map<String, int> productCount = _countBy(
            visibleProducts.map((ProductProvinceSummary p) => p.province),
          );

          final List<ProvinceTally> tallies = kExploreProvinces
              .map(
                (ExploreProvince p) => ProvinceTally(
                  name: p.name,
                  region: p.region,
                  storeCount: storeCount[p.name] ?? 0,
                  productCount: productCount[p.name] ?? 0,
                ),
              )
              .toList();

          // A region with no seeded data at all. The west is the design's
          // deliberate example, so this branch is a real state and not a
          // theoretical one.
          final bool regionIsEmpty =
              _region != null &&
              storeCount.values.every((int v) => v == 0) &&
              productCount.values.every((int v) => v == 0);

          return CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(child: _search()),
              SliverToBoxAdapter(child: _regionChips()),
              if (!matchesTerm)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyView(
                    icon: Icons.search_off_rounded,
                    title: 'ไม่พบจังหวัดที่ค้นหา',
                    body: 'ลองพิมพ์ชื่อจังหวัดอื่น',
                    actionLabel: 'ล้างคำค้น',
                    onAction: _clearQuery,
                  ),
                )
              else if (regionIsEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyView(
                    icon: Icons.map_outlined,
                    title:
                        'ตอนนี้ยังไม่มีร้านในภาค${_region!.label.replaceFirst('ภาค', '')}',
                    body: 'ลองดูภาคอื่น หรือกลับไปหน้าแรก',
                    actionLabel: 'ดูภาคอื่น',
                    onAction: () => setState(() {
                      _region = null;
                      _province = null;
                    }),
                    secondaryActionLabel: 'กลับไปหน้าแรก',
                    onSecondaryAction: () => context.go(AppRoutes.home),
                  ),
                )
              else ...<Widget>[
                SliverToBoxAdapter(
                  child: _MapCard(
                    selectedProvince: _province,
                    visibleRegion: _region,
                    storeTotal: visibleStores.length,
                    productTotal: visibleProducts.length,
                    onProvinceTap: _openProvince,
                  ),
                ),
                if (_province case final String chosen)
                  SliverToBoxAdapter(
                    child: _ProvinceStores(
                      province: chosen,
                      stores: visibleStores
                          .where((StoreModel s) => s.province == chosen)
                          .toList(),
                      onBack: () => setState(() => _province = null),
                    ),
                  )
                else ...<Widget>[
                  const SliverToBoxAdapter(
                    child: AppSectionLabel('เลือกจังหวัด'),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.cardGutter,
                    ),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: AppSpacing.sm + 2,
                            crossAxisSpacing: AppSpacing.sm + 2,
                            childAspectRatio: 1.55,
                          ),
                      delegate: SliverChildBuilderDelegate((
                        BuildContext context,
                        int index,
                      ) {
                        final ProvinceTally item = tallies[index];
                        return _ProvinceCard(
                          tally: item,
                          selected: item.name == _province,
                          onTap: () => _openProvince(item.name),
                        );
                      }, childCount: tallies.length),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xxxl),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static Map<String, int> _countBy(Iterable<String> values) {
    final Map<String, int> counts = <String, int>{};
    for (final String value in values) {
      if (value.isEmpty) continue;
      counts.update(value, (int v) => v + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Widget _search() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.cardGutter,
        AppSpacing.lg,
        AppSpacing.cardGutter,
        0,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (String value) => setState(() => _query = value),
        textInputAction: TextInputAction.search,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: 'ค้นหาจังหวัดหรือร้าน',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'ล้างคำค้น',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: _clearQuery,
                ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.huge),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.huge),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _regionChips() {
    return SizedBox(
      height: AppSizes.chipHeight + AppSpacing.xl,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.cardGutter,
          AppSpacing.md,
          AppSpacing.cardGutter,
          0,
        ),
        children: <Widget>[
          AppChip(
            label: 'ทั้งหมด',
            selected: _region == null,
            onTap: () => setState(() {
              _region = null;
              _province = null;
            }),
          ),
          for (final ThaiRegion region in ThaiRegion.values) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            AppChip(
              label: region.label.replaceFirst('ภาค', ''),
              selected: _region == region,
              onTap: () => setState(() {
                _region = _region == region ? null : region;
                _province = null;
              }),
            ),
          ],
        ],
      ),
    );
  }

  void _openProvince(String province) {
    setState(() {
      _province = _province == province ? null : province;
    });
  }
}

// ---------------------------------------------------------------------------
// Province data
// ---------------------------------------------------------------------------

/// A province the map can place a dot on.
class ExploreProvince {
  const ExploreProvince(this.name, this.region);

  final String name;
  final ThaiRegion region;
}

/// A province plus its live counts, recomputed whenever the data changes.
class ProvinceTally {
  const ProvinceTally({
    required this.name,
    required this.region,
    required this.storeCount,
    required this.productCount,
  });

  final String name;
  final ThaiRegion region;
  final int storeCount;
  final int productCount;
}

/// Provinces the design places on the map.
///
/// Kept as a literal list rather than a GeoJSON load: the map is a stylised 2D
/// outline, so real boundaries would add payload and buy nothing visually, and
/// a fixed list keeps the dot positions stable between builds.
const List<ExploreProvince> kExploreProvinces = <ExploreProvince>[
  ExploreProvince('เชียงใหม่', ThaiRegion.north),
  ExploreProvince('ลำพูน', ThaiRegion.north),
  ExploreProvince('แม่ฮ่องสอน', ThaiRegion.north),
  ExploreProvince('น่าน', ThaiRegion.north),
  ExploreProvince('เลย', ThaiRegion.northeast),
  ExploreProvince('อุดรธานี', ThaiRegion.northeast),
  ExploreProvince('หนองคาย', ThaiRegion.northeast),
  ExploreProvince('พิษณุโลก', ThaiRegion.central),
  ExploreProvince('อยุธยา', ThaiRegion.central),
  ExploreProvince('สุพรรณบุรี', ThaiRegion.central),
  ExploreProvince('ฉะเชิงเทรา', ThaiRegion.east),
  ExploreProvince('ระยอง', ThaiRegion.east),
  ExploreProvince('ภูเก็ต', ThaiRegion.south),
  ExploreProvince('นครศรีธรรมราช', ThaiRegion.south),
  ExploreProvince('สงขลา', ThaiRegion.south),
  ExploreProvince('ยะลา', ThaiRegion.south),
];

/// Region colour, shared by the map dots, the province cards and the chips so
/// the three can never drift apart.
Color regionColor(ThaiRegion region) => switch (region) {
  ThaiRegion.north => AppColors.regionNorth,
  ThaiRegion.northeast => AppColors.regionNortheast,
  ThaiRegion.central => AppColors.regionCentral,
  ThaiRegion.east => AppColors.regionEast,
  ThaiRegion.west => AppColors.regionWest,
  ThaiRegion.south => AppColors.regionSouth,
};

// ---------------------------------------------------------------------------
// Map
// ---------------------------------------------------------------------------

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.selectedProvince,
    required this.visibleRegion,
    required this.storeTotal,
    required this.productTotal,
    required this.onProvinceTap,
  });

  final String? selectedProvince;
  final ThaiRegion? visibleRegion;
  final int storeTotal;
  final int productTotal;
  final ValueChanged<String> onProvinceTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xxs,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '$storeTotal ร้าน · $productTotal สินค้า',
                    style: AppTextStyles.labelMedium,
                  ),
                ),
                Text('แผนที่ไทย', style: AppTextStyles.labelSmall),
              ],
            ),
          ),
          SizedBox(
            height: 246,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: ThailandMap(
                provinces: kExploreProvinces,
                selectedProvince: selectedProvince,
                visibleRegion: visibleRegion,
                onProvinceTap: onProvinceTap,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.touch_app_outlined,
                  size: 14,
                  color: AppColors.inkMuted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'แตะจุดบนแผนที่เพื่อดูร้านในจังหวัดนั้น',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Stylised 2D outline of Thailand with one tappable dot per province.
///
/// Drawn with a [CustomPainter] rather than an image so it scales to any
/// width, stays crisp, and can recolour itself for the dark theme.
class ThailandMap extends StatelessWidget {
  const ThailandMap({
    super.key,
    required this.provinces,
    required this.onProvinceTap,
    this.selectedProvince,
    this.visibleRegion,
  });

  final List<ExploreProvince> provinces;
  final ValueChanged<String> onProvinceTap;
  final String? selectedProvince;
  final ThaiRegion? visibleRegion;

  /// Dot positions in the painter's own 200x340 space, matched to the outline.
  static const Map<String, Offset> dotPositions = <String, Offset>{
    'เชียงใหม่': Offset(96, 62),
    'ลำพูน': Offset(112, 50),
    'แม่ฮ่องสอน': Offset(76, 46),
    'น่าน': Offset(130, 34),
    'เลย': Offset(150, 58),
    'อุดรธานี': Offset(140, 82),
    'หนองคาย': Offset(158, 92),
    'พิษณุโลก': Offset(126, 106),
    'อยุธยา': Offset(124, 150),
    'สุพรรณบุรี': Offset(104, 142),
    'ฉะเชิงเทรา': Offset(140, 182),
    'ระยอง': Offset(150, 206),
    'ภูเก็ต': Offset(90, 250),
    'นครศรีธรรมราช': Offset(120, 272),
    'สงขลา': Offset(128, 300),
    'ยะลา': Offset(124, 316),
  };

  /// The outline's authored box. [dotPositions] uses the same space.
  static const Size canvasSize = Size(200, 340);

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double scale = math.min(
          constraints.maxWidth / canvasSize.width,
          constraints.maxHeight / canvasSize.height,
        );
        final double offsetX =
            (constraints.maxWidth - canvasSize.width * scale) / 2;
        final double offsetY =
            (constraints.maxHeight - canvasSize.height * scale) / 2;

        return Semantics(
          label: 'แผนที่ไทย แสดงจุดจังหวัดตามสีภูมิภาค',
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: CustomPaint(
                  painter: _ThailandOutlinePainter(
                    fill: scheme.surfaceContainerHighest,
                    stroke: scheme.primary,
                    grid: scheme.outlineVariant,
                  ),
                ),
              ),
              for (final ExploreProvince province in provinces)
                if (dotPositions[province.name] case final Offset dot)
                  _MapDot(
                    name: province.name,
                    color: regionColor(province.region),
                    dimmed:
                        visibleRegion != null &&
                        visibleRegion != province.region,
                    isSelected: selectedProvince == province.name,
                    size: (selectedProvince == province.name ? 12 : 9) * scale,
                    center: Offset(
                      offsetX + dot.dx * scale,
                      offsetY + dot.dy * scale,
                    ),
                    onTap: () => onProvinceTap(province.name),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _MapDot extends StatelessWidget {
  const _MapDot({
    required this.name,
    required this.color,
    required this.dimmed,
    required this.isSelected,
    required this.size,
    required this.center,
    required this.onTap,
  });

  final String name;
  final Color color;
  final bool dimmed;
  final bool isSelected;
  final double size;
  final Offset center;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The visual dot is 9-12px, far below the tap minimum, so the hit box is
    // inflated to the accessible size and the dot is centred inside it.
    final double hit = math.max(size, AppSizes.minTapTarget);

    return Positioned(
      left: center.dx - hit / 2,
      top: center.dy - hit / 2,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: 'ดูร้านในจังหวัด$name',
        child: Tooltip(
          message: name,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.translucent,
            child: SizedBox(
              width: hit,
              height: hit,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: dimmed ? 0.28 : 1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accent
                          : Theme.of(context).colorScheme.surface,
                      width: isSelected ? 3 : 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Coarse silhouette of Thailand, authored in a 200x340 box.
///
/// Intentionally stylised: it has to read as "Thailand" at 130px wide, not
/// survive a cartographic audit.
class _ThailandOutlinePainter extends CustomPainter {
  const _ThailandOutlinePainter({
    required this.fill,
    required this.stroke,
    required this.grid,
  });

  final Color fill;
  final Color stroke;
  final Color grid;

  static final Path _outline = Path()
    ..moveTo(112, 24)
    ..cubicTo(96, 30, 82, 40, 74, 56)
    ..cubicTo(66, 72, 70, 86, 80, 96)
    ..cubicTo(70, 108, 62, 122, 64, 136)
    ..cubicTo(66, 152, 78, 162, 86, 174)
    ..cubicTo(92, 186, 90, 202, 94, 216)
    ..cubicTo(98, 230, 106, 238, 108, 252)
    ..cubicTo(110, 268, 104, 286, 106, 302)
    ..cubicTo(108, 318, 114, 330, 116, 336)
    ..cubicTo(122, 330, 124, 318, 122, 306)
    ..cubicTo(120, 292, 114, 280, 114, 266)
    ..cubicTo(114, 250, 122, 238, 130, 226)
    ..cubicTo(138, 214, 140, 198, 136, 184)
    ..cubicTo(132, 170, 124, 162, 126, 148)
    ..cubicTo(128, 132, 142, 124, 150, 110)
    ..cubicTo(158, 96, 156, 78, 148, 64)
    ..cubicTo(140, 50, 126, 34, 112, 24)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 200, size.height / 340);

    // Woven cross-hatch: the map shares the product placeholders' material, so
    // the screen reads as one set rather than two.
    final Paint thread = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (double x = 0; x < 200; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset(x, 340), thread);
    }
    for (double y = 0; y < 340; y += 8) {
      canvas.drawLine(Offset(0, y), Offset(200, y), thread);
    }

    canvas.drawPath(_outline, Paint()..color = fill);
    canvas.drawPath(
      _outline,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ThailandOutlinePainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.stroke != stroke ||
      oldDelegate.grid != grid;
}

// ---------------------------------------------------------------------------
// Province list
// ---------------------------------------------------------------------------

class _ProvinceCard extends StatelessWidget {
  const _ProvinceCard({
    required this.tally,
    required this.selected,
    required this.onTap,
  });

  final ProvinceTally tally;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color tone = regionColor(tally.region);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String shortRegion = tally.region.label.replaceFirst('ภาค', '');

    return Semantics(
      button: true,
      selected: selected,
      label:
          '${tally.name} ภาค$shortRegion ${tally.storeCount} ร้าน '
          '${tally.productCount} สินค้า',
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: selected ? AppColors.accent : scheme.outlineVariant,
                width: selected ? 2.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  tally.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headlineSmall,
                ),
                Text(
                  '$shortRegion · ${tally.storeCount} ร้าน · ${tally.productCount} สินค้า',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tone,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProvinceStores extends StatelessWidget {
  const _ProvinceStores({
    required this.province,
    required this.stores,
    required this.onBack,
  });

  final String province;
  final List<StoreModel> stores;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final List<StoreModel> sorted = <StoreModel>[...stores]
      ..sort(
        (StoreModel a, StoreModel b) => b.ratingCount.compareTo(a.ratingCount),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppSectionLabel(
          sorted.isEmpty
              ? '$province · ยังไม่มีร้าน'
              : '$province · ${sorted.length} ร้าน',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.cardGutter,
            0,
            AppSpacing.cardGutter,
            AppSpacing.md,
          ),
          child: AppChip(label: 'กลับไปรายชื่อจังหวัด', onTap: onBack),
        ),
        if (sorted.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxl),
            child: EmptyView(
              icon: Icons.storefront_outlined,
              title: 'ยังไม่มีร้านใน$province',
              body: 'ลองดูจังหวัดอื่น หรือกลับไปหน้าแรก',
              actionLabel: 'เลือกสินค้า',
              onAction: () => context.go(AppRoutes.home),
            ),
          )
        else
          for (int i = 0; i < sorted.length; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.cardGutter,
                0,
                AppSpacing.cardGutter,
                AppSpacing.sm + 2,
              ),
              child: _StoreRow(store: sorted[i], index: i + 1),
            ),
      ],
    );
  }
}

class _StoreRow extends StatelessWidget {
  const _StoreRow({required this.store, required this.index});

  final StoreModel store;
  final int index;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push(AppRoutes.stores),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 18,
            child: Text('$index', style: AppTextStyles.labelMedium),
          ),
          WeaveTexture(
            color: _weaveForStore(store),
            width: 56,
            height: 56,
            radius: AppRadius.chunky,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  store.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelLarge,
                ),
                Text(
                  <String>[
                    if (store.community.isNotEmpty) store.community,
                    if (store.province.isNotEmpty) store.province,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  /// A store with a logo gets the photo; otherwise it gets a weave placeholder
  /// tinted by region so the list still reads geographically.
  static Color _weaveForStore(StoreModel store) {
    if (store.logoUrl != null && store.logoUrl!.isNotEmpty) {
      return AppColors.weaveIndigo;
    }
    return switch (store.regionEnum) {
      ThaiRegion.north => AppColors.regionNorth,
      ThaiRegion.northeast => AppColors.regionNortheast,
      ThaiRegion.central => AppColors.regionCentral,
      ThaiRegion.east => AppColors.regionEast,
      ThaiRegion.west => AppColors.regionWest,
      ThaiRegion.south => AppColors.regionSouth,
      null => AppColors.weaveGreen,
    };
  }
}
