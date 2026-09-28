import 'firestore_codec.dart';

/// A `categories/{categoryId}` document — the top level of browsing.
class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.icon,
    required this.sortOrder,
    this.active = true,
  });

  final String id;
  final String name;

  /// URL-safe identifier, kept for future share links.
  final String slug;

  /// Emoji used as the category badge — deliberately not an image file so the
  /// app needs no bundled icon set for 10+ categories.
  final String icon;

  final int sortOrder;
  final bool active;

  factory CategoryModel.fromFirestore(String id, Map<String, dynamic> data) {
    final FirestoreReader r = FirestoreReader(data);
    return CategoryModel(
      id: id,
      name: r.string('name'),
      slug: r.string('slug'),
      icon: r.string('icon'),
      sortOrder: r.integer('sortOrder'),
      active: r.boolean('active', fallback: true),
    );
  }
}
