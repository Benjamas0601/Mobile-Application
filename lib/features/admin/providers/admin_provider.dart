import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/store_model.dart';
import '../../../models/user_model.dart';
import '../repositories/admin_repository.dart';

/// จุดฉีด repository ของแอดมิน เพื่อให้ทดสอบหน้าจอโดยใช้ข้อมูลจำลองได้
final Provider<AdminRepository> adminRepositoryProvider =
    Provider<AdminRepository>((Ref ref) => AdminRepository());

/// Live (snapshot-based) lists so a store/user signed up elsewhere appears in
/// the admin tabs without a manual refresh — a one-shot `get()` would cache
/// the first read and miss new documents forever.
final StreamProvider<List<StoreModel>> adminStoresProvider =
    StreamProvider<List<StoreModel>>((Ref ref) {
      return ref.watch(adminRepositoryProvider).watchStores();
    });

final StreamProvider<List<UserModel>> adminUsersProvider =
    StreamProvider<List<UserModel>>((Ref ref) {
      return ref.watch(adminRepositoryProvider).watchUsers();
    });
