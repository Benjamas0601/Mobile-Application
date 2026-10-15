import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product_model.dart';
import '../models/user_model.dart';
import '../repositories/favorite_repository.dart';
import 'auth_provider.dart';
import 'catalog_provider.dart';

/// จุดฉีดคลังรายการถูกใจ — เทสต์แทนที่ด้วย fake เพื่อไม่ต้องใช้ Firestore จริง
final Provider<FavoriteRepository> favoriteRepositoryProvider =
    Provider<FavoriteRepository>((Ref ref) => FavoriteRepository());

/// รหัสสินค้าที่ผู้ใช้ที่ล็อกอินอยู่กดถูกใจ เรียงจากใหม่ไปเก่า
///
/// ผู้ที่ยังไม่ล็อกอินจะได้รายการว่างและไม่เปิด listener ไปที่ Firestore เลย
/// จึงปลอดภัยที่จะให้การ์ดสินค้าทุกใบอ่านค่านี้แม้อยู่ในโหมดผู้เยี่ยมชม
final StreamProvider<List<String>> myFavoriteIdsProvider =
    StreamProvider.autoDispose<List<String>>((Ref ref) {
      final UserModel? user = ref.watch(authUserProvider).asData?.value;
      if (user == null) {
        return Stream<List<String>>.value(const <String>[]);
      }
      return ref.watch(favoriteRepositoryProvider).watchMyFavoriteIds();
    });

/// สินค้านี้ถูกใจอยู่หรือไม่ — ใช้กับการ์ดสินค้าและหน้ารายละเอียด
final isFavoriteProvider = Provider.autoDispose.family<bool, String>(
  (Ref ref, String productId) {
    final List<String> ids =
        ref.watch(myFavoriteIdsProvider).asData?.value ?? const <String>[];
    return ids.contains(productId);
  },
);

/// สินค้าที่ผู้ใช้กดถูกใจ พร้อมข้อมูลสดจาก Firestore
///
/// สมัครใหม่ทุกครั้งที่ชุดรหัสถูกใจเปลี่ยน — สินค้าที่ถูกลบ/ซ่อนจะถูกตัดออก
final StreamProvider<List<ProductModel>> favoriteProductsProvider =
    StreamProvider.autoDispose<List<ProductModel>>((Ref ref) async* {
      final List<String> ids = await ref.watch(myFavoriteIdsProvider.future);
      if (ids.isEmpty) {
        yield const <ProductModel>[];
        return;
      }
      yield* ref.watch(catalogRepositoryProvider).watchProductsByIds(ids);
    });

/// สลับสถานะถูกใจของสินค้าหนึ่งชิ้น — โยนเมื่อยังไม่ได้เข้าสู่ระบบ
final Provider<Future<void> Function(String productId)> toggleFavoriteProvider =
    Provider<Future<void> Function(String productId)>((Ref ref) {
      final FavoriteRepository repository = ref.watch(
        favoriteRepositoryProvider,
      );
      return (String productId) async {
        final bool isFavorite = ref.read(isFavoriteProvider(productId));
        await repository.setFavorite(productId, !isFavorite);
      };
    });
