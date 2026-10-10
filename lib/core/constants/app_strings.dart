/// All user-facing copy in one place.
///
/// Reason: the app is Thai-first, so when the teacher or a tester reports
/// "the wording is wrong" there is exactly one file to edit, and no widget
/// contains a hard-coded sentence. Widgets should reference `AppStrings.*`
/// rather than typing Thai text inline.
/// รวมข้อความ UI ภาษาไทยไว้จุดเดียวเพื่อให้ใช้ถ้อยคำสม่ำเสมอ
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
  static const String backToHome = 'กลับหน้าแรก';

  // --- Navigation (seller) -------------------------------------------------
  static const String navSellerDashboard = 'ภาพรวม';
  static const String navSellerProducts = 'สินค้า';
  static const String navSellerStore = 'ร้าน';
  static const String navSellerOrders = 'คำสั่งซื้อ';

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
  static const String errNotAuthorisedSeller =
      'บัญชีนี้ไม่ได้เป็นผู้ขาย — กลับหน้าแรก หรือเข้าสู่ระบบใหม่';

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
  static const String goToPayment = 'ไปหน้าชำระเงิน';
  static const String payNow = 'ชำระเงิน';
  static const String orderSummary = 'สรุปคำสั่งซื้อ';
  static const String orderPlacedAt = 'สั่งซื้อเมื่อ';
  static const String orderItems = 'สินค้าในคำสั่งซื้อ';
  static const String orderDetailTitle = 'รายละเอียดคำสั่งซื้อ';
  static const String orderStatusTitle = 'สถานะการจัดส่ง';
  static const String orderIdPrefix = 'เลขที่';
  static const String orderNotFoundTitle = 'ไม่พบคำสั่งซื้อนี้';
  static const String orderNotFoundHint =
      'คำสั่งซื้ออาจถูกลบไปแล้ว หรือคุณไม่มีสิทธิ์ดูคำสั่งซื้อนี้';
  static const String orderNote = 'หมายเหตุถึงร้านค้า';
  static const String paymentStatus = 'สถานะการชำระเงิน';
  static const String trackingNumberPrefix = 'เลขพัสดุ';
  static const String shippedOnPrefix = 'จัดส่งเมื่อ';

  // --- Demo-only seller control --------------------------------------------
  // Stands in for the seller console until that exists. The strings say so,
  // because a graded demo should not let a control look like a real feature.
  static const String demoSellerControl = 'โหมดสาธิต (ผู้ขาย)';
  static const String demoSellerControlHint =
      'ปุ่มสำหรับสาธิตการเดินสถานะคำสั่งซื้อ '
      'จะถูกถอดออกเมื่อมีหน้าจอผู้ขายจริง';
  static const String advanceToStatus = 'เปลี่ยนเป็น "{status}"';
  static const String advanceStatusDone = 'เปลี่ยนสถานะเป็น "{status}" แล้ว';
  static const String advanceStatusFailed = 'เปลี่ยนสถานะไม่สำเร็จ';
  static const String backToOrders = 'กลับไปรายการคำสั่งซื้อ';
  static const String orderCreateFailed =
      'บันทึกคำสั่งซื้อไม่สำเร็จ กรุณาลองใหม่';
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

  // --- Cart store guard -----------------------------------------------------
  // One order references one store (firestore.rules resolves the seller from
  // `order.storeId`), so a cart holding two stores cannot become one order.
  // These strings explain that instead of failing at the payment step.
  // --- Payment screen reached without a draft -------------------------------
  // A deep link to `/checkout/payment`, or arriving after the cart was already
  // turned into an order. Shows a way forward instead of a blank form.
  static const String noDraftTitle = 'ยังไม่มีข้อมูลให้ชำระเงิน';
  static const String noDraftHint =
      'กรุณาเลือกสินค้าและกดสั่งซื้อก่อน หน้านี้จะแสดงเมื่อคุณเข้ามาโดยไม่ได้มาจากขั้นตอนสั่งซื้อ';

  static const String cartDifferentStoreTitle = 'ตะกร้ามีของต่างร้าน';
  static const String cartDifferentStoreHint =
      'หนึ่งคำสั่งซื้ออ้างอิงร้านเดียว ตะกร้านี้จึงมีของจากหลายร้าน\n'
      'เลือกได้อย่างใดอย่างหนึ่ง: ล้างตะกร้าแล้วเลือกใหม่ '
      'หรือกลับไปดูของร้านเดิม';
  static const String clearCartAndRetry = 'ล้างตะกร้าแล้วเลือกใหม่';
  static const String keepBrowsing = 'เลือกสินค้าต่อ';
  static const String cartAtStockLimit = 'มีในสต็อกเท่านี้แล้ว';
  static const String cartCleared = 'ล้างตะกร้าแล้ว';
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
  static const String chatNoConversations = 'ยังไม่มีข้อความ';
  static const String chatNoConversationsHint =
      'กด "ส่งข้อความถึงร้าน" ในหน้าสินค้าเพื่อเริ่มคุยกับร้าน';
  static const String chatEmptyRoom = 'ยังไม่มีข้อความในห้องนี้';
  static const String chatEmptyRoomHint =
      'พิมพ์ข้อความด้านล่างเพื่อคุยกับร้าน';
  static const String chatSend = 'ส่ง';
  static const String chatSendFailed = 'ส่งข้อความไม่สำเร็จ';
  static const String chatOpenFailed = 'เปิดแชทไม่สำเร็จ กรุณาลองใหม่';
  static const String messageHint = 'พิมพ์ข้อความ...';
  static const String sendImage = 'ส่งรูป';

  // --- Platform economics (must be honest, never claim "free") ------------
  static const String platformFeeNote =
      'โครงสร้างค่าธรรมเนียมของแพลตฟอร์มปรับให้เหมาะกับผู้ประกอบการไทย '
      'โดยร้านค้าตั้งค่าได้เอง และแสดงยอดค่าคอมมิชชันอย่างโปร่งใส';
  static const String commissionRate = 'ค่าคอมมิชชัน {rate}';

  // --- Seller: order inbox --------------------------------------------------
  // The real seller console for orders, replacing the demo advance control on
  // the buyer's order detail screen.
  static const String sellerOrders = 'คำสั่งซื้อของร้าน';
  static const String sellerNoOrders = 'ยังไม่มีคำสั่งซื้อเข้าร้าน';
  static const String sellerNoOrdersHint =
      'เมื่อมีลูกค้าสั่งซื้อ รายการจะปรากฏที่นี่ทันที';
  static const String sellerOrderNeedsAction = 'ต้องดำเนินการ';
  static const String sellerOrderAwaitingPayment = 'รอผู้ซื้อชำระเงิน';
  static const String sellerOrderItems = '{count} ชิ้น';
  static const String sellerOrderAdvance = 'เดินสถานะ';
  static const String sellerOrderCancelledNote =
      'ออเดอร์นี้ถูกยกเลิกแล้ว ประวัติยังเก็บไว้ตรวจย้อนหลัง';
  static const String sellerOrderFilterAll = 'ทั้งหมด';
  static const String sellerShipTrackingTitle = 'ใส่เลขพัสดุ';
  static const String sellerShipTrackingLabel = 'เลขพัสดุ (ถ้ามี)';
  static const String sellerShipTrackingHint =
      'ถ้าส่งเองหรือใช้รถส่งของ ไม่ต้องกรอกก็ได้';
  static const String sellerShipConfirm = 'ยืนยันการจัดส่ง';
  static const String sellerShipCancel = 'ยกเลิก';

  // --- Seller: hub & store profile -----------------------------------------
  static const String sellerProductsHint =
      'เพิ่ม แก้ไข และลบสินค้า รวมตัวเลือกสี/ขนาดและสต็อก';
  static const String sellerOrdersHint = 'ดูออเดอร์ที่เข้าร้านและเดินสถานะ';
  static const String sellerStoreProfileHint =
      'ชื่อร้าน ที่ตั้ง เรื่องราว และรูปปก';
  static const String sellerStoreProfileTitle = 'ข้อมูลร้าน';
  static const String sellerStoreNameLabel = 'ชื่อร้าน';
  static const String sellerStoreDescriptionLabel = 'เกี่ยวกับร้าน';
  static const String sellerStoreProvinceLabel = 'จังหวัด';
  static const String sellerStoreRegionLabel = 'ภูมิภาค';
  static const String sellerStoreCommunityLabel = 'ชุมชนผู้ผลิต';
  static const String sellerStoreCoverLabel = 'รูปปกร้าน';
  static const String sellerStoreLogoLabel = 'โลโก้ร้าน';
  static const String sellerStoreSaved = 'บันทึกข้อมูลร้านแล้ว';
  static const String sellerStoreSaveFailed =
      'บันทึกข้อมูลร้านไม่สำเร็จ กรุณาลองใหม่';
  static const String sellerStoreNameRequired = 'กรุณากรอกชื่อร้าน';
  static const String sellerStoreNotEditable = 'แก้ไขข้อมูลร้านนี้ไม่ได้';

  // --- Seller: product management -----------------------------------------
  // The seller console's first screen: manage the catalogue of the seller's
  // own store(s). Drafts are listed here even though customers never see them.
  static const String sellerProducts = 'จัดการสินค้า';
  static const String sellerAddProduct = 'เพิ่มสินค้า';
  static const String sellerEditProduct = 'แก้ไขสินค้า';
  static const String sellerNoStoreTitle = 'ยังไม่มีร้านค้า';
  static const String sellerNoStoreHint =
      'ต้องมีร้านค้าก่อนจึงจะเพิ่มสินค้าได้ กรุณาติดต่อผู้ดูแลระบบ';
  static const String sellerNoProducts = 'ยังไม่มีสินค้า';
  static const String sellerNoProductsHint =
      'กดปุ่ม "เพิ่มสินค้า" เพื่อเริ่มต้นสินค้าชิ้นแรก';
  static const String sellerPickStore = 'เลือกร้านค้า';
  static const String deleteProductConfirm = 'ลบสินค้านี้?';
  static const String deleteProductHint =
      'สินค้าและตัวเลือกทั้งหมดจะถูกลบ ประวัติคำสั่งซื้อเก่าจะยังอยู่';
  static const String productSaved = 'บันทึกสินค้าแล้ว';
  static const String productDeleted = 'ลบสินค้าแล้ว';
  static const String saveProductFailed = 'บันทึกสินค้าไม่สำเร็จ กรุณาลองใหม่';
  static const String deleteProductFailed = 'ลบสินค้าไม่สำเร็จ กรุณาลองใหม่';

  // --- Seller: product form ------------------------------------------------
  static const String productNameLabel = 'ชื่อสินค้า';
  static const String productNameHint = 'เช่น ผ้าไหมแดงลายไทย';
  static const String productDescriptionLabel = 'รายละเอียดสินค้า';
  static const String productPriceLabel = 'ราคา (บาท)';
  static const String productCategoryLabel = 'หมวดหมู่';
  static const String productStatusLabel = 'สถานะการขาย';
  static const String productImages = 'รูปสินค้า';
  static const String addImageByUrl = 'เพิ่มลิงก์รูป';
  static const String uploadFromDevice = 'อัปโหลดจากเครื่อง';
  static const String imageUrlHint = 'https://...';
  static const String addImage = 'เพิ่มรูป';
  static const String variantsSection = 'ตัวเลือกสินค้า (สี/ขนาด)';
  static const String variantsSectionHint =
      'ผู้ซื้อเลือกจากตัวเลือกเหล่านี้ สต็อกทั้งหมดคือผลรวมของทุกตัวเลือก';
  static const String addVariant = 'เพิ่มตัวเลือก';
  static const String variantNameHint = 'ชื่อตัวเลือก';
  static const String variantColorHint = 'สี';
  static const String variantSizeHint = 'ขนาด';
  static const String variantPriceDeltaHint = 'ราคาเพิ่ม (บาท)';
  static const String variantStockHint = 'สต็อก';
  static const String removeVariant = 'ลบตัวเลือก';
  static const String stockTotalLabel = 'สต็อกทั้งหมด';
  static const String errCategoryRequired = 'กรุณาเลือกหมวดหมู่';
  static const String errPriceInvalid = 'กรุณากรอกราคาเป็นตัวเลข';
  static const String errImageUrl = 'กรุณากรอกลิงก์รูปให้ถูกต้อง';
  static const String productDescriptionHint =
      'เล่าเรื่องสินค้า รายละเอียดวัสดุ วิธีใช้';
  static const String productImagesEmptyHint =
      'ยังไม่มีรูป — เพิ่มลิงก์หรืออัปโหลดจากเครื่อง';
  static const String imageFallbackHint =
      'ตอนนี้ใช้ลิงก์รูปจากอินเทอร์เน็ตได้ก่อน';
  static const String uploadingImage = 'กำลังอัปโหลดรูป...';
  static const String uploadFailed = 'อัปโหลดรูปไม่สำเร็จ';
  static const String variantNameExample = 'เช่น สีแดง / กล่อง 1 เดือน';
}
