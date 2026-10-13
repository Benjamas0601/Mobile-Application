import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/screens/admin_home_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/cart/screens/cart_screen.dart';
import '../../features/cart/screens/checkout_screen.dart';
import '../../features/cart/screens/payment_screen.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../../features/chat/screens/chat_thread_screen.dart';
import '../../features/coupons/screens/coupon_list_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/notifications/screens/notification_list_screen.dart';
import '../../features/orders/screens/order_detail_screen.dart';
import '../../features/orders/screens/order_list_screen.dart';
import '../../features/orders/screens/order_tracking_screen.dart';
import '../../features/products/screens/product_detail_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/seller/screens/product_edit_screen.dart';
import '../../features/seller/screens/seller_home_screen.dart';
import '../../features/seller/screens/seller_order_list_screen.dart';
import '../../features/seller/screens/seller_product_list_screen.dart';
import '../../features/seller/screens/seller_store_edit_screen.dart';
import '../../features/stores/screens/stores_screen.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';

/// รวม path ของหน้าจอต่าง ๆ ไว้ที่เดียว เพื่อป้องกันการพิมพ์ path ผิด
/// และช่วยให้ตรวจสอบภาพรวมการนำทางของแอปได้ง่าย
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String stores = '/stores';
  static const String orders = '/orders';
  static const String ordersHistory = '/order-history';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String payment = '/checkout/payment';
  static const String profile = '/profile';

  /// หน้ารายการคูปองของผู้ซื้อ — เข้าถึงได้โดยไม่ต้องล็อกอิน
  static const String coupons = '/coupons';

  /// หน้ากล่องแจ้งเตือนในแอป ต้องเข้าสู่ระบบก่อน
  static const String notifications = '/notifications';
  static const String adminRoot = '/admin';

  /// หน้ารายการห้องสนทนาของผู้ซื้อและผู้ขาย
  /// ทุก path ภายใต้ `/chat/...` ต้องเข้าสู่ระบบก่อน
  static const String chat = '/chat';
  static String chatThread(String threadId) => '/chat/$threadId';

  /// หน้าหลักของพื้นที่ผู้ขาย โดยทุก path ภายใต้ `/seller/...` ต้องเข้าสู่ระบบ
  static const String sellerRoot = '/seller';
  static const String sellerProducts = '/seller/products';
  static const String sellerOrders = '/seller/orders';
  static const String sellerStoreProfile = '/seller/store';

  /// สร้าง path รายละเอียดสินค้าจากรหัสสินค้า
  static String productDetail(String productId) => '/product/$productId';

  /// สร้าง path รายละเอียดคำสั่งซื้อจากรหัสคำสั่งซื้อ
  static String orderDetail(String orderId) => '/order/$orderId';

  /// สร้าง path ติดตามสถานะการจัดส่งหลังชำระเงิน
  static String orderTracking(String orderId) => '/order/$orderId/tracking';

  /// สร้าง path เพิ่มสินค้าพร้อมระบุร้านค้าผ่าน query parameter
  static String sellerProductNew(String storeId) =>
      '/seller/products/new?storeId=$storeId';

  /// สร้าง path แก้ไขสินค้าจากรหัสสินค้า
  static String sellerProductEdit(String productId) =>
      '/seller/products/$productId';
}

/// ตรวจสอบสิทธิ์เข้าถึงตำแหน่งปัจจุบัน และคืน path สำหรับเปลี่ยนหน้า
/// หากคืนค่า `null` หมายถึงอนุญาตให้อยู่หน้าปัจจุบันต่อ
///
/// ผู้ใช้ที่ยังไม่เข้าสู่ระบบสามารถเลือกดูสินค้าได้ ส่วนหน้าที่ผูกกับบัญชี
/// เช่น รายการคำสั่งซื้อและพื้นที่ผู้ขาย จะถูกจำกัดสิทธิ์
/// ระหว่างรอสถานะการเข้าสู่ระบบให้ถือว่าเป็นผู้ใช้ทั่วไป เพื่อไม่ให้หน้า
/// ที่ต้องยืนยันตัวตนแสดงขึ้นมาก่อนทราบผล
String? authRedirect({
  required bool signedIn,
  required String location,
  UserModel? user,
}) {
  // ไม่จำกัดหน้า checkout ที่นี่ เพราะหน้านั้นมีขั้นตอนแจ้งทางเลือกให้ผู้ใช้
  // (เข้าสู่ระบบ / สมัครสมาชิก / เลือกซื้อสินค้าต่อ) อยู่แล้ว และรองรับการ
  // กลับมาทำรายการต่อหลังเข้าสู่ระบบ การตรวจที่นี่อาจเปลี่ยนหน้าเร็วเกินไป
  // ขณะที่ข้อมูลโปรไฟล์ยังโหลดไม่เสร็จ
  // พื้นที่ผู้ขายตรวจด้วยเงื่อนไข prefix ด้านล่าง เพื่อให้ครอบคลุมทุกหน้า
  // `/seller/...` แม้จะมีการเพิ่มเส้นทางใหม่ในภายหลัง
  const Set<String> accountRequired = <String>{
    AppRoutes.orders,
    AppRoutes.ordersHistory,
    AppRoutes.profile,
    AppRoutes.chat,
    AppRoutes.notifications,
  };
  final bool isOrderRoute = location.startsWith('/order/');
  final bool isChatRoute =
      location == AppRoutes.chat || location.startsWith('${AppRoutes.chat}/');

  // เส้นทางที่มีพารามิเตอร์ เช่น `/seller/products/p-x` จะมีรหัสจริงแทนที่
  // จึงตรวจด้วยการเทียบค่าในชุด path ไม่ได้ ต้องตรวจทุกหน้าโดยใช้ prefix
  final bool isSellerRoute =
      location.startsWith('${AppRoutes.sellerRoot}/') ||
      location == AppRoutes.sellerRoot;
  final bool isAdminRoute =
      location == AppRoutes.adminRoot ||
      location.startsWith('${AppRoutes.adminRoot}/');

  if (isAdminRoute && user?.isAdmin != true) {
    return signedIn ? AppRoutes.home : '${AppRoutes.login}?redirect=$location';
  }

  // ผู้ใช้ที่เข้าสู่ระบบแล้วแต่ไม่มีบทบาทผู้ขายหรือผู้ดูแลระบบต้องออกจาก
  // พื้นที่ผู้ขาย มิฉะนั้นอาจติดอยู่ที่หน้าตรวจสิทธิ์ภายใน เช่น กรณีมีค่า
  // `redirect` เก่าหลงเหลือหลังเข้าสู่ระบบ จึงส่งกลับหน้าหลักซึ่งปลอดภัย
  // สำหรับผู้ใช้ทุกบทบาท หากโปรไฟล์ยังโหลดไม่เสร็จ (`user == null`) ให้หน้า
  // จัดการสถานะกำลังโหลดของตัวเองก่อน โดยไม่เปลี่ยนเส้นทางในขั้นตอนนี้
  if (signedIn &&
      user != null &&
      isSellerRoute &&
      !user.isSeller &&
      !user.isAdmin) {
    return AppRoutes.home;
  }

  if (!signedIn) {
    if (!accountRequired.contains(location) &&
        !isSellerRoute &&
        !isOrderRoute &&
        !isChatRoute) {
      return null;
    }
    // แนบหน้าปลายทางไปกับพารามิเตอร์ `redirect` เพื่อกลับไปทำรายการเดิม
    // หลังจากเข้าสู่ระบบ แทนการส่งผู้ใช้ไปหน้าหลักเสมอ
    return '${AppRoutes.login}?redirect=$location';
  }

  // เมื่อผู้ดูแลระบบเปิดหน้าหลัก หน้าเข้าสู่ระบบ หรือหน้าสมัครสมาชิก
  // ให้พาไปยังหน้าจัดการผู้ดูแลระบบโดยตรง
  if (user?.isAdmin == true &&
      (location == AppRoutes.home ||
          location == AppRoutes.login ||
          location == AppRoutes.register)) {
    return AppRoutes.adminRoot;
  }

  if (user?.isSeller == true) {
    // ผู้ขายที่เปิดหน้าทั่วไปหรือหน้าเข้าสู่ระบบให้ไปยังแดชบอร์ดผู้ขาย
    if (location == AppRoutes.home ||
        location == AppRoutes.login ||
        location == AppRoutes.register) {
      return AppRoutes.sellerRoot;
    }
  }

  return null;
}

/// Provider สำหรับสร้าง router และเชื่อมการเปลี่ยนเส้นทางกับสถานะผู้ใช้
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    redirect: (BuildContext context, GoRouterState state) => authRedirect(
      // ใช้ `asData` เพื่อให้ได้ค่า null ทั้งระหว่างโหลดและเมื่อออกจากระบบ
      // ซึ่งเพียงพอสำหรับตรวจว่ามีผู้ใช้ที่ยืนยันตัวตนแล้วหรือไม่
      signedIn: ref.read(authUserProvider).asData?.value != null,
      location: state.matchedLocation,
      user: ref.read(authUserProvider).asData?.value,
    ),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.login,
        builder: (BuildContext context, GoRouterState state) =>
            LoginScreen(redirect: state.uri.queryParameters['redirect']),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (BuildContext context, GoRouterState state) =>
            RegisterScreen(redirect: state.uri.queryParameters['redirect']),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (BuildContext context, GoRouterState state) =>
            const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminRoot,
        builder: (BuildContext context, GoRouterState state) =>
            const AdminHomeScreen(),
      ),
      GoRoute(
        path: '/product/:productId',
        builder: (BuildContext context, GoRouterState state) =>
            ProductDetailScreen(
              productId: state.pathParameters['productId'] ?? '',
            ),
      ),
      GoRoute(
        path: AppRoutes.cart,
        builder: (BuildContext context, GoRouterState state) =>
            const CartScreen(),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        builder: (BuildContext context, GoRouterState state) =>
            const CheckoutScreen(),
      ),
      // ขั้นตอนที่สองของ checkout อ่านข้อมูลที่ต้องใช้จาก provider
      // จึงไม่ต้องแนบข้อมูลไว้ใน URL และรองรับการโหลดหน้าซ้ำระหว่างทำรายการ
      GoRoute(
        path: AppRoutes.payment,
        builder: (BuildContext context, GoRouterState state) =>
            const PaymentScreen(),
      ),
      GoRoute(
        path: AppRoutes.stores,
        builder: (BuildContext context, GoRouterState state) =>
            const StoresScreen(),
      ),
      // รายการคำสั่งซื้อเป็นข้อมูลเฉพาะบัญชี จึงต้องเข้าสู่ระบบก่อน
      // ส่วน `/checkout` จัดการแจ้งสิทธิ์ภายในหน้าเอง
      GoRoute(
        path: AppRoutes.orders,
        builder: (BuildContext context, GoRouterState state) =>
            const OrderListScreen(),
      ),
      // ลิงก์ตรงจากหน้าชำระเงิน ให้ผู้ซื้อไปติดตามคำสั่งซื้อที่เพิ่งทำได้ทันที
      GoRoute(
        path: '/order/:orderId/tracking',
        builder: (BuildContext context, GoRouterState state) =>
            OrderTrackingScreen(orderId: state.pathParameters['orderId'] ?? ''),
      ),
      GoRoute(
        path: '/order/:orderId',
        builder: (BuildContext context, GoRouterState state) =>
            OrderDetailScreen(orderId: state.pathParameters['orderId'] ?? ''),
      ),
      // รายการแชทและห้องสนทนา — ต้องล็อกอิน (กันไว้ด้านบนแล้ว)
      GoRoute(
        path: AppRoutes.chat,
        builder: (BuildContext context, GoRouterState state) =>
            const ChatListScreen(),
      ),
      GoRoute(
        path: '/chat/:threadId',
        builder: (BuildContext context, GoRouterState state) =>
            ChatThreadScreen(threadId: state.pathParameters['threadId'] ?? ''),
      ),
      // แก้ไขข้อมูลส่วนตัว — ผู้ล็อกอินทุกบัญชีเข้าถึงได้ (เก็บไว้ใน
      // accountRequired ด้านบน กันผู้ที่ยังไม่ได้ล็อกอินไว้แล้ว)
      GoRoute(
        path: AppRoutes.profile,
        builder: (BuildContext context, GoRouterState state) =>
            const ProfileScreen(),
      ),
      // กล่องแจ้งเตือนในแอป — ต้องล็อกอิน (กันไว้ใน accountRequired ด้านบน)
      GoRoute(
        path: AppRoutes.notifications,
        builder: (BuildContext context, GoRouterState state) =>
            const NotificationListScreen(),
      ),
      // รายการคูปองสำหรับผู้ซื้อ — ไม่ต้องล็อกอิน ด้วยข้อมูลโปรโมชัน
      // เป็นข้อมูลสาธารณะ (read ให้ทุกคน) ส่วนขั้นตอนใช้คูปองจริงยังต้อง
      // ล็อกอินเพราะอยู่บนหน้า checkout อยู่แล้ว
      GoRoute(
        path: AppRoutes.coupons,
        builder: (BuildContext context, GoRouterState state) =>
            const CouponListScreen(),
      ),
      // พื้นที่ผู้ขายต้องเข้าสู่ระบบตาม redirect ด้านบน และตรวจบทบาทซ้ำในหน้า
      // เนื่องจากข้อมูลบทบาทจัดเก็บใน Firestore ไม่ได้อยู่ใน path ของเส้นทาง
      GoRoute(
        path: AppRoutes.sellerRoot,
        builder: (BuildContext context, GoRouterState state) =>
            const SellerHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.sellerOrders,
        builder: (BuildContext context, GoRouterState state) =>
            const SellerOrderListScreen(),
      ),
      GoRoute(
        path: AppRoutes.sellerStoreProfile,
        builder: (BuildContext context, GoRouterState state) =>
            const SellerStoreEditScreen(),
      ),
      GoRoute(
        path: AppRoutes.sellerProducts,
        builder: (BuildContext context, GoRouterState state) =>
            const SellerProductListScreen(),
      ),
      GoRoute(
        path: '/seller/products/new',
        builder: (BuildContext context, GoRouterState state) =>
            ProductEditScreen(storeId: state.uri.queryParameters['storeId']),
      ),
      GoRoute(
        path: '/seller/products/:productId',
        builder: (BuildContext context, GoRouterState state) =>
            ProductEditScreen(
              productId: state.pathParameters['productId'] ?? '',
            ),
      ),
    ],
  );

  // ประเมิน redirect ใหม่ทุกครั้งที่สถานะผู้ใช้เปลี่ยน เช่น เมื่อออกจากระบบ
  // จะได้ไม่ค้างอยู่ในหน้าที่กำลังอ่านข้อมูล Firestore ซึ่งไม่อนุญาตแล้ว
  ref.listen(authUserProvider, (
    AsyncValue<Object?>? _,
    AsyncValue<Object?>? _,
  ) {
    router.refresh();
  });

  ref.onDispose(router.dispose);
  return router;
});
