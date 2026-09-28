import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

/// Injected once and overridden in tests with a fake.
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) => AuthRepository());

/// The signed-in profile, or null when signed out.
///
/// Built from [AuthRepository.authStateChanges] so the router can react to
/// sign-in/sign-out without a second listener, and the profile document is
/// re-read on every auth event so a role change shows up immediately.
final StreamProvider<UserModel?> authUserProvider = StreamProvider<UserModel?>((
  Ref ref,
) async* {
  final AuthRepository repository = ref.watch(authRepositoryProvider);
  await for (final User? user in repository.authStateChanges()) {
    if (user == null) {
      yield null;
    } else {
      yield await repository.loadUser(user.uid);
    }
  }
});

/// Shorthand for screens that only need the sign-in/out actions.
final Provider<AuthRepository> authActionsProvider = Provider<AuthRepository>(
  (Ref ref) => ref.watch(authRepositoryProvider),
);
