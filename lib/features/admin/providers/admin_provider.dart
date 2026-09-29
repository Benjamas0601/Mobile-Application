import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/store_model.dart';
import '../../../models/user_model.dart';
import '../repositories/admin_repository.dart';

final Provider<AdminRepository> adminRepositoryProvider =
    Provider<AdminRepository>((Ref ref) => AdminRepository());

final FutureProvider<List<StoreModel>> adminStoresProvider =
    FutureProvider<List<StoreModel>>((Ref ref) {
      return ref.watch(adminRepositoryProvider).listStores();
    });

final FutureProvider<List<UserModel>> adminUsersProvider =
    FutureProvider<List<UserModel>>((Ref ref) {
      return ref.watch(adminRepositoryProvider).listUsers();
    });

final FutureProvider<List<AdminAffiliateRecord>> adminAffiliatesProvider =
    FutureProvider<List<AdminAffiliateRecord>>((Ref ref) {
      return ref.watch(adminRepositoryProvider).listAffiliates();
    });
