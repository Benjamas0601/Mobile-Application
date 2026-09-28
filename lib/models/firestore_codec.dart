/// Type-safe readers and writers for raw Firestore documents.
///
/// Firestore hands back `Map<String, dynamic>` where a number may arrive as
/// `int` or `double`, a date as `Timestamp`, and a missing key as `null`.
/// Casting that by hand in every model is where `as int` crashes come from,
/// so all conversion lives here and models stay declarative.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads a single document map with a fallback for every field.
class FirestoreReader {
  FirestoreReader(this._data);

  /// Builds a reader from a snapshot, treating a missing document as empty
  /// so callers never need a null check on `exists()` first.
  factory FirestoreReader.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return FirestoreReader(doc.data() ?? const <String, dynamic>{});
  }

  final Map<String, dynamic> _data;

  /// The untouched map, for fields this reader does not model yet.
  Map<String, dynamic> get raw => Map<String, dynamic>.unmodifiable(_data);

  bool has(String key) => _data.containsKey(key) && _data[key] != null;

  String string(String key, {String fallback = ''}) {
    final Object? value = _data[key];
    if (value is String) return value;
    return fallback;
  }

  String? stringOrNull(String key) {
    final Object? value = _data[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  int integer(String key, {int fallback = 0}) {
    final Object? value = _data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  double decimal(String key, {double fallback = 0}) {
    final Object? value = _data[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  bool boolean(String key, {bool fallback = false}) {
    final Object? value = _data[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return fallback;
  }

  /// Returns null when the field is missing or unparsable, which lets a
  /// model treat "no timestamp yet" differently from "epoch zero".
  DateTime? dateTime(String key) {
    final Object? value = _data[key];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  DateTime dateTimeOr(String key, DateTime fallback) =>
      dateTime(key) ?? fallback;

  List<String> stringList(String key) {
    final Object? value = _data[key];
    if (value is! List) return const <String>[];
    return List<String>.unmodifiable(value.whereType<String>());
  }

  /// Reads a list of sub-documents (e.g. the `items` array on an order).
  List<Map<String, dynamic>> mapList(String key) {
    final Object? value = _data[key];
    if (value is! List) return const <Map<String, dynamic>>[];
    return List<Map<String, dynamic>>.unmodifiable(
      value.whereType<Map>().map(
        (Map<Object?, Object?> e) => e.cast<String, dynamic>(),
      ),
    );
  }

  /// Reads an embedded map (e.g. `shippingAddress`) and hands it to [build].
  T? nested<T>(String key, T Function(FirestoreReader reader) build) {
    final Object? value = _data[key];
    if (value is! Map) return null;
    return build(FirestoreReader(value.cast<String, dynamic>()));
  }
}

/// Builds the map written back to Firestore.
///
/// The explicit `put` helpers make every write a deliberate, reviewable
/// line — no `Map.fromEntries` with string keys scattered through a model.
class FirestoreWriter {
  final Map<String, dynamic> _data = <String, dynamic>{};

  FirestoreWriter put(String key, Object? value) {
    if (value != null) _data[key] = value;
    return this;
  }

  /// Stores a `DateTime` as a Firestore `Timestamp` so range queries and
  /// `orderBy('createdAt')` behave correctly.
  FirestoreWriter putDate(String key, DateTime? value) {
    if (value != null) _data[key] = Timestamp.fromDate(value);
    return this;
  }

  FirestoreWriter putList(String key, List<Object?> values) {
    if (values.isNotEmpty) _data[key] = values;
    return this;
  }

  Map<String, dynamic> get build => Map<String, dynamic>.unmodifiable(_data);
}
