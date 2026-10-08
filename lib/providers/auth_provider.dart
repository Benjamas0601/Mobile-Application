import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

/// Injected once and overridden in tests with a fake.
/// จุดฉีด AuthRepository เพื่อให้หน้าจอทดสอบแทนที่ด้วย fake ได้
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) => AuthRepository());

/// โปรไฟล์ของผู้ใช้ที่ล็อกอินอยู่ หรือ null เมื่อยังไม่ได้ล็อกอิน
///
/// สร้างจาก [AuthRepository.authStateChanges] เพื่อให้ router ตอบสนองการ
/// เข้า/ออกระบบได้โดยไม่ต้องมี listener ซ้ำ และอ่านโปรไฟล์ใหม่ทุกครั้งที่มี
/// auth event เพื่อให้การเปลี่ยนบทบาทแสดงผลทันที
///
/// หน้าจอที่เพิ่งเขียนโปรไฟล์ (เช่น หน้าสมัคร) ต้องเรียก
/// `ref.invalidate(authUserProvider)` ตามหลัง เพราะตอนสมัคร auth stream
/// ปล่อย event *ก่อน* ที่เอกสาร `users/{uid}` จะถูกเขียนเสร็จ — ถ้าไม่อ่านซ้ำ
/// provider จะค้างค่า null จนกว่าจะมี auth event ใหม่ และ greeting บนหน้า
/// home จะไม่แสดงชื่อผู้ใช้
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
