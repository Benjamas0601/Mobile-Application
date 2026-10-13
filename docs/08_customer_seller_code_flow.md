# Customer และ Seller: โฟลว์การทำงานของโค้ด

เอกสารนี้อธิบายเส้นทางการทำงานของลูกค้าและผู้ขาย ตั้งแต่สมัครสมาชิกจนถึงสั่งซื้อและสร้าง QR พร้อมเพย์ รวมถึงวิธีที่สองฝั่งใช้ข้อมูลและโค้ดร่วมกัน

> หมายเหตุ: ชื่อไฟล์และพาธในเอกสารอ้างอิงจากโครงสร้างโปรเจกต์ปัจจุบัน

## ภาพรวมสถาปัตยกรรม

หน้าจอไม่ได้อ่านและเขียน Firestore โดยตรงทั้งหมด แต่แยกหน้าที่เป็นชั้น ๆ:

```text
Screen (แสดงผลและรับการกระทำ)
  → Riverpod Provider / Controller (จัดการ state และเลือกบริการ)
  → Repository (อ่านหรือเขียนข้อมูลกับ Firebase)
  → Firebase Authentication / Cloud Firestore

Firestore data
  → Repository แปลงเป็น Model
  → Provider ส่งข้อมูลให้ Screen
```

- **Screen** อยู่ใต้ `lib/features/` รับ input และแสดงสถานะ loading/error/data
- **Provider/Controller** อยู่ใต้ `lib/providers/` เป็นจุดเชื่อมระหว่างหน้าจอกับ repository และเก็บ state ที่ต้องใช้ข้ามหน้า
- **Repository** อยู่ใต้ `lib/repositories/` รวมการติดต่อ Firebase
- **Model/Draft** อยู่ใต้ `lib/models/` กำหนดรูปข้อมูลที่อ่านจากฐานข้อมูล หรือค่าชั่วคราวจากฟอร์ม
- **Router** ใน `lib/core/routes/app_router.dart` จับคู่ URL กับหน้าจอ และควบคุม redirect ตามสถานะล็อกอินและบทบาท
- **Firestore Rules** เป็นด่านตรวจสิทธิ์ฝั่งฐานข้อมูล ไม่ควรถือว่าการซ่อนปุ่มหรือการตรวจ role ใน UI เป็นมาตรการรักษาความปลอดภัยเพียงอย่างเดียว

## ข้อมูลหลักที่สองฝั่งใช้ร่วมกัน

| ข้อมูล | ที่เก็บ | ใช้ทำอะไร |
|---|---|---|
| ผู้ใช้ | `users/{uid}` | ชื่อ อีเมล เบอร์โทร และ roles เช่น `customer`, `seller` |
| ร้านค้า | `stores/{storeId}` | เจ้าของร้าน ชื่อร้าน ข้อมูลหน้าร้าน และ `promptPayId` |
| สินค้า | `products/{productId}` | ข้อมูลสินค้าและ `storeId` ที่บอกว่าสินค้าเป็นของร้านใด |
| คำสั่งซื้อ | `orders/{orderId}` | ผู้ซื้อ `buyerUid`, ร้าน `storeId`, รายการสินค้า ยอด สถานะ และวิธีชำระ |
| การชำระเงิน | `payments/{paymentId}` | ข้อมูลการส่งการชำระที่เชื่อมกับ `orderId` |

`uid` ระบุตัวผู้ใช้ ส่วน `storeId` ระบุร้าน และ `orderId` ระบุคำสั่งซื้อ การใช้ ID เหล่านี้ทำให้โค้ดคนละหน้าสามารถหาข้อมูลชุดเดียวกันได้โดยไม่ต้องส่งข้อมูลทั้งหมดผ่าน URL

## โฟลว์สมัครสมาชิก

### เข้าหน้าสมัคร

1. ผู้ใช้เปิด route `/register` ซึ่งลงทะเบียนไว้ใน `lib/core/routes/app_router.dart`
2. Router สร้าง `RegisterScreen` จาก `lib/features/auth/screens/register_screen.dart`
3. หน้าจอรับข้อมูลส่วนตัว และให้เลือกสมัครเป็นลูกค้าหรือผู้ขาย
4. เมื่อตรวจสอบฟอร์มผ่าน หน้าจอเรียก `authRepositoryProvider` และส่งข้อมูลให้ `AuthRepository.register(...)`

### สิ่งที่ `AuthRepository.register` ทำ

โค้ดอยู่ใน `lib/repositories/auth_repository.dart` และทำงานตามลำดับ:

1. ตรวจ input และอนุญาตเฉพาะการสมัครเป็น `customer` หรือ `seller`
2. ใช้ Firebase Authentication สร้างบัญชีด้วยอีเมลและรหัสผ่าน จึงได้ `uid`
3. บันทึกโปรไฟล์ลง `users/{uid}` โดยตั้ง role พื้นฐานเป็น `customer` และเพิ่ม `seller` เมื่อสมัครแบบผู้ขาย
4. ถ้าเป็นผู้ขาย สร้างเอกสารใหม่ใน `stores/{storeId}` พร้อม `ownerUid` ที่ชี้กลับไปยัง `uid`
5. คืน `UserModel` ให้หน้าจอ

การสมัครเป็นผู้ขายจึงสร้างทั้งบัญชีผู้ใช้และร้านเริ่มต้น แต่ **ยังไม่ได้บันทึก PromptPay ID** ในขั้นตอนสมัคร

หากการเขียนข้อมูลล้มเหลว repository พยายามลบโปรไฟล์และบัญชีที่เพิ่งสร้าง แล้วส่ง `AuthFailure` กลับไปให้หน้าจอแสดงข้อผิดพลาด

### โหลดสถานะผู้ใช้และนำทางต่อ

- `authUserProvider` ใน `lib/providers/auth_provider.dart` ฟัง auth state จาก Firebase และอ่าน `users/{uid}` ผ่าน `AuthRepository`
- หลังสมัคร `RegisterScreen` invalidate provider และอ่านโปรไฟล์ใหม่ เพราะ auth event อาจมาก่อนการเขียนโปรไฟล์เสร็จ
- จากนั้นนำทางไปหน้าที่เหมาะสม: ลูกค้าไปหน้า Home, ผู้ขายไปหน้า Seller หรือไปยัง redirect ที่แนบมากับ route
- Router ใช้สถานะ auth/profile เพื่อคุมการเข้าหน้าผู้ขายและหน้าที่ต้องล็อกอิน

## ฝั่งผู้ขาย: ตั้งค่าร้านและข้อมูลรับเงิน

### โหลดร้านของผู้ขาย

1. ผู้ขายเข้าพื้นที่ `/seller`
2. `myStoreProvider` ใน `lib/providers/seller_catalog_provider.dart` ใช้ UID ปัจจุบัน
3. `SellerCatalogRepository.watchMyStore()` ใน `lib/repositories/seller_catalog_repository.dart` ค้นหาเอกสาร `stores` ที่มี `ownerUid` ตรงกับ UID
4. ข้อมูล Firestore ถูกแปลงเป็น `StoreModel` ใน `lib/models/store_model.dart`

ในรูปแบบข้อมูลปัจจุบัน provider/repository ฝั่งผู้ขายทำงานกับร้านของผู้ขายที่ล็อกอินอยู่ (หนึ่งผู้ขายต่อหนึ่งร้านตามคอมเมนต์ในโค้ด)

### บันทึก PromptPay ID

1. จาก Seller Home ผู้ขายเปิด route `/seller/store`
2. `SellerStoreEditScreen` ใน `lib/features/seller/screens/seller_store_edit_screen.dart` แสดงฟอร์มแก้ข้อมูลร้าน รวมถึงช่อง PromptPay ID
3. เมื่อกดบันทึก หน้าจอสร้าง `StoreProfileDraft` ใน `lib/models/store_profile_draft.dart`
4. หน้าจอเรียก `saveStoreProfileProvider` ใน `lib/providers/seller_catalog_provider.dart`
5. Controller เรียก `SellerCatalogRepository.updateStoreProfile(...)`
6. Repository อัปเดตเอกสาร `stores/{store.id}` โดยเขียนฟิลด์ `promptPayId` พร้อมข้อมูลร้านที่แก้ไข
7. Provider ของร้านผู้ขายถูก invalidate เพื่อให้หน้าที่อ่านข้อมูลเห็นค่าล่าสุด

`StoreProfileDraft` เป็นเพียงข้อมูลฟอร์มชั่วคราว ไม่ได้เขียน Firestore เอง ส่วน repository เป็นผู้บันทึกจริง

## ฝั่งลูกค้า: เลือกสินค้าและสร้างออเดอร์

### ดูสินค้าและเพิ่มลงตะกร้า

1. ลูกค้าเลือกสินค้าในแคตตาล็อกสาธารณะ ซึ่งอ่านผ่าน `CatalogRepository` และ providers ใน `lib/providers/catalog_provider.dart`
2. `ProductModel` มี `storeId` ระบุร้านเจ้าของสินค้า
3. เมื่อเพิ่มสินค้า `CartNotifier` ใน `lib/providers/cart_provider.dart` เก็บ snapshot ของสินค้าไว้ในตะกร้า เช่น product ID ชื่อ ราคา จำนวน และ store ID
4. ตะกร้าปฏิเสธการเพิ่มสินค้าจากร้านที่สอง เพราะคำสั่งซื้อหนึ่งรายการมี `storeId` เดียว

ตะกร้าเก็บ state ในแอป จึงเริ่มใช้งานได้แม้ยังไม่ได้ล็อกอิน แต่การทำ checkout ต้องผ่านการยืนยันตัวตน

### Checkout และการส่งข้อมูลไปหน้าชำระเงิน

1. ลูกค้ากด checkout จาก `CartScreen` เพื่อเปิด `CheckoutScreen`
2. หากยังไม่ได้ล็อกอิน หน้าจอเสนอให้เข้าสู่ระบบหรือสมัคร โดยแนบ redirect กลับมายัง checkout
3. หลังกรอกที่อยู่และยืนยัน `CheckoutScreen` อ่าน `storeId` จากตะกร้า
4. หน้าจอเรียก `checkoutDraftProvider` เพื่อเก็บ `CheckoutDraft(storeId, shippingAddress)` ไว้ใน state ของ Riverpod
5. จากนั้นเปิด route `/checkout/payment`

ใช้ provider แทน route arguments เพราะข้อมูลที่ต้องถือข้ามขั้นตอน เช่น ที่อยู่ ไม่ควรใส่ไว้ใน URL

## การโหลดร้านและสร้าง QR ที่หน้าชำระเงิน

1. `PaymentScreen` ใน `lib/features/cart/screens/payment_screen.dart` อ่าน `CheckoutDraft` และ `authUserProvider`
2. ใช้ `draft.storeId` เรียก `storeProvider(draft.storeId)` ใน `lib/providers/catalog_provider.dart`
3. `storeProvider` เรียก `CatalogRepository.watchStore(storeId)` ใน `lib/repositories/catalog_repository.dart`
4. Repository อ่านเอกสาร `stores/{storeId}` จาก Firestore แล้วแปลงเป็น `StoreModel`
5. `PaymentScreen` ส่งข้อมูลร้าน เช่น `promptPayId`, ชื่อร้าน และข้อมูลธนาคาร เข้า `_PaymentForm`
6. `_PaymentForm` คำนวณยอดและส่งวิธีชำระ, PromptPay ID และยอดหน่วยสตางค์ให้ `_TransferInstructions`
7. เมื่อเลือกพร้อมเพย์ `buildPromptPayPayload(promptPayId, amountSatang)` ตรวจรูปแบบ ID แล้วเรียก `encodePromptPay` จาก `thai_promptpay`
8. `QrImageView` จาก `qr_flutter` รับ payload ที่ได้และวาดเป็นภาพ QR บนหน้าจอ

ดังนั้น QR ไม่ได้ถูกเก็บไว้เป็นภาพประจำร้าน: แอปเลือก PromptPay ID ตาม `storeId` ของ checkout และประกอบ payload ใหม่จาก ID กับยอดของรายการนั้น

ถ้าร้านยังไม่มี PromptPay ID ที่ถูกต้อง payload จะสร้างไม่ได้ และหน้าจอแสดงคำแนะนำให้ผู้ขายตั้งค่าข้อมูลร้าน

## ยืนยันคำสั่งซื้อและข้อมูลที่ร้านเห็น

เมื่อลูกค้ากดยืนยัน:

1. `_PaymentForm` เรียก `placeOrderProvider.notifier.place(...)` ใน `lib/providers/order_provider.dart`
2. `PlaceOrderController` ตรวจข้อมูลสำคัญ เช่น ตะกร้า, `storeId`, ที่อยู่ และหลักฐานเมื่อวิธีชำระต้องใช้
3. Controller แปลง `CartLine` เป็น snapshot ของ `OrderItem` แล้วเรียก `OrderRepository.createOrder(...)`
4. `OrderRepository` ใน `lib/repositories/order_repository.dart` เขียนเอกสาร `orders` พร้อม `buyerUid`, `storeId`, รายการสินค้า, ยอดรวม, วิธีชำระ และสถานะ
5. สำหรับวิธีที่ไม่ใช่เก็บเงินปลายทาง repository เขียนเอกสารใน `payments` ที่เชื่อมด้วย `orderId`
6. หลังบันทึกสำเร็จ Controller ล้างตะกร้า checkout draft และคูปอง แล้ว refresh รายการออเดอร์ของลูกค้า
7. ฝั่งผู้ขายใช้ `storeOrdersProvider(storeId)` เพื่ออ่านออเดอร์ที่ผูกกับร้านของตน และจัดการสถานะตามสิทธิ์ที่ระบบกำหนด

## โค้ดส่วนใดเรียกใช้ร่วมกัน

| จุดเชื่อม | ฝั่งลูกค้า | ฝั่งผู้ขาย |
|---|---|---|
| Firebase Authentication และ `authUserProvider` | ล็อกอินก่อน checkout และใช้ UID ระบุผู้ซื้อ | ใช้ UID หาเอกสารร้านที่เป็นเจ้าของ |
| `StoreModel` / เอกสาร `stores` | โหลดชื่อร้านและข้อมูลรับเงินตอน checkout | อ่านและแก้ไขข้อมูลหน้าร้าน |
| `storeId` | อยู่ในสินค้า/ตะกร้า/checkout draft และถูกเขียนลงออเดอร์ | ใช้กรองร้านและออเดอร์ของร้าน |
| Firestore `orders` | สร้างออเดอร์และดูประวัติ | อ่านออเดอร์ของร้านและดำเนินการตามสถานะ |
| Riverpod | state ของ auth, cart, draft, checkout และ orders | state ของร้าน, สินค้า, orders และข้อมูลที่กำลังบันทึก |
| Repository | อ่านแคตตาล็อกและเขียนออเดอร์ | อ่าน/บันทึกข้อมูลร้านและจัดการสินค้า |

การเรียกใช้ร่วมกันไม่ได้หมายความว่าหน้าจอฝั่งหนึ่งเรียกหน้าจออีกฝั่งโดยตรง แต่ทั้งสองฝั่งใช้ **Model, Provider, Repository และเอกสาร Firestore ชุดเดียวกัน** โดยอ้างถึงข้อมูลด้วย ID

## แผนผังเรียกโค้ดโดยย่อ

```text
สมัครเป็นลูกค้า
RegisterScreen
  → AuthRepository.register
  → Firebase Auth + users/{uid}
  → authUserProvider
  → Home

สมัครเป็นผู้ขาย
RegisterScreen
  → AuthRepository.register
  → Firebase Auth + users/{uid} + stores/{storeId}
  → authUserProvider
  → Seller Home
  → SellerStoreEditScreen
  → StoreProfileDraft
  → SaveStoreProfileController
  → SellerCatalogRepository.updateStoreProfile
  → stores/{storeId}.promptPayId

ซื้อและชำระเงิน
Catalog Screen
  → ProductModel.storeId
  → CartNotifier (ป้องกันตะกร้าปนหลายร้าน)
  → CheckoutScreen
  → CheckoutDraft(storeId, shippingAddress)
  → PaymentScreen
  → storeProvider(storeId)
  → CatalogRepository.watchStore
  → StoreModel.promptPayId
  → buildPromptPayPayload(ID, ยอด)
  → thai_promptpay
  → QrImageView
  → PlaceOrderController
  → OrderRepository
  → orders/{orderId} + payments/{paymentId}
  → storeOrdersProvider(storeId) ฝั่งผู้ขาย
```

## ขอบเขตปัจจุบันของระบบชำระเงิน

- `thai_promptpay` สร้างข้อมูลพร้อมเพย์ และ `qr_flutter` แสดงข้อมูลนั้นเป็น QR
- QR มีข้อมูลผู้รับและยอดสำหรับให้แอปธนาคารอ่าน แต่การแสดง QR ไม่ได้ยืนยันว่าเงินเข้าบัญชีแล้ว
- โค้ดระบุชัดว่าระบบยังเป็น MVP และยังไม่ได้เชื่อม Payment Gateway จริง
- การยืนยันในแอปสร้างออเดอร์และบันทึกสถานะการชำระตาม flow ปัจจุบัน ไม่ได้ตรวจธุรกรรมจากธนาคารโดยตรง
