/// Domain enumerations shared across models, repositories and UI.
///
/// Every enum stores both a machine value (used in Firestore) and a Thai
/// display label. Keeping the Firestore value in one place means a rename
/// in the database is a one-line change here rather than a search across
/// the whole codebase.
library;

/// Who the account acts as. A single account may hold several roles -
/// that is intentional and matches how real OTOP sellers often also promote
/// their own products.
/// ค่าบทบาทที่เก็บในฐานข้อมูลและป้ายภาษาไทยที่แสดงใน UI
/// บทบาท `affiliate` ถูกลบออกไปแล้ว (6 ต.ค. 2569) — สมัครสดได้แค่
/// customer/seller ส่วน admin สร้างผ่าน Firestore โดยตรงเท่านั้น
/// (ตรงกับ hasOnly ใน `firestore.rules` users.create / users.update)
enum UserRole {
  customer('customer', 'ลูกค้า'),
  seller('seller', 'ผู้ขาย OTOP'),
  admin('admin', 'ผู้ดูแลระบบ');

  const UserRole(this.value, this.label);

  /// Value persisted in Firestore.
  final String value;

  /// Thai label shown in the UI.
  final String label;

  static UserRole? fromValue(String? value) {
    if (value == null) return null;
    for (final UserRole role in UserRole.values) {
      if (role.value == value) return role;
    }
    return null;
  }
}

/// The six Thai regions, used for "Explore Thailand" grouping.
///
/// [UserRole] ordering above is unrelated; this list is geographic.
enum ThaiRegion {
  north('north', 'ภาคเหนือ', 'เชียงใหม่ แม่ฮ่องสอน เชียงราย'),
  northeast('northeast', 'ภาคอีสาน', 'นครราชสีมา อุดรธานี บุรีรัมย์'),
  central('central', 'ภาคกลาง', 'อยุธยา สุราษฎร์ธานี นครปฐม'),
  east('east', 'ภาคตะวันออก', 'ระยอง จันทบุรี ตราด'),
  west('west', 'ภาคตะวันตก', 'กาญจนบุรี ราชบุรี เพชรบุรี'),
  south('south', 'ภาคใต้', 'สงขลา สุราษฎร์ธานี นครศรีธรรมราช');

  const ThaiRegion(this.value, this.label, this.exampleProvinces);

  final String value;
  final String label;

  /// Shown on the region card so a first-time user understands the scope
  /// without opening it.
  final String exampleProvinces;

  static ThaiRegion? fromValue(String? value) {
    if (value == null) return null;
    for (final ThaiRegion region in ThaiRegion.values) {
      if (region.value == value) return region;
    }
    return null;
  }
}

/// Product lifecycle as controlled by the seller.
enum ProductStatus {
  draft('draft', 'ฉบับร่าง'),
  active('active', 'ขายอยู่'),
  outOfStock('out_of_stock', 'สินค้าหมด'),
  archived('archived', 'เก็บเข้าคลัง');

  const ProductStatus(this.value, this.label);

  final String value;
  final String label;

  /// Only [active] products appear in search and category listings.
  bool get isVisibleToCustomers => this == ProductStatus.active;

  static ProductStatus fromValue(String? value) {
    return ThaiEnumLookup.firstOrNull(
          ProductStatus.values,
          (e) => e.value == value,
        ) ??
        ProductStatus.draft;
  }
}

/// Order fulfilment. Deliberately short — every extra state is a UI
/// surface the seller has to understand, and OTOP sellers mostly ship
/// in one or two batches per week.
enum OrderStatus {
  pendingPayment('pending_payment', 'รอชำระเงิน'),
  paid('paid', 'ชำระแล้ว'),
  awaitingShipment('awaiting_shipment', 'รอจัดส่ง'),
  shipped('shipped', 'จัดส่งแล้ว'),
  completed('completed', 'จัดส่งสำเร็จ'),
  cancelled('cancelled', 'ยกเลิก');

  const OrderStatus(this.value, this.label);

  final String value;
  final String label;

  /// Statuses the seller is allowed to move an order to.
  List<OrderStatus> get allowedNext => switch (this) {
    OrderStatus.pendingPayment => const <OrderStatus>[
      OrderStatus.paid,
      OrderStatus.cancelled,
    ],
    OrderStatus.paid => const <OrderStatus>[
      OrderStatus.awaitingShipment,
      OrderStatus.cancelled,
    ],
    OrderStatus.awaitingShipment => const <OrderStatus>[OrderStatus.shipped],
    OrderStatus.shipped => const <OrderStatus>[OrderStatus.completed],
    OrderStatus.completed => const <OrderStatus>[],
    OrderStatus.cancelled => const <OrderStatus>[],
  };

  static OrderStatus fromValue(String? value) {
    return ThaiEnumLookup.firstOrNull(
          OrderStatus.values,
          (e) => e.value == value,
        ) ??
        OrderStatus.pendingPayment;
  }
}

/// Payment lifecycle, kept separate from [OrderStatus] so payment and
/// fulfilment can be reasoned about (and audited) independently.
enum PaymentStatus {
  unpaid('unpaid', 'ยังไม่ชำระ'),
  awaitingTransfer('awaiting_transfer', 'รอโอนเงิน'),
  submitted('submitted', 'ส่งหลักฐานแล้ว'),
  verified('verified', 'ตรวจสอบแล้ว'),
  failed('failed', 'ชำระไม่สำเร็จ'),
  refunded('refunded', 'คืนเงินแล้ว');

  const PaymentStatus(this.value, this.label);

  final String value;
  final String label;

  static PaymentStatus fromValue(String? value) {
    return ThaiEnumLookup.firstOrNull(
          PaymentStatus.values,
          (e) => e.value == value,
        ) ??
        PaymentStatus.unpaid;
  }
}

/// How a coupon reduces the total.
enum DiscountType {
  percentage('percentage', 'เปอร์เซ็นต์'),
  fixedAmount('fixed_amount', 'จำนวนเงิน');

  const DiscountType(this.value, this.label);

  final String value;
  final String label;

  static DiscountType fromValue(String? value) {
    return ThaiEnumLookup.firstOrNull(
          DiscountType.values,
          (e) => e.value == value,
        ) ??
        DiscountType.fixedAmount;
  }
}

/// How the buyer paid, kept separate from [PaymentStatus] so the chosen
/// channel and its state can change independently.
enum PaymentMethod {
  promptPay('promptpay', 'พร้อมเพย์'),
  bankTransfer('bank_transfer', 'โอนผ่านธนาคาร'),
  cashOnDelivery('cash_on_delivery', 'เก็บเงินปลายทาง');

  const PaymentMethod(this.value, this.label);

  final String value;
  final String label;

  /// Only channels that need a slip image to prove the transfer.
  bool get requiresSlip => this != PaymentMethod.cashOnDelivery;

  static PaymentMethod fromValue(String? value) {
    return ThaiEnumLookup.firstOrNull(
          PaymentMethod.values,
          (e) => e.value == value,
        ) ??
        PaymentMethod.bankTransfer;
  }
}

/// Content shape of a chat message.
enum MessageType {
  text('text', 'ข้อความ'),
  image('image', 'รูปภาพ'),
  system('system', 'ระบบ');

  const MessageType(this.value, this.label);

  final String value;
  final String label;

  static MessageType fromValue(String? value) {
    return ThaiEnumLookup.firstOrNull(
          MessageType.values,
          (e) => e.value == value,
        ) ??
        MessageType.text;
  }
}

/// What triggers a notification, which decides the icon shown in the list.
enum NotificationType {
  orderStatus('order_status', 'สถานะคำสั่งซื้อ'),
  newMessage('new_message', 'ข้อความใหม่'),
  promotion('promotion', 'โปรโมชั่น'),
  reviewReply('review_reply', 'ตอบรีวิว'),
  system('system', 'ระบบ');

  const NotificationType(this.value, this.label);

  final String value;
  final String label;

  static NotificationType fromValue(String? value) {
    return ThaiEnumLookup.firstOrNull(
          NotificationType.values,
          (e) => e.value == value,
        ) ??
        NotificationType.system;
  }
}

/// Result shape shared by every asynchronous state in the app.
///
/// Using one sealed class everywhere is what lets the UI render
/// loading / success / empty / error consistently (see `StateViews`).
sealed class AsyncValue<T> {
  const AsyncValue();

  const factory AsyncValue.idle() = Idle<T>;
  const factory AsyncValue.loading() = Loading<T>;
  const factory AsyncValue.data(T value) = Data<T>;
  const factory AsyncValue.failure(String message) = Failure<T>;
}

class Idle<T> extends AsyncValue<T> {
  const Idle();
}

class Loading<T> extends AsyncValue<T> {
  const Loading();
}

class Data<T> extends AsyncValue<T> {
  const Data(this.value);
  final T value;
}

class Failure<T> extends AsyncValue<T> {
  const Failure(this.message);
  final String message;
}

/// Tiny generic helper so the `fromValue` lookups above stay one line each.
class ThaiEnumLookup {
  ThaiEnumLookup._();

  static T? firstOrNull<T>(Iterable<T> values, bool Function(T) test) {
    for (final T value in values) {
      if (test(value)) return value;
    }
    return null;
  }
}
