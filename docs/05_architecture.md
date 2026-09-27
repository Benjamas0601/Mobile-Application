# Architecture & โครงสร้างโค้ด — Week 2

> หลักการเดียว: **UI ไม่มี business logic**
> เพราะนักศึกษาต้องอธิบายโค้ดต่ออาจารย์ได้ โครงสร้างที่ซับซ้อนเกินจำเป็น
> จะกลายเป็นโค้ดที่อธิบายไม่ได้

---

## 1. Data Flow

```
┌──────────────────────────────────────────────┐
│  UI            lib/features/*/screens+widgets │  วาดอย่างเดียว ไม่คิดเลขธุรกิจ
└───────────────────────┬──────────────────────┘
                        │ เรียก method / อ่าน state
┌───────────────────────▼──────────────────────┐
│  State        lib/features/*/providers        │  Riverpod: เก็บ state + จัดการ
│               lib/providers/                  │  loading / error / data
└───────────────────────┬──────────────────────┘
                        │
┌───────────────────────▼──────────────────────┐
│  Repository   lib/repositories/               │  business logic ทั้งหมดอยู่ที่นี่
│                                              │  (คิดส่วนลด, ตัดสต็อก, คำนวณ commission)
└───────────────────────┬──────────────────────┘
                        │
┌───────────────────────▼──────────────────────┐
│  Service      lib/core/services/             │  ตัวห่อ SDK บาง ๆ (FirebaseAuth, Firestore, Storage)
└───────────────────────┬──────────────────────┘
                        │
┌───────────────────────▼──────────────────────┐
│  Cloud        Firestore / Storage            │  thaiotop-587f1
└──────────────────────────────────────────────┘
```

**ตัวอย่างข้อดี:** ตอนต้องเปลี่ยนจากเดโมเป็นของจริง เปลี่ยนแค่ชั้น Service
แต่ Repository (ซึ่งมีตรรกะคิดเงิน) ไม่ต้องแก้เลย → **ทดสอบ business logic ได้โดยไม่ต้องต่อ Firebase**

---

## 2. โครงสร้างโฟลเดอร์

```
lib/
├── main.dart                    # entry point: init Firebase → runApp
├── app.dart                     # MaterialApp + theme + locale + router
│
├── core/                        # ── ไม่มี business logic, ไม่มี UI ──
│   ├── config/
│   │   ├── firebase_options.dart     # (สร้างโดย FlutterFire CLI)
│   │   └── firebase_bootstrap.dart   # init + จัดการ error ตอนเริ่มแอป
│   ├── constants/
│   │   ├── app_enums.dart            # role, region, order/payment status
│   │   └── app_strings.dart          # ข้อความไทยทั้งหมด
│   ├── theme/
│   │   ├── app_colors.dart
│   │   ├── app_typography.dart
│   │   ├── app_spacing.dart
│   │   └── app_theme.dart
│   ├── services/                    # ห่อ Firebase SDK (Week 3)
│   ├── utils/                       # format เงิน/วันที่, validators (Week 3)
│   └── routes/
│       └── app_router.dart           # ทุก path เป็น constant
│
├── models/                      # fromFirestore / toFirestore  (Week 3)
│
├── repositories/                # business logic                 (Week 3+)
│
├── providers/                   # provider ระดับทั้งแอป        (Week 3)
│
├── features/
│   └── <feature>/
│       ├── screens/              # หน้าจอเต็ม
│       ├── widgets/              # widget เฉพาะของ feature นั้น
│       └── providers/            # state ของ feature นั้น
│   ├── auth/         ✅ login_screen, hero_3d
│   ├── home/         ⏳
│   ├── explore/      ⏳
│   ├── products/     ⏳
│   ├── stores/       ⏳
│   ├── cart/         ⏳
│   ├── checkout/     ⏳
│   ├── orders/       ⏳
│   ├── seller/       ⏳
│   ├── affiliate/    ⏳
│   ├── chat/         ⏳
│   └── profile/      ⏳
│
└── widgets/                     # widget ใช้ร่วมทั้งแอป
    ├── bootstrap_gate.dart      # กันหน้าขาวตอน Firebase ไม่พร้อม
    └── state_views.dart         # ⏳ loading / empty / error ตัวเดียวใช้ทั้งแอป

test/                            # ⏳ Week 5 (เป้า ≥ 10 เคส)
docs/                            # เอกสาร Week 2
scripts/                         # สคริปต์ช่วย seed ข้อมูล demo
assets/                          # images / icons / fonts
```

**กฎที่บังคับ:**
- `core/` ห้าม import จาก `features/` (core ต้องอยู่ล่างสุด)
- `screens/` ห้ามเรียก Firebase SDK ตรง ๆ ต้องผ่าน Repository
- business logic (คิดส่วนลด/commission/stock) ห้ามอยู่ใน Widget

---

## 3. State Management: ทำไมต้อง Riverpod

| เหตุผล | รายละเอียด |
|---|---|
| DI ไม่ต้องใช้ `BuildContext` | ทดสอบ repository ได้โดยไม่ต้อง pump widget |
| แยก provider ตาม feature | ลบ feature ก็ลบทิ้งได้ ไม่กระทบส่วนอื่น |
| `AsyncValue` ให้สถานะครบ | เราเขียน `AsyncValue` เองใน `app_enums.dart` เพื่อให้ทุกจุดใช้รูปแบบเดียวกัน |
| Auto-dispose | provider ที่ไม่มีใครฟังอยู่จะถูกปล่อยเอง ดีกับแอปที่หลายหน้า |

**รูปแบบที่จะใช้** (เขียนเป็น provider แบบ function ไม่ใช้ class generator เพื่อให้อ่านง่าย):

```dart
// ✅ ทำแบบนี้ — debug ง่าย, ไม่ต้องรัน code generation
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(firestore: ref.watch(firestoreProvider));
});

final productListProvider = FutureProvider.autoDispose.family<List<Product>, ProductQuery>(
  (ref, query) => ref.watch(productRepositoryProvider).list(query),
);
```

> **ไม่ใช้ Riverpod Generator (`riverpod_annotation`)** เพราะต้องรัน build_runner
> ซึ่งเป็นอีกหนึ่งจุดที่พังเงียบ ๆ และเพิ่มภาระการอธิบายโค้ด — เป็นการตัดทิศทาง
> ที่ช่วยทั้งคะแนน "โค้ดเรียบร้อย" และ "เข้าใจโค้ดรายบุคคล"

---

## 4. Firestore Schema (ร่าง — จะยืนยันใน Week 3)

```
users/{uid}                    uid, displayName, email, phone, roles[], province, createdAt
stores/{storeId}               storeId, ownerUid, name, province, region, community,
                               description, coverImageUrl, otopCertified, ratingAvg,
                               commissionRate, createdAt
categories/{categoryId}        name, slug, icon, sortOrder, active
products/{productId}           storeId, name, description, price, categoryId, province,
                               region, imageUrls[], stockTotal, status,
                               story{community, ingredients, productionMethod, uniqueness},
                               ratingAvg, ratingCount, soldCount, createdAt, updatedAt
product_variants/{variantId}   productId, name(สี/ขนาด), options{color,size}, priceDelta,
                               stock, imageUrl
cart_items/{cartItemId}        userId, productId, variantId, qty, unitPrice, addedAt
orders/{orderId}               buyerUid, storeId, items[], subtotal, discount, shipping,
                               total, couponCode, status, shippingAddress{}, createdAt
order_items/{orderItemId}      orderId, productId, variantId, nameSnapshot, unitPrice, qty
payments/{paymentId}           orderId, method, amount, status, reference, slipUrl, updatedAt
coupons/{couponId}             code, type(percentage|fixed), value, minSpend, maxDiscount,
                               storeId?, startsAt, expiresAt, usageLimit, usedCount, active
reviews/{reviewId}             productId, userId, orderId, rating, comment, images[], createdAt
chat_threads/{threadId}        participantUids[], storeId, buyerUid, lastMessage, lastAt
  └─ messages/{messageId}      threadId, senderUid, type(text|image), text, imageUrl, createdAt, readBy[]
affiliate_links/{linkId}       affiliateUid, productId, code, clicks, orders, createdAt
affiliate_clicks/{clickId}     linkId, createdAt, source
affiliate_commissions/{id}     affiliateUid, orderId, amount, rate, status, createdAt
notifications/{id}             userId, type, title, body, data, read, createdAt
```

**หลักการออกแบบ**
1. **เก็บ snapshot ลง order_items** — ถ้าราคาสินค้าเปลี่ยนทีหลัง ลูกค้าต้องยังเห็นราคาเดิม
2. **denormalize ชื่อสินค้า/ราคา** ใน order เพื่อไม่ต้อง join ตอนแสดงประวัติ
3. **สต็อกแยกที่ variant** เพราะ "ผ้าเชียม สีน้ำเงิน หมด" ≠ "ผ้าเชียม หมด"
4. **ทุก doc มี `createdAt`** เพื่อเรียงล่าสุด
5. **ไม่มี collection ซ้ำซ้อน** — ใช้ `chat_threads/messages` แทน `messages` ที่มี `threadId` ซ้ำ ๆ

---

## 5. Role Security (2 ชั้น — ต้องมีทั้งคู่)

| Role | อ่าน | เขียน |
|---|---|---|
| Customer | product / store / category (สาธารณะ) | profile ตัวเอง, cart ตัวเอง, order ตัวเอง, review ตัวเอง, chat ที่อยู่ในนั้น |
| Seller | ของสาธารณะ + **เฉพาะ store ของตัวเอง** | store ตัวเอง, product/variant ของ store ตัวเอง, **เฉพาะ order ที่มี store ตัวเอง** |
| Affiliate | ของสาธารณะ | link/comission **เฉพาะของตัวเอง** |
| Admin | ทุกอย่าง | ข้อมูลพื้นฐาน (หมวด, coupon, สถานะ commission) |

> **ชั้นที่ 1:** Firestore Security Rules — บังคับที่เซิร์ฟเวอร์ (เขียนใน Week 3)
> **ชั้นที่ 2:** UI ซ่อนปุ่มที่กดไม่ได้อยู่แล้ว (เพื่อ UX)
>
> ⚠️ ชั้นที่ 2 **ไม่ใช่** ความปลอดภัย — ถ้ามีแต่ชั้นที่ 2 ผู้ใช้เรียก Firestore ตรงได้

---

## 6. Error Handling Strategy

ทุก feature ต้องผ่าน 4 สถานะ (โจทย์สั่งชัด):

```dart
switch (asyncValue) {
  case Idle():     → ยังไม่เริ่ม (โชว์ครอนจาก model)
  case Loading():  → skeleton / shimmer
  case Data(:final value):
        value.isEmpty → EmptyView(ข้อความเฉพาะ + ปุ่มนำทางต่อ)
        else          → เนื้อหา
  case Failure(:final message): → ErrorView(ข้อความไทย + ปุ่มลองใหม่)
}
```

- `state_views.dart` เป็นตัวเดียวที่ทั้งแอปใช้ → ไม่มีหน้าขาว
- ข้อความ error ต้องเป็นภาษาไทยที่บอก **วิธีแก้** ไม่ใช่ error code
- `FirebaseBootstrap` จัดการกรณียังไม่ได้ config → แสดงขั้นตอนที่ต้องรัน ไม่ใช่ stack trace

---

## 7. สิ่งที่ตัดสินใจ และเหตุผล

| การตัดสินใจ | เหตุผล | ผลต่อคะแนน |
|---|---|---|
| Riverpod แบบไม่ใช้ code generation | ไม่ต้องรัน build_runner, อ่านง่ายกว่า | โค้ดเรียบร้อย + เข้าใจง่าย |
| `AsyncValue` เขียนเอง ไม่ใช้ `AsyncValue` ของ Riverpod | ควบคุมรูปแบบได้ 100% และไม่ต้องเรียนรู้ API เพิ่ม | ลด barrier เวลาอธิบาย |
| business logic แยกเป็น `core/utils` (format/validate) | ทดสอบเป็น unit test ได้โดยไม่ต้องมี UI | เขียน test 10 เคสได้เร็ว |
| Product Card เป็น 2D, 3D เฉพาะ Login | scroll ไม่หนัก, ตรงหลัก "3D=Attention" | UX คะแนน 4 |
| ไม่ทำ 3D Map | กินเฟรมเรตบน Android รุ่นเก่า | ตัด scope ที่ไม่ได้คะแนน |
| ไม่ใช้ `flutter_google_fonts` | ดึง font จากเน็ตตอนรัน → เสี่ยงค้างตอน demo | ความเสถียรของ UX |
