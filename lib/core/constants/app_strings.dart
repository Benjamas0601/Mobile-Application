/// All user-facing copy in one place.
///
/// Reason: the app is Thai-first, so when the teacher or a tester reports
/// "the wording is wrong" there is exactly one file to edit, and no widget
/// contains a hard-coded sentence. Widgets should reference `AppStrings.*`
/// rather than typing Thai text inline.
class AppStrings {
  AppStrings._();

  // --- App -----------------------------------------------------------------
  static const String appName = 'Thai OTOP';
  static const String appTagline = 'ค้นพบสินค้าและเรื่องราวจากทั่วไทย';

  // --- Generic states ------------------------------------------------------
  /// Required by the brief: never show a blank screen.
  static const String errorTitle = 'ไม่สามารถโหลดข้อมูลได้';
  static const String errorBody =
      'กรุณาลองใหม่อีกครั้ง หรือตรวจสอบการเชื่อมต่ออินเทอร์เน็ต';
  static const String retry = 'ลองอีกครั้ง';
  static const String loading = 'กำลังโหลด...';
  static const String seeAll = 'ดูทั้งหมด';
  static const String comingSoon = 'กำลังจะมาเร็ว ๆ นี้';
  static const String save = 'บันทึก';
  static const String cancel = 'ยกเลิก';
  static const String confirm = 'ยืนยัน';
  static const String delete = 'ลบ';
  static const String edit = 'แก้ไข';
  static const String close = 'ปิด';
  static const String back = 'ย้อนกลับ';
  static const String search = 'ค้นหา';

  // --- Empty states --------------------------------------------------------
  static const String emptyProducts = 'ยังไม่พบสินค้าในหมวดนี้';
  static const String emptyProductsHint =
      'ลองเปลี่ยนหมวดหมู่ หรือค้นหาด้วยคำอื่น';
  static const String emptyCart = 'ตะกร้ายังว่างอยู่';
  static const String emptyCartHint = 'ลองเลือกสินค้าจากร้าน OTOP ที่คุณสนใจ';
  static const String emptyOrders = 'ยังไม่มีคำสั่งซื้อ';
  static const String emptyOrdersHint = 'เมื่อคุณสั่งซื้อ รายการจะปรากฏที่นี่';
  static const String emptyChat = 'ยังไม่มีการสนทนา';
  static const String emptyChatHint = 'ถามร้านค้าได้โดยตรงจากหน้าสินค้า';
  static const String emptySearch = 'ไม่พบผลลัพธ์';
  static const String emptySearchHint =
      'ตรวจสอบคำค้น หรือลองค้นหาด้วยชื่อจังหวัดแทน';

  // --- Navigation (customer) ----------------------------------------------
  static const String navHome = 'หน้าแรก';
  static const String navExplore = 'สำรวจ';
  static const String navOrders = 'คำสั่งซื้อ';
  static const String navCart = 'ตะกร้า';
  static const String navProfile = 'โปรไฟล์';

  // --- Navigation (seller) -------------------------------------------------
  static const String navSellerDashboard = 'ภาพรวม';
  static const String navSellerProducts = 'สินค้า';
  static const String navSellerStore = 'ร้าน';
  static const String navSellerOrders = 'คำสั่งซื้อ';

  // --- Navigation (affiliate) ---------------------------------------------
  static const String navAffiliateDashboard = 'ภาพรวม';
  static const String navAffiliateLinks = 'ลิงก์';
  static const String navAffiliateCommission = 'ค่าคอมมิชชัน';

  // --- Auth ----------------------------------------------------------------
  static const String login = 'เข้าสู่ระบบ';
  static const String register = 'สมัครสมาชิก';
  static const String logout = 'ออกจากระบบ';
  static const String email = 'อีเมล';
  static const String password = 'รหัสผ่าน';
  static const String confirmPassword = 'ยืนยันรหัสผ่าน';
  static const String displayName = 'ชื่อที่แสดง';
  static const String phone = 'เบอร์โทรศัพท์';
  static const String forgotPassword = 'ลืมรหัสผ่าน?';
  static const String dontHaveAccount = 'ยังไม่มีบัญชี?';
  static const String alreadyHaveAccount = 'มีบัญชีอยู่แล้ว?';

  // --- Validation ----------------------------------------------------------
  static const String errRequired = 'กรุณากรอกข้อมูลให้ครบ';
  static const String errEmailFormat = 'รูปแบบอีเมลไม่ถูกต้อง';
  static const String errPasswordShort = 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
  static const String errPasswordMismatch = 'รหัสผ่านทั้งสองไม่ตรงกัน';
  static const String errPhoneFormat = 'เบอร์โทรศัพท์ไม่ถูกต้อง';
  static const String errInvalidCredentials = 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
  static const String errEmailInUse = 'อีเมลนี้ถูกใช้สมัครไว้แล้ว';
  static const String errNotAuthorised = 'คุณไม่มีสิทธิ์เข้าถึงส่วนนี้';

  // --- Product -------------------------------------------------------------
  static const String productStory = 'เรื่องราวสินค้า';
  static const String ingredients = 'วัตถุดิบ';
  static const String productionMethod = 'วิธีการผลิต';
  static const String uniqueness = 'เอกลักษณ์ของสินค้า';
  static const String community = 'ชุมชนผู้ผลิต';
  static const String province = 'จังหวัด';
  static const String region = 'ภูมิภาค';
  static const String inStock = 'มีสินค้า';
  static const String stockLeft = 'เหลือเพียง {count} ชิ้น';
  static const String outOfStock = 'สินค้าหมด';
  static const String selectVariant = 'กรุณาเลือกตัวเลือก';
  static const String sold = 'ขายแล้ว {count}';

  // --- Cart & coupon -------------------------------------------------------
  static const String cart = 'ตะกร้า';
  static const String addToCart = 'เพิ่มลงตะกร้า';
  static const String buyNow = 'ซื้อเลย';
  static const String coupon = 'คูปอง';
  static const String applyCoupon = 'ใช้คูปอง';
  static const String couponApplied = 'ใช้คูปอง {code} แล้ว';
  static const String couponInvalid = 'คูปองไม่ถูกต้องหรือหมดอายุ';
  static const String couponMinSpend = 'ยอดซื้อขั้นต่ำ {amount}';
  static const String subtotal = 'ยอดรวมสินค้า';
  static const String discount = 'ส่วนลด';
  static const String shipping = 'ค่าจัดส่ง';
  static const String total = 'ยอดชำระ';
  static const String freeShipping = 'ฟรี';

  // --- Checkout & payment --------------------------------------------------
  static const String checkout = 'สั่งซื้อ';
  static const String shippingAddress = 'ที่อยู่จัดส่ง';
  static const String paymentMethod = 'วิธีชำระเงิน';
  static const String placeOrder = 'ยืนยันการสั่งซื้อ';
  static const String paymentPending = 'รอการยืนยันการชำระเงิน';
  static const String paymentSubmitted = 'ส่งข้อมูลการชำระเงินแล้ว';
  static const String paymentVerified = 'ผู้ขายตรวจสอบการชำระเงินแล้ว';
  static const String uploadSlip = 'แนบหลักฐานการโอน';
  static const String orderNumber = 'เลขที่คำสั่งซื้อ';
  static const String mvpPaymentNotice =
      'ระบบชำระเงินในเวอร์ชันนี้เป็น MVP Flow (ยังไม่เชื่อม Payment Gateway จริง) '
      'ทุกขั้นตอนถูกบันทึกลงฐานข้อมูลจริง และออกแบบให้ต่อ Gateway ได้ภายหลัง';

  // --- Guest checkout gate -------------------------------------------------
  // The app is browse-first, so these strings only appear at the one step that
  // needs a named person.
  static const String loginToOrder = 'เข้าสู่ระบบเพื่อดำเนินการสั่งซื้อ';
  static const String loginToOrderHint =
      'คุณสามารถเลือกสินค้าและใส่ตะกร้าได้ตามปกติ '
      'กรุณาเข้าสู่ระบบหรือสมัครสมาชิกเพื่อยืนยันคำสั่งซื้อ';
  static const String backToCart = 'กลับไปเลือกสินค้า';
  static const String searchHint = 'ค้นหาสินค้า เช่น กาแฟ ผ้าไหม';
  static const String clearSearch = 'ล้างคำค้นหา';
  static const String searchResults = 'ผลการค้นหา';
  static const String addressHint =
      'บ้านเลขที่ หมู่ ซอย ถนน ตำบล อำเภอ จังหวัด และเบอร์โทร';
  static const String orderPlaced = 'สั่งซื้อสำเร็จแล้ว';
  static const String continueShopping = 'เลือกสินค้าเพิ่ม';
  static const String addedToCart = 'เพิ่มลงตะกร้าแล้ว';

  // --- Stores --------------------------------------------------------------
  static const String stores = 'ร้านค้า';
  static const String loadStoresFailed = 'โหลดร้านค้าไม่สำเร็จ';
  static const String noStores = 'ยังไม่มีร้านค้าในระบบ';
  static const String remove = 'นำออก';

  // --- Chat ----------------------------------------------------------------
  static const String chat = 'แชท';
  static const String chatWithSeller = 'ส่งข้อความถึงร้าน';
  static const String messageHint = 'พิมพ์ข้อความ...';
  static const String sendImage = 'ส่งรูป';

  // --- Platform economics (must be honest, never claim "free") ------------
  static const String platformFeeNote =
      'โครงสร้างค่าธรรมเนียมของแพลตฟอร์มปรับให้เหมาะกับผู้ประกอบการไทย '
      'โดยร้านค้าตั้งค่าได้เอง และแสดงยอดค่าคอมมิชชันอย่างโปร่งใส';
  static const String commissionRate = 'ค่าคอมมิชชัน {rate}';
}
