import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:thai_otop_marketplace/core/constants/app_enums.dart';
import 'package:thai_otop_marketplace/core/constants/app_strings.dart';
import 'package:thai_otop_marketplace/core/routes/app_router.dart';
import 'package:thai_otop_marketplace/core/services/auth/login_attempt_guard.dart';
import 'package:thai_otop_marketplace/features/auth/screens/login_screen.dart';
import 'package:thai_otop_marketplace/models/user_model.dart';
import 'package:thai_otop_marketplace/providers/auth_provider.dart';
import 'package:thai_otop_marketplace/repositories/auth_repository.dart';

const UserModel _customer = UserModel(
  uid: 'u1',
  displayName: 'ลูกค้าทดสอบ',
  email: 'customer@example.com',
);

/// Minimal auth double: the login screen only needs [signIn].
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.failure});

  /// When set, every sign-in throws this instead of comparing passwords.
  final AuthFailure? failure;

  int signInCalls = 0;

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls += 1;
    final AuthFailure? fail = failure;
    if (fail != null) throw fail;
    if (password != 'correct') {
      throw const AuthFailure(
        AppStrings.errInvalidCredentials,
        kind: AuthFailureKind.invalidCredentials,
      );
    }
    return _customer;
  }

  @override
  Stream<User?> authStateChanges() => Stream<User?>.empty();

  @override
  User? get currentAuthUser => null;

  @override
  Future<UserModel?> loadUser(String uid) async => _customer;

  @override
  Future<UserModel?> loadCurrentUser() async => _customer;

  @override
  Future<UserModel> register({
    required String email,
    required String password,
    required String displayName,
    required String phone,
    required String province,
    required UserRole accountType,
    String storeName = '',
    String community = '',
    String storeDescription = '',
    String region = '',
  }) => throw UnimplementedError();

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<UserModel> updateProfile({
    required String displayName,
    required String phone,
  }) => throw UnimplementedError();
}

void main() {
  group('LoginAttemptGuard', () {
    late DateTime now;
    late LoginAttemptGuard guard;

    setUp(() {
      now = DateTime(2026, 10, 23, 12);
      guard = LoginAttemptGuard(clock: () => now);
      addTearDown(guard.dispose);
    });

    test('allows two wrong passwords and locks on the third', () {
      guard.recordFailure('customer@example.com');
      expect(guard.isLocked('customer@example.com'), isFalse);
      expect(guard.attemptsLeft('customer@example.com'), 2);

      guard.recordFailure('customer@example.com');
      expect(guard.isLocked('customer@example.com'), isFalse);
      expect(guard.attemptsLeft('customer@example.com'), 1);

      guard.recordFailure('customer@example.com');
      expect(guard.isLocked('customer@example.com'), isTrue);
      expect(guard.remainingLock('customer@example.com'), guard.lockDuration);
      expect(guard.attemptsLeft('customer@example.com'), 0);
    });

    test('counts down and gives three fresh attempts after one minute', () {
      for (int i = 0; i < 3; i++) {
        guard.recordFailure('customer@example.com');
      }

      now = now.add(const Duration(seconds: 30));
      expect(guard.isLocked('customer@example.com'), isTrue);
      expect(
        guard.remainingLock('customer@example.com'),
        const Duration(seconds: 30),
      );

      now = now.add(const Duration(seconds: 31));
      expect(guard.isLocked('customer@example.com'), isFalse);
      expect(guard.attemptsLeft('customer@example.com'), 3);
    });

    test('a wrong password during the lock does not extend it', () {
      for (int i = 0; i < 3; i++) {
        guard.recordFailure('customer@example.com');
      }
      now = now.add(const Duration(seconds: 40));

      guard.recordFailure('customer@example.com');

      expect(
        guard.remainingLock('customer@example.com'),
        const Duration(seconds: 20),
      );
    });

    test('a successful sign-in clears earlier misses', () {
      guard.recordFailure('customer@example.com');
      guard.recordFailure('customer@example.com');

      guard.recordSuccess('customer@example.com');

      expect(guard.isLocked('customer@example.com'), isFalse);
      expect(guard.attemptsLeft('customer@example.com'), 3);
    });

    test('matches emails regardless of case and surrounding spaces', () {
      guard.recordFailure('  Customer@Example.COM ');
      guard.recordFailure('customer@example.com');
      guard.recordFailure('CUSTOMER@example.com');

      expect(guard.isLocked('customer@example.com '), isTrue);
    });

    test('locking one account leaves other accounts free', () {
      for (int i = 0; i < 3; i++) {
        guard.recordFailure('a@example.com');
      }

      expect(guard.isLocked('a@example.com'), isTrue);
      expect(guard.isLocked('b@example.com'), isFalse);
      expect(guard.attemptsLeft('b@example.com'), 3);
    });
  });

  group('login screen lockout', () {
    late DateTime now;
    late ProviderContainer container;

    void setUpContainer(_FakeAuthRepository repo) {
      now = DateTime(2026, 10, 23, 12);
      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          loginAttemptGuardProvider.overrideWith((Ref ref) {
            final LoginAttemptGuard guard = LoginAttemptGuard(
              clock: () => now,
            );
            ref.onDispose(guard.dispose);
            return guard;
          }),
        ],
      );
      addTearDown(container.dispose);
    }

    Future<void> pumpLogin(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
    }

    Future<void> enterCredentials(
      WidgetTester tester,
      String password,
    ) async {
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'customer@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), password);
    }

    Future<void> tapSignIn(WidgetTester tester) async {
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    FilledButton signInButton(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byType(FilledButton));

    testWidgets('shows how many attempts are left after one miss', (
      WidgetTester tester,
    ) async {
      setUpContainer(_FakeAuthRepository());
      await pumpLogin(tester);

      await enterCredentials(tester, 'wrong12');
      await tapSignIn(tester);

      expect(find.text(AppStrings.loginAttemptsLeft(2)), findsOneWidget);
      expect(signInButton(tester).onPressed, isNotNull);
    });

    testWidgets('locks for a minute after three misses, then unlocks', (
      WidgetTester tester,
    ) async {
      setUpContainer(_FakeAuthRepository());
      await pumpLogin(tester);
      await enterCredentials(tester, 'wrong12');

      await tapSignIn(tester);
      await tapSignIn(tester);
      await tapSignIn(tester);

      // The red invalid-credentials banner is replaced by the amber lock
      // banner, and the button is disabled while counting down.
      expect(
        find.text(AppStrings.loginLockedFor(3, 60)),
        findsOneWidget,
      );
      expect(signInButton(tester).onPressed, isNull);
      expect(find.text(AppStrings.login), findsNothing);

      // The keyboard "done" action must not sneak past the lock either.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(container.read(loginAttemptGuardProvider).isLocked(
        'customer@example.com',
      ), isTrue);

      // One minute later the ticker repaints the form and the button returns.
      now = now.add(const Duration(seconds: 61));
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('กรุณารออีก'), findsNothing);
      expect(signInButton(tester).onPressed, isNotNull);
      expect(find.text(AppStrings.login), findsOneWidget);
    });

    testWidgets('switching to another email lifts the lock for that account', (
      WidgetTester tester,
    ) async {
      setUpContainer(_FakeAuthRepository());
      await pumpLogin(tester);
      await enterCredentials(tester, 'wrong12');

      await tapSignIn(tester);
      await tapSignIn(tester);
      await tapSignIn(tester);
      expect(signInButton(tester).onPressed, isNull);

      // A different account was never locked, so the button must come back as
      // soon as the email field changes (no need to wait for the ticker).
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'another@example.com',
      );
      await tester.pump();

      expect(find.textContaining('กรุณารออีก'), findsNothing);
      expect(signInButton(tester).onPressed, isNotNull);

      // Let the original account's cooldown finish so no timer outlives the
      // widget test.
      now = now.add(const Duration(seconds: 61));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a network failure never burns an attempt', (
      WidgetTester tester,
    ) async {
      setUpContainer(
        _FakeAuthRepository(
          failure: const AuthFailure(
            'เชื่อมต่ออินเทอร์เน็ตไม่สำเร็จ กรุณาลองใหม่',
            kind: AuthFailureKind.network,
          ),
        ),
      );
      await pumpLogin(tester);
      await enterCredentials(tester, 'wrong12');

      await tapSignIn(tester);
      await tapSignIn(tester);
      await tapSignIn(tester);

      expect(find.textContaining('กรุณารออีก'), findsNothing);
      expect(
        container.read(loginAttemptGuardProvider).isLocked(
          'customer@example.com',
        ),
        isFalse,
      );
      expect(signInButton(tester).onPressed, isNotNull);
    });

    testWidgets('a correct password clears the counter', (
      WidgetTester tester,
    ) async {
      setUpContainer(_FakeAuthRepository());
      final GoRouter router = GoRouter(
        initialLocation: AppRoutes.login,
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.login,
            builder: (BuildContext context, GoRouterState state) =>
                const LoginScreen(),
          ),
          GoRoute(
            path: AppRoutes.home,
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(body: Text('HOME')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await enterCredentials(tester, 'wrong12');
      await tapSignIn(tester);
      await tapSignIn(tester);
      expect(
        container.read(loginAttemptGuardProvider).attemptsLeft(
          'customer@example.com',
        ),
        1,
      );

      await enterCredentials(tester, 'correct');
      await tapSignIn(tester);
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
      expect(
        container.read(loginAttemptGuardProvider).attemptsLeft(
          'customer@example.com',
        ),
        3,
      );
    });
  });
}
