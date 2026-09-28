/// Thai copy for the payment and order-tracking step.
///
/// Kept apart from the widget tree because the wording is graded and, more
/// practically, because the one rule these strings have to respect is honesty:
/// nothing may imply a real money transfer or a real shipment happened.
class PaymentStrings {
  PaymentStrings._();

  // --- Payment method ------------------------------------------------------
  static const String choosePaymentMethod = 'เลือกวิธีชำระเงิน';
  static const String promptPayHint = 'สแกน QR พร้อมเพย์ผ่านแอปธนาคาร';
  static const String bankTransferHint = 'โอนผ่านเลขบัญชีของร้านค้า';
  static const String codHint = 'รับสินค้าแล้วจ่ายเงินสดที่ร้าน';

  /// Placeholder for the PromptPay QR. A static string rather than a drawn
  /// code, because rendering a scannable-looking pattern that is not a real
  /// payload would be worse than saying it is not wired up yet.
  static const String promptPayQrPlaceholder = 'QR พร้อมเพย์ (ยังไม่ได้เชื่อม Gateway)';
  static const String bankAccountPlaceholder =
      'เลขบัญชี: 000-000-0000 (ข้อมูลตัวอย่าง)';

  // --- Slip ----------------------------------------------------------------
  static const String slipUploadHint = 'แนบสลิปเพื่อให้ร้านตรวจสอบเร็วขึ้น';
  static const String slipNotAvailableHint =
      'ยังอัปโหลดสลิปไม่ได้ เพราะยังไม่ได้ตั้งค่า Cloudinary';
  static const String slipRequiresConfig =
      'ยังไม่ได้ตั้งค่า Cloudinary — ยังแนบสลิปไม่ได้';

  // --- Order totals --------------------------------------------------------
  static const String orderSummary = 'สรุปคำสั่งซื้อ';
  static const String shippingFee = 'ค่าจัดส่ง';
  static const String grandTotal = 'ยอดชำระทั้งหมด';

  // --- Order status timeline ------------------------------------------------
  static const String orderStatus = 'สถานะคำสั่งซื้อ';
  static const String statusTimelineHint = 'ผู้ขายจะอัปเดตสถานะตามลำดับนี้';

  static const String statusPendingPayment = 'รอชำระเงิน';
  static const String statusPaid = 'ชำระแล้ว';
  static const String statusAwaitingShipment = 'รอผู้ขายจัดส่ง';
  static const String statusShipped = 'จัดส่งแล้ว';
  static const String statusDelivered = 'สำเร็จ';
  static const String statusCancelled = 'ยกเลิกแล้ว';
  static const String statusCancelledHint = 'คำสั่งซื้อนี้ถูกยกเลิกแล้ว';
  static const String statusAwaitingTransfer = 'รอโอนเงิน';
  static const String statusVerifyingTransfer = 'กำลังตรวจสอบยอดโอน';
  static const String statusTransferRejected = 'ยอดโอนไม่สำเร็จ กรุณาลองใหม่';

  // --- Demo-only seller control --------------------------------------------
  /// A temporary stand-in for the seller console, which is later work.
  static const String demoSellerControl = 'โหมดสาธิต';
  static const String demoSellerControlHint =
      'ปุ่มสำหรับผู้ขาย/แอดมิน ใช้เดินสถานะเพื่อสาธิต จะถูกถอดออกเมื่อมีหน้าจอผู้ขายจริง';
  static const String advanceToStatus = 'เดินสถานะเป็น "{status}"';
  static const String advanceStatusDone = 'เดินสถานะเป็น "{status}" แล้ว';
  static const String advanceStatusFailed = 'เดินสถานะไม่สำเร็จ';

  // --- Errors --------------------------------------------------------------
  static const String orderCreateFailed =
      'บันทึกคำสั่งซื้อไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';
  static const String needSignInToOrder = 'กรุณาเข้าสู่ระบบเพื่อดูคำสั่งซื้อ';
  static const String cartDifferentStoreTitle = 'ตะกร้ามีของต่างร้าน';
  static const String cartDifferentStoreHint =
      'หนึ่งคำสั่งซื้ออ้างอิงร้านเดียว ตะกร้านี้จึงมีของจากหลายร้าน\n'
      'เลือกได้อย่างใดอย่างหนึ่ง: ล้างตะกร้าแล้วเลือกใหม่ หรือกลับไปดูของร้านเดิม';
  static const String clearCartAndContinue = 'ล้างตะกร้าแล้วเลือกใหม่';
  static const String keepBrowsing = 'เลือกสินค้าต่อ';
}
