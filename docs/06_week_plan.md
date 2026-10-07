# แผนและสถานะรายสัปดาห์ (Process Tracking)

> เกณฑ์ให้คะแนน **8 คะแนนจากการติดตาม process รายสัปดาห์** จึงต้องมี
> บันทึกว่า "สัปดาห์นี้ทำอะไร / ผลเป็นอย่างไร / สัปดาห์หน้าจะทำอะไร" ทุกสัปดาห์
> ไม่ใช่เพิ่มตอนจะส่งงาน

---

## สรุปภาพรวม

| สัปดาห์ | ส่ง | สถานะ |
|---|---|---|
| Week 2 | 30 ก.ย. 2569 | ✅ **เสร็จ** |
| Week 3 | 7 ต.ค. 2569 | 🔄 **กำลังทำ** (Auth, catalog/cart, checkout/orders และ Seller Product CRUD เสร็จ; เหลือเก็บ error states, ย้าย Rules tests เข้า repo และ E2E บางส่วน) |
| Week 4 | 14 ต.ค. 2569 | ⏳ |
| Week 5 | 21 ต.ค. 2569 | ⏳ |
| Week 6 | 4 พ.ย. 2569 | ⏳ |

---

## ✅ Week 2 (เสร็จ 27 ก.ย. 2569)

### สิ่งที่ทำ

| # | งาน | หลักฐาน | สถานะ |
|---|---|---|---|
| 1 | Problem / Target User / Value Prop | `docs/01_product_problem.md` | ✅ |
| 2 | โฟลว์หลัก 3 บทบาท + error/empty state | `docs/02_user_flows.md` | ✅ |
| 3 | Wireframe 6 หน้าจอ | `docs/03_wireframes.md` | ✅ (เกิน 5 ที่กำหนด) |
| 4 | ธีม / visual identity / 3D direction | `docs/04_design_direction.md` | ✅ |
| 5 | โครงสร้างโฟลเดอร์ + architecture | `docs/05_architecture.md` | ✅ |
| 6 | สร้าง Flutter project (android/ios/web) | `flutter create` | ✅ |
| 7 | Design tokens ครบ (color/type/spacing/theme) | `lib/core/theme/` | ✅ |
| 8 | ข้อความไทยทั้งหมด + enums + AsyncValue | `lib/core/constants/` | ✅ |
| 9 | 3D Hero (isometric CustomPainter) | `lib/features/auth/widgets/hero_3d.dart` | ✅ |
| 10 | หน้า Login ตาม wireframe | `lib/features/auth/screens/login_screen.dart` | ✅ |
| 11 | Firebase bootstrap + error gate | `lib/core/config/`, `lib/widgets/bootstrap_gate.dart` | ✅ |
| 12 | ตั้ง Git + commit | 2 commits | ✅ |
| 13 | ตรวจสอบว่ารันได้จริง | `flutter analyze` 0 issue, `flutter build web` สำเร็จ | ✅ |

### สิ่งที่ยังไม่เสร็จ (ตั้งใจ ไม่ใช่ตกหล่น)

- **ยังไม่ได้เปิด Firebase Authentication ใน Console** — ไฟล์ config สร้างแล้ว
  (`android/app/google-services.json`, `lib/core/config/firebase_options.dart`) แต่ยังไม่ได้
  enable provider ฝั่ง Console และยังไม่ได้ทดสอบจริงบนอุปกรณ์ → เป็นงานแรกของ Week 3
- **ยังไม่มี test** — เขียนใน Week 5 ตามที่กำหนด (≥ 10 เคส)
- **ยังไม่ได้ bundle ฟอนต์ Noto Sans Thai** — ดาวน์โหลดจากเน็ตถูกบล็อกในเครื่องนี้
  จึงใช้ฟอนต์ระบบก่อน พร้อมวางจุดเปลี่ยนไว้ที่ `kAppFontFamily` แล้ว (Week 5)
- **ยังไม่ได้ติดตั้ง Android `cmdline-tools`** — ไม่กระทบการ build (พิสูจน์แล้วว่า
  `flutter build apk` สำเร็จ) แต่ `flutter doctor` จะยังเตือนเรื่อง license

### ✅ หลักฐานการรันได้จริง (เพิ่มเติม 27 ก.ย. 2569)

| คำสั่ง | ผลลัพธ์ |
|---|---|
| `flutter analyze` | `No issues found!` (1.8 วิ) |
| `flutter build web --no-wasm-dry-run` | สำเร็จ |
| `flutter build apk --debug` | สำเร็จ 78.7 วิ → `build/app/outputs/flutter-apk/app-debug.apk` (157.27 MB) |

### ⚠️ ความเสี่ยงที่พบ และการจัดการ

| ความเสี่ยง | ผลกระทบ | การจัดการ |
|---|---|---|
| Firebase Auth ยังไม่ได้ enable ใน Console | บล็อก Auth flow ใน Week 3 | ต้อง enable Email/Password ผ่าน browser |
| เครื่องตั้ง Windows เป็นภาษาไทย | Gradle ใช้ `BuddhistCalendar` → ปี 2569 เกินช่วง MS-DOS → `mergeDebugJavaResource` พัง | บังคับ `-Duser.language=en -Duser.country=US` ใน `android/gradle.properties` (แก้แล้ว) |
| ไม่มี Android device เชื่อม | ทดสอบบนเครื่องจริงไม่ได้ | ใช้ emulator หรือ Chrome ระหว่างพัฒนา |
| เครื่อง block การดาวน์โหลดจาก GitHub | ติดตั้งฟอนต์/asset อัตโนมัติไม่ได้ | ใช้ฟอนต์ระบบ, เตรียมสคริปต์ seed ข้อมูลแทน |
| เหลือเวลาน้อย (3 วันถึงส่ง Week 2) | — | ตัด scope: ไม่มี Multi-vendor cart, ไม่มี 3D map, ไม่มี admin dashboard ซับซ้อน |


### สัปดาห์หน้า (Week 3) จะทำ

1. `flutterfire configure` → ได้ `firebase_options.dart` จริง
2. เขียน Security Rules ตามตาราง role + ทดสอบใน Rules Playground
3. Models ทั้งหมด (`fromFirestore` / `toFirestore`)
4. Services (auth / firestore / storage)
5. Repositories (auth / product / store)
6. **Auth เสร็จ**: สมัคร / ล็อกอิน / ออก / แก้โปรไฟล์ + redirect ตาม role
7. **Product CRUD**: ผู้ขายเพิ่ม/แก้/ลบ + variant + สต็อก + อัปโหลดหลายรูป
8. Error handling ครบ 4 สถานะทุกหน้า

---

## 🔄 Week 3 (เริ่ม 28 ก.ย. 2569) — Cloud Database + Authentication

### เปิดใช้งาน Cloud Database (เสร็จ 28 ก.ย. 2569)

| # | งาน | ผล | สถานะ |
|---|---|---|---|
| 1 | เปิด Google Cloud API ที่จำเป็น | `firestore.googleapis.com`, `identitytoolkit.googleapis.com`, `firebasestorage.googleapis.com` | ✅ |
| 2 | สร้าง Firestore database | `projects/thaiotop-587f1/databases/(default)` edition `STANDARD` | ✅ |
| 3 | เลือก region | **`asia-southeast1`** (สิงคโปร์) — เลือกครั้งเดียวเปลี่ยนไม่ได้ | ✅ |
| 4 | เปิด delete protection | `DELETE_PROTECTION_ENABLED` กันลบฐานข้อมูกพลาด | ✅ |
| 5 | เขียน Firestore Security Rules | `firestore.rules` — ครบทุก collection ตาม role table | ✅ |
| 6 | คอมไพล์ + deploy rules | `rules file compiled successfully` | ✅ |
| 7 | เขียน composite indexes | `firestore.indexes.json` — 10 index ตาม query ที่ออกแบบไว้ | ✅ |
| 8 | deploy indexes | `deployed indexes ... successfully for (default) database` | ✅ |
| 9 | ยืนยัน rules บนเซิร์ฟเวอร์ | เทียบกับไฟล์ในเครื่อง: **14,933 bytes = 14,933 bytes ตรงกัน** | ✅ |
| 10 | เขียน Storage Rules | `storage.rules` — อัปโหลดรูปเฉพาะร้านตัวเอง, จำกัด 5 MB, ชนิด image | ✅ |
| 11 | ผูกไฟล์ทั้งหมดใน `firebase.json` | เดิมมีแค่ส่วน `flutter` → เพิ่ม `firestore` + `storage` | ✅ |
| 12 | เพิ่ม enum ที่ยังขาด | `PaymentMethod`, `MessageType`, `NotificationType` ใน `app_enums.dart` | ✅ |

### 🌱 Seed ข้อมูลตั้งต้น (เสร็จ 28 ก.ย. 2569)

ใส่ข้อมูลผ่าน Admin API (`tool/seed_firestore.js`) เพราะเขียนจากแอปตอนนี้ยังไม่มีโค้ด และ Admin API ให้สร้างบัญชี Auth ได้พร้อมกัน

| Collection | จำนวน | หมายเหตุ |
|---|---|---|
| `users` | 5 | สร้าง Firebase Auth จริง ล็อกอินได้ทันที |
| `categories` | 10 | หมวด OTOP ตามตารางในเอกสารออกแบบ |
| `stores` | 4 | ชิงไทย / ลาดดอย / สวัสดี / ตำรับ — ครบ 3 ภาค |
| `products` | 11 | มี `story{}` ครบทั้ง 4 ช่อง |
| `product_variants` | 9 | แยกสต็อกตามสี/ขนาด |

**บัญชีสาธิต** (รหัสผ่านเดียวกันทั้งหมด: `OtopDemo123`)

| Email | Role | ใช้สาธิตอะไร |
|---|---|---|
| `seller.north@example.com` | customer + seller | ร้านชิงไทร + ลาดดอย (2 ร้าน) |
| `seller.central@example.com` | customer + seller | ร้านสวัสดี |
| `seller.south@example.com` | customer + seller | ร้านตำรับ |
| `customer@example.com` | customer | ซื้อ/ตะกร้า/รีวิว |
| `admin@example.com` | customer + admin | จัดการหมวด/คูปอง |

> ⚠️ บัญชีเหล่านี้เป็นบัญชีสาธิต **ถ้าจะเอาโปรเจกต์ไปใช้จริงต้องลบทิ้งก่อน** โดยเฉพาะ `admin`

### 🔐 ผลทดสอบ Security Rules ด้วยสิทธิ์ผู้ใช้จริง

ทดสอบโดย `signInWithPassword` แล้วยิง Firestore ด้วย `idToken` ของผู้ใช้ (ไม่ใช่ Admin) — พิสูจน์ว่า Rules ทำงานจริง ไม่ใช่แค่ compile ผ่าน

| การทดสอบ | ผล | ถูกตามที่ออกแบบ |
|---|---|---|
| ยังไม่ล็อกอิน → อ่าน `products` / `stores` / `categories` | อ่านได้ | ✅ |
| ยังไม่ล็อกอิน → อ่าน `users` / `orders` / `cart_items` | ถูกบล็อก | ✅ |
| ล็อกอิน → อ่านโปรไฟล์ตัวเอง และของผู้ขาย | อ่านได้ | ✅ |
| ลูกค้าพยายามสร้างสินค้า | **403 ถูกบล็อก** | ✅ ปิด privilege escalation |
| อ่านออเดอร์ของคนอื่น | ถูกบล็อก | ✅ |

### 🖼️ เก็บรูปด้วย Cloudinary (Firebase Storage ใช้ไม่ได้โดยไม่ผูกบัตร)

| เรื่อง | รายละเอียด |
|---|---|
| เหตุผล | Cloud Storage for Firebase บังคับให้โปรเจกต์อยู่บนแผน **Blaze** ตั้งแต่ 3 ก.พ. 2569 → ต้องผูกบัตรเครดิต ซึ่งไม่ใช่ข้อกำหนดของโปรเจกต์นี้ (อ้างอิง: `firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024`) |
| ทางเลือกที่เลือก | **Cloudinary free** — 25 credits/เดือน ไม่มีวันหมดอายุ ใช้ production ได้ตามโควตา และ**ไม่ต้องผูกบัตร** (ยืนยันจาก `cloudinary.com/documentation/billing_and_plans`) |
| ทางเลือกที่ตก | Supabase Storage free (1 GB, ไม่ต้องบัตร) — ตกเพราะต้องสมัครบัญชีใหม่ และโปรเจกต์ฟรีถูก pause ถ้าไม่มี activity 7 วัน รูปจะ 404 ตอนเดโม |
| สิ่งที่ยังใช้ Firebase | Auth + Firestore เหมือนเดิม เปลี่ยนเฉพาะส่วนเก็บรูป |
| โค้ด | `ImageStorageService` (interface) + `CloudinaryImageService` — สลับผู้ให้บริการได้โดยแก้บรรทัดเดียว |
| เก็บค่า credential | `defaultValue` ใน `cloudinary_config.dart` (ทั้งสองค่าเป็น public โดยธรรมชาติ) + override ด้วย `--dart-define` |
| รูปแบบโฟลเดอร์ | ตรงกับข้อกำหนดเดิมของ Firebase Storage → ถ้าวันไหนย้ายกลับ จึงไม่ต้องแก้ฐานข้อมูล (`storage.rules` **ถูกลบออกจากโปรเจกต์แล้ว** เพราะไม่ได้ใช้ — ดูหัวข้อ "ลบ storage.rules" ด้านล่าง) |
| รูปใน seed | ใช้ `picsum.photos` เป็นรูปตัวอย่างชั่วคราว (เปลี่ยนเป็นรูปจริงตอนผู้ขายอัปโหลด) |

> **หมายเหตุ:** ถอด block `storage` ออกจาก `firebase.json` แล้ว ตอนนี้
> `firebase deploy` แบบไม่ระบุเป้าหมายจะไม่พยายามแตะ Storage อีก (เดิมมันล้มเหลว
> เพราะยังไม่มี bucket และต้องขึ้นแผน Blaze) — แต่ยังควรใช้
> `firebase deploy --only firestore:rules` เพื่อไม่เผลอ deploy อย่างอื่น

### ✅ คืน Cloudinary + harden path (29 ก.ย. 2569)

| งาน | รายละเอียด |
|---|---|
| เปลี่ยนกลับจาก Firebase Storage | ลองต่อ `firebase_storage` แล้วค้าง เพราะโปรเจกต์อยู่บน Spark และ **default bucket ไม่เคยถูกสร้าง** — ยืนยันจากการอัปโหลดจริงบนเครื่องที่ได้ `object-not-found` ทุก path (รวม path ที่ rules อนุญาต) จึงเป็นปัญหา bucket ไม่ใช่กฎ |
| เก็บงานที่ดีจากรอบนั้น | `ImageUploadPolicy.sanitizeFolder()` — กัน `..` ใน path (ตัว Cloudinary เดิมไม่ได้กัน) |
| เก็บ guard ที่แก้ไว้ | เช็ค `_cloudName`/`_uploadPreset` ของ instance ตัวเอง แทนที่จะเช็ค config global |

### ✅ Cloudinary credential + smoke test (29 ก.ย. 2569)

| ค่า | ผลการตรวจ |
|---|---|
| `CLOUDINARY_CLOUD_NAME` | `zqaixbny` — ยืนยันด้วย `GET /v1_1/zqaixbny/image/upload` ได้ *"Upload preset must be specified"* (คนละ error กับ cloud ปลอมที่ตอบ *"Unknown API key"*) |
| `CLOUDINARY_UPLOAD_PRESET` | `otop_shop` — POST แล้วได้ *"Missing required parameter - file"* → preset มีจริงและเปิด **Unsigned** แล้ว |
| Upload จริง | สำเร็จ — `secure_url` + `public_id` ตรงรูปแบบที่ `UploadedImage` คาด |
| Delivery URL | `HTTP 200 image/jpeg` |
| Transform ตาม `buildUrl()` | `c_fill,g_auto,w_300,h_200,q_auto,f_auto` → `HTTP 200` |

**ฝัง default ลง source แล้ว (29 ก.ย. 2569)** — เดิมส่งค่าเข้ามาตอน build ด้วย
`--dart-define` ทำให้ build ที่ลืม flag ออกมาเป็นแอปที่ปุ่มอัปโหลดกดแล้วไม่ทำอะไร
และไม่มีทางบอกว่าขาดอะไร จึงย้ายไป `defaultValue` ใน
`lib/core/config/cloudinary_config.dart` (สองค่านี้ไม่ใช่ความลับ · เหตุผลเต็มอยู่ใน `docs/07_cloudinary_setup.md`)
ยัง override ด้วย `--dart-define` ได้ถ้าจะชี้ cloud อื่น
วิธีหาค่า + วิธีเช็คว่าค่าถูกเขียนไว้ที่ `docs/07_cloudinary_setup.md`

> ✅ รูป smoke test ลบออกจาก Media Library แล้ว (29 ก.ย. 2569) — delivery ตอบ `404`

### ต่อไปในสัปดาห์นี้

1. เขียน Models ทั้งหมด (`fromFirestore` / `toFirestore`)
2. Services (auth / firestore / storage)
3. Repositories (auth / product / store)
4. Auth flow: สมัคร / ล็อกอิน / ออก / redirect ตาม role
5. Product CRUD + variant + อัปโหลดหลายรูป
6. Error handling ครบ 4 สถานะทุกหน้า

---

## 🔄 Vertical Slice + Guest Flow (เสร็จ 28 ก.ย. 2569)

ต่อ Firebase จริงให้เป็น flow เดียวที่เดินได้ครบตั้งแต่เปิดแอปจนถึงกดสั่งซื้อ
โดยคิดจากคนใช้จริงว่า **คนที่ยังไม่มีบัญชีต้องดูของได้ก่อน** — ไม่บังคับ login ตอนเปิดแอป

### ขอบเขตที่ทำเสร็จ

| # | งาน | ผล | สถานะ |
|---|---|---|---|
| 1 | Models ทั้งหมด | `category/product/store/user_model.dart` + `firestore_codec.dart` ช่วย decode | ✅ |
| 2 | Repositories | `catalog_repository.dart` (public read), `auth_repository.dart` (login/register/logout) | ✅ |
| 3 | Providers (Riverpod แบบไม่ใช้ code gen) | `catalog_provider.dart`, `auth_provider.dart`, `cart_provider.dart` | ✅ |
| 4 | Home อ่านข้อมูลจริง | หมวดหมู่ 10 หมวด · สินค้า 11 ชิ้น · เลือกภาค | ✅ |
| 5 | Product Story / detail | อ่าน store + variant + story ครบ 4 ช่อง | ✅ |
| 6 | Register | เขียน `users/{uid}` profile หลังสมัครสำเร็จ | ✅ |
| 7 | Local guest cart | เพิ่ม/ลด/ลบ/ล้าง + clamp ไม่เกินสต็อก + ค่าส่ง ฿50 / ฟรีเมื่อยอดถึง ฿1,000 | ✅ |
| 8 | Checkout auth gate | 3 ปุ่ม: เข้าสู่ระบบ · สมัครสมาชิก · กลับไปเลือกสินค้า | ✅ |
| 9 | Redirect กลับมา flow เดิม | Login/Register รับ `?redirect=` แล้วกลับ `/checkout` ไม่ใช่ Home | ✅ |
| 10 | Guest search | ค้นหาใน Home debounce 350 ms คง category/region เดิม | ✅ |
| 11 | Stores directory | ดูร้านทั้ง 4 ร้าน (ตัวเอง) ได้โดยไม่ login | ✅ |
| 12 | Error/Empty/Skeleton views | `widgets/state_views.dart` — เครื่องมือพร้อม แต่ยังไม่ครบทุกหน้า | ⚠️ |
| 13 | iOS deployment target | 13.0 → 15.0 + photo/camera permission | ✅ |

### เหตุผลที่ออกแบบเป็น guest-first

โจทย์คือ marketplace ของ OTOP คนส่วนใหญ่เข้ามาเพื่อ "ดูของ" ก่อน
ถ้าบังคับ login ตอนเปิดแอป conversion จะตกทันที จึงแยกเป็น:

- **อ่านอย่างเดียว** (หมวด/ภาค/ร้าน/สินค้า/ค้นหา) → ไม่ต้องมีบัญชี
- **มีสินค้าในมือ** (ตะกร้า) → local state ไม่ต้องมีบัญชี ผู้ใช้เริ่มได้ทันที
- **ต้องมีบัญชีตอนซื้อเท่านั้น** → gate ที่ checkout ไม่ใช่ตอนเข้าแอป

ข้อดีที่ได้: ไม่ต้องเขียน `cart_items` ใน Firestore เลยตอนนี้ และ Firestore Rules
ที่เปิด public read อยู่แล้วรองรับ flow นี้พอดีโดยไม่ต้องแก้

### ✅ หลักฐานว่ารันได้จริง (28 ก.ย. 2569)

| คำสั่ง / การทดสอบ | ผลลัพธ์ |
|---|---|
| `flutter analyze --no-pub` | `No issues found!` |
| `flutter test --no-pub` | **42/42 ผ่าน** (5 ไฟล์) |
| `flutter build apk --debug` | สำเร็จ → `app-debug.apk` |
| เปิดบน Android emulator | Guest เข้า Home เห็นหมวด/ภาค/search/ปุ่ม "เข้าสู่ระบบ" |
| เพิ่มลงตะกร้า | Snackbar `เพิ่มลงตะกร้าแล้ว (1)` |
| Cart | สินค้า ฿480 + ค่าส่ง ฿50 = **฿530** |
| กดสั่งซื้อ | เจอ gate ครบ 3 ปุ่ม |
| Logcat | ไม่มี `E/flutter` / `FATAL EXCEPTION` |

### ✅ Test (ทำเกินแผน — แผนวางไว้ Week 5)

| ไฟล์ | เคส | ครอบคลุม |
|---|---|---|
| `test/app_router_test.dart` | 12 | guest เข้าได้ทุกหน้า · orders/profile ถูกกัน · redirect กลับ |
| `test/cart_test.dart` | 12 | เพิ่ม/ลด/ลบ/ล้าง · clamp สต็อก · ยอด · ค่าส่ง |
| `test/checkout_gate_test.dart` | 5 | gate ครบ 3 ปุ่ม · ไม่ redirect หนีตอนยังไม่ login |
| `test/product_filter_test.dart` | 9 | category/region/search + จำนวนผลลัพธ์ |
| `test/home_search_test.dart` | 4 | debounce 350 ms · ล้างคำค้น · หัวข้อ "ผลการค้นหา" |

### ⏳ เหลือใน Week 3

1. **Error/Empty state ครบทุกหน้า** — มี `state_views.dart` และหน้า Seller บางส่วนเรียกใช้แล้ว แต่ยังไม่ได้ไล่ตรวจทุกหน้า
2. **Seller E2E เพิ่มเติม** — Product CRUD ผ่านแล้ว (`create → edit price → delete`); ยังไม่ได้เดิน order status และ store profile บน emulator
3. **ย้าย Firestore Rules tests เข้า repo** — ตอนนี้ชุด 36 เคสยังอยู่ที่ `%TEMP%\opencode\rules-test\check.js` ไม่ได้เป็น regression test ที่รันจากโปรเจกต์ได้
4. **ทดสอบ build/run บน iOS** — ต้องใช้ macOS + Xcode
5. **ลบ Cloudinary probe 2 รูป** — unsigned preset ลบไม่ได้ ต้องลบผ่าน Media Library

> **ขอบเขต Local DB → Cloud Sync:** ยังไม่ได้ทำ ระบบตะกร้าตั้งใจเป็น in-memory เพื่อรองรับ guest และ Product/Order เขียนไป Firestore โดยตรงผ่าน repository; ยังไม่มี local database persistence หรือ sync queue ในแอป

### ⏳ ต้องทำนอกเครื่องนี้

| งาน | ทำไมทำตอนนี้ไม่ได้ |
|---|---|
| build/run จริงบน iOS | เครื่องเป็น Windows ไม่มี Xcode · ต้อง `pod install` ครั้งแรก (ยังไม่มี `ios/Podfile`) |

---

## 📌 วิธีอัปเดตสถานะทุกสัปดาห์

ทุกสัปดาห์ต้องเพิ่มหัวข้อลงล่างในไฟล์นี้ และ commit ด้วยข้อความรูปแบบ:

```
feat(week3): <สิ่งที่ทำในสัปดาห์นั้น>
fix(week3): <บั๊กที่เจอ>
docs(week3): <เอกสาร>
```

**เกณฑ์วัดว่า process แข็งแรง:** commit สม่ำเสมอทุกวัน/สัปดาห์
ไม่ใช่ 1 commit ใหญ่ตอนใกล้ส่ง · มี bug log ที่แก้จริง · มี commit ที่ย้อนกลับได้

> ⚠️ **ความผิดพลาดในการติดตาม process** — commit `ec90123` ตั้งชื่อว่า
> `feat(week4)` แต่งานในนั้นเป็นขอบเขตของ **Week 3** (Week 4 ตามแผนคือระบบแชท)
> เนื่องจาก push ไปแล้วจึงไม่แก้ประวัติซ้ำ แต่บันทึกไว้ตรงนี้เพื่อให้ตรวจสอบย้อนหลังได้
> และเป็นตัวอย่างว่าต้องอ่าน `06_week_plan.md` ก่อนตั้งชื่อ commit ทุกครั้ง

---

## 📋 บันทึกปัญหาที่พบ (Bug Log)

> เปิดใช้ตั้งแต่ Week 3 — เก็บทุก bug ที่เจอ **และ** วิธีแก้
> เป็นหลักฐานว่า "ทดสอบจริง" ไม่ใช่แค่เขียนโค้ดให้คอมไพล์ผ่าน

| # | วันที่ | ส่วนที่พบ | อาการ | สาเหตุ | วิธีแก้ | สถานะ |
|---|---|---|---|---|---|---|
| 1 | 27 ก.ย. | `app_spacing.dart` | compile error: `Undefined class 'BorderRadius'` | ไฟล์ไม่ import `material.dart` | เพิ่ม import | ✅ แก้แล้ว |
| 2 | 27 ก.ย. | `app_theme.dart` | `CupertinoPageTransitionsBuilder` ไม่รู้จัก | อยู่ใน `cupertino.dart` ไม่ใช่ `material.dart` | เพิ่ม import แบบ `show` | ✅ แก้แล้ว |
| 3 | 27 ก.ย. | `hero_3d.dart` | ชื่อพารามิเตอร์ชนกัน (`Offset d` vs `double d`) | ตั้งชื่อกระชับเกินไป | เปลี่ยนเป็น named parameters | ✅ แก้แล้ว |
| 4 | 27 ก.ย. | ทั้งโปรเจกต์ | โฟลเดอร์ `flutter_application_1` ซ้อนอยู่ในราก | ถูกสร้างพลาดระหว่าง session ทำงาน | ย้ายออกไปเก็บที่ temp (ไม่ลบทิ้ง) | ✅ แก้แล้ว |
| 5 | 27 ก.ย. | `:app:compileFlutterBuildDebug` | `BoxConstraints` not found, `layoutChild`/`hasChild`/`positionChild` ไม่มี ใน `material_ui-1.2.0` | `.dart_tool/package_config.json` ยังชี้ `C:\flutter` ซึ่งถูกย้ายไป `D:\flutter` แล้ว | ลบ `.dart_tool` + `pubspec.lock` แล้ว `flutter pub get` ใหม่ | ✅ แก้แล้ว |
| 6 | 27 ก.ย. | `:image_picker_android:compileDebugKotlin` | `package android.annotation does not exist`, `Cannot access 'java.lang.Class'` | `JAVA_HOME` ว่าง → Gradle จับ Oracle JDK 23 ซึ่งใหม่เกินสำหรับ AGP 9.0.1 | ติดตั้ง Microsoft OpenJDK 17 + pin `org.gradle.java.home` ใน `android/gradle.properties` | ✅ แก้แล้ว |
| 7 | 27 ก.ย. | `:app:mergeDebugJavaResource` | `VerifyException (no error message)` | Windows ตั้งภาษาไทย → JVM ใช้ `sun.util.BuddhistCalendar` → `YEAR=2569` เกินช่วง MS-DOS (1980–2107) ที่ AGP `MsDosDateTimeUtils` ยอมรับ | บังคับ `-Duser.language=en -Duser.country=US` ใน `org.gradle.jvmargs` | ✅ แก้แล้ว |
| 8 | 27 ก.ย. | Gradle cache | `Remove-Item -Recurse` ลบไม่หมด, `build/` เหลือ 3,020 ไฟล์ | Windows MAX_PATH (260 ตัว) | ใช้ `Remove-Item -LiteralPath "\\?\$path" -Recurse -Force` | ✅ แก้แล้ว |
| 9 | 28 ก.ย. | `app_enums.dart` | จังหวัดตัวอย่างภาคตะวันตกซ้ำกับภาคตะวันออก (`ระยอง`) | คัดลอกรายชื่อจังหวัดผิดภาค | เปลี่ยนเป็น `กาญจนบุรี ราชบุรี เพชรบุรี` | ✅ แก้แล้ว |
| 10 | 28 ก.ย. | `firestore.rules` (ร่างแรก) | helper function เรียกข้าม `match` block ไม่ได้ และใช้ `get(...)` ผิดรูป | เขียน function ไว้ใน scope ของ collection | ย้าย helper ทั้งหมดขึ้นระดับ `documents` และใช้ `get(/databases/$(database)/documents/...)` | ✅ แก้แล้ว |
| 11 | 28 ก.ย. | Firebase CLI | `firestore:databases:create` บอก `missing required argument 'database'` | ต้องระบุ database id และค่า `(default)` ถูก cmd.exe กินวงเล็บ | เรียก Firestore Admin REST API โดยส่ง `?databaseId=(default)` จาก Node | ✅ แก้แล้ว |
| 12 | 28 ก.ย. | Identity Toolkit | เปิด Email/Password ผ่าน API ไม่ได้ | `CONFIGURATION_NOT_FOUND` — config resource ต้องให้ Console เป็นผู้ initialize | ผู้ใช้เปิดเองใน Console แล้วตรวจยืนยัน `email enabled=true` | ✅ แก้แล้ว |
| 13 | 28 ก.ย. | Cloudinary SDK | `depend_on_referenced_packages` — import `cross_file` แต่ไม่ได้ประกาศใน pubspec | `image_picker` มีแต่ re-export ตัว package ให้เรียกใช้โดยตรง | เพิ่ม `cross_file` ใน `dependencies` | ✅ แก้แล้ว |
| 14 | 28 ก.ย. | `tool/seed_firestore.js` | `Document name ".../documents/users/xxx" lacks "projects" at index 0` | ใส่ document name เป็น URL เต็ม | เปลี่ยนเป็น relative path `projects/{p}/databases/(default)/documents/...` | ✅ แก้แล้ว |
| 15 | 28 ก.ย. | `tool/seed_firestore.js` | `setPassword failed (404)` | Identity Toolkit v1 ไม่มีเมธอดนี้ | เปลี่ยนเป็น `accounts:update` และให้ล้มเหลวได้โดยไม่ทำให้ seed พัง | ✅ แก้แล้ว |
| 16 | 28 ก.ย. | สคริปต์ทดสอบ Rules | `products` ตอบ `INVALID_ARGUMENT` ทั้งที่ Rules อนุญาต | ต่อ `?pageSize=100` ทับ query string ที่มีอยู่แล้ว → ได้ `?` สองตัว | ตรวจ `includes('?')` ก่อนต่อพารามิเตอร์ | ✅ แก้แล้ว |
| 17 | 28 ก.ย. | `catalog_repository.dart` | หมวดหมู้บน Home ว่างทั้ง 10 หมวด (แต่ Firestore มีข้อมูลจริง) | query `where('active', == true).orderBy('sortOrder')` ต้องใช้ **composite index ของ `categories`** — ใน `firestore.indexes.json` มี 10 index แต่ไม่มีของ `categories` เลย → Firestore ตอบ `FAILED_PRECONDITION` แล้ว provider fallback เป็นรายการว่าง | เปลี่ยนเป็น `orderBy('sortOrder')` แล้วกรอง `active` ฝั่ง Dart (หมวดมีแค่ ~10 รายการ อ่านทั้งหมดแล้วค่อยกรองไม่แพง) | ✅ แก้แล้ว · ยืนยันบน emulator เห็นครบ |
| 18 | 28 ก.ย. | `app_router.dart` | กด "สั่งซื้อ" แล้วถูกดันไปหน้า Login ทันที ทั้งที่ออกแบบให้เห็น gate 3 ปุ่ม | `/checkout` อยู่ในชุด `accountRequired` ซึ่ง redirect ตอน build ตาม auth stream — พอ auth ยังไม่ resolve ก็เด้งออกก่อน gate มีโอกาสแสดง | ย้าย `/checkout` ออกจาก `accountRequired` เหลือเฉพาะ orders / order-history / profile แล้วให้ gate จัดการเอง | ✅ แก้แล้ว · มี test `checkout_gate_test.dart` กันซ้ำ |
| 19 | 28 ก.ย. | `checkout_screen.dart` | `Looking up a deactivated widget's ancestor is unsafe` ตอนกดสั่งซื้อ | เรียก `ScaffoldMessenger.of(context)` **หลัง** `context.go()` — widget ถูกถอดออกจาก tree ไปแล้วจึงหา ancestor ไม่เจอ | เก็บ `ScaffoldMessengerState` ไว้ก่อน แล้วค่อย navigate | ✅ แก้แล้ว |
| 20 | 28 ก.ย. | `product_detail_screen.dart` | `ref` ไม่อยู่ใน scope ของ `_bottomBar()` / `_addToCart()` | ปุ่มอยู่ใน build method ที่ไม่ใช่ `ConsumerWidget` จึงไม่มี `WidgetRef` ให้ใช้ | ส่ง `WidgetRef` เข้าไปเป็น parameter ของทั้งสองเมธอด | ✅ แก้แล้ว |
| 21 | 28 ก.ย. | Android emulator | เปิด AVD ไม่ได้ `skin path not found` | `skin` ใน `config.ini` ชี้ path ที่ไม่มีอยู่จริง | เปลี่ยนเป็น path ที่มีจริงใน SDK | ✅ แก้แล้ว |
| 22 | 28 ก.ย. | `ios/Runner.xcodeproj` | iOS จะ build ไม่ผ่าน | `IPHONEOS_DEPLOYMENT_TARGET = 13.0` ต่ำกว่าที่ Firebase Apple SDK ต้อง (15.0) | ยกเป็น 15.0 ทั้ง 3 จุด + เพิ่ม `NSPhotoLibrary` / `NSCamera` usage description | ✅ แก้แล้ว · ยังต้อง build บน Mac เพื่อพิสูจน์ |

> หมายเหตุ bug #17 เคยถูกวินิจฉัยผิดตอนแรกว่า "seed ไม่มี field `active`"
> ตรวจซ้ำแล้วพบว่า seed **มี** `active: true` อยู่แล้ว (`tool/seed_firestore.js:381`)
> สาเหตุจริงคือ composite index ที่ยังไม่ได้สร้าง — บันทึกไว้เพื่อกันไม่ให้
> ใครเข้าใจผิดตามต่อไป

---

## 🧾 Week 3 — ชำระเงิน + สถานะออเดอร์ (28 ก.ย. 2569)

> ปิดงาน scope "เลือกวิธีชำระเงิน (mock ไม่ต่อ gateway จริง) + ติดตามสถานะออเดอร์"
> ทั้งชุด: UI → Riverpod → Repository → Firestore — สร้างข้อมูลจริงบนโปรเจกต์ และพิสูจน์ด้วย E2E

### ขอบเขตที่ทำเสร็จ

| # | งาน | ผล | สถานะ |
|---|---|---|---|
| 1 | หน้าชำระเงิน `/checkout/payment` | 3 วิธี: พร้อมเพย์ (QR) · โอนผ่านธนาคาร · COD · แสดงยอดรวมบนปุ่มยืนยัน | ✅ |
| 2 | mock ไม่ใช่เงินจริง | แจ้งเตือนชัดเจนว่ายังไม่ต่อ gateway · สลิป/QR เล็ง Cloudinary ไว้ (ยังไม่มี creds) | ✅ |
| 3 | สร้าง `orders` doc | สถานะแรก `pending_payment` · items snapshot ฝังใน doc · seller ตรวจราคาจริงต้องทำ Cloud Function | ✅ |
| 4 | ประวัติ + รายละเอียดออเดอร์ | `watchMyOrders` เรียงล่าสุด · timeline 5 สเต็ป · ยกเลิกเป็น terminal state | ✅ |
| 5 | ปุ่มเดินสถานะ (demo เฉพาะ seller/admin) | `advanceStatus` เขียนทีละ 1 สเต็ป ตาม state machine · rules ตรวจซ้ำฝั่ง server | ✅ |
| 6 | ตะกร้า = 1 ร้าน | ปฏิเสธสินค้าต่างร้าน · ล้างแล้วเพิ่มร้านใหม่ได้ · มี test กัน regression | ✅ |
| 7 | Seed ออเดอร์ demo | 6 ออเดอร์ครบทุกสถานะ + payment docs → เห็นผลทันทีในแอป | ✅ |
| 8 | E2E บน emulator กับ Firestore จริง | login → ประวัติ seeded → timeline → ซื้อจริง → ออเดอร์ใหม่โผล่ในประวัติ | ✅ |

### ✅ หลักฐาน (รอบส่ง Week 3)

| คำสั่ง / การทดสอบ | ผลลัพธ์ |
|---|---|
| `flutter analyze --no-pub` | `No issues found!` |
| `flutter test --no-pub` | **85/85 ผ่าน** (8 ไฟล์) |
| `flutter test integration_test -d emulator-5554` | **E2E ผ่าน** — login จริง + อ่านข้อมูลจริง + สร้างออเดอร์จริงบน Firestore จริง |
| `npx firebase deploy --only firestore:rules` | กฎ `orders` แยก `get`/`list` อัปโหลดเรียบร้อย |
| `node tool/seed_firestore.js thaiotop-587f1` | seed 6 ออเดอร์ 5 payment ลงโปรเจกต์จริง |
| `flutter build apk --debug` | สำเร็จ → `app-debug.apk` (ติดตั้งบนอีมูเลเตอร์) |

### ✅ Test ของสัปดาห์นี้

| ไฟล์ | เคส | ครอบคลุม |
|---|---|---|
| `test/payment_and_order_test.dart` | 21 | 3 วิธีชำระ+ยอดรวม · แจ้งไม่ต่อ gateway · COD ซ่อน QR · ไร้ draft ถูกรอ · สั่งสำเร็จล้างตะกร้า · เขียนพลาดเก็บ cart+draft+แสดงข้อความ · ตะกร้าว่าง/ที่อยู่เปล่าไม่แตะ repo · timeline/ยกเลิก · ลูกค้า vs ผู้ขาย control · advance เขียน 1 สเต็ป · ปุ่ม "กลับไปรายการคำสั่งซื้อ" · ไม่ตั้งค่า → บอกตรง ๆ / ตั้งค่าแล้ว → ไม่โชว์คำเตือน · inbox ผู้ขายอ่านด้วย storeId · เลขพัสดุถึง repository · รายการสินค้าว่าง/ที่อยู่เว้นวรรค → ไม่สร้างออเดอร์ |
| `test/order_model_test.dart` | 14 | state machine `allowedNext` · happy path 4 สเต็ป · terminal · fromFirestore + doc เก่า · timeline ย่อเมื่อยกเลิก · item snapshot ครบ |
| `test/image_storage_test.dart` | 15 | ต่อ Cloudinary จริง + override fake ได้ · config ค่า default ตั้งแล้วเป็น configured · ปิดทั้งค่า → `ImageUploadException` พร้อมบอก flag · folder path ตรง Firestore · `..` ถูกตัด · extension case-insensitive |
| `test/cart_test.dart` | 18 | + single-store: ปฏิเสธต่างร้าน · ล้างแล้วเพิ่มร้านใหม่ · outOfStock/atStockLimit · parity `getShippingFee` |
| `integration_test/login_and_purchase_flow_test.dart` | 1 | E2E: login → ประวัติ seeded → timeline → ซื้อจริง → ออเดอร์ใหม่ในประวัติ |

### ⚠️ ข้อจำกัดที่เหลือ (แก้ไข 29 ก.ย. 2569)

1. ~~**เงินยังเป็น mock** — รอ Cloudinary creds~~ → **✅ creds พร้อม ฝัง default แล้ว และอัปโหลดจริงผ่านจาก emulator** (ดูหัวข้อ Cloudinary ด้านบน) · เงินยังเป็น mock เพราะยังไม่ต่อ gateway จริง ซึ่งเป็น scope ที่โจทย์อนุญาต
2. **ผู้ขายเดินสถานะยังไม่พิสูจน์แบบ E2E** — ครอบด้วย unit/widget test แล้ว แต่ยังไม่ได้เดินบน emulator → งานถัดไป
3. **Seller Product CRUD** → **✅ เสร็จ** พร้อม E2E `create → edit price → delete` (ดูหัวข้อถัดไป)
4. **ข้อมูลขยะใน Firestore จาก E2E** — 41 เอกสาร (orders 10 · products 11 · product_variants 11 · payments 9) เกินจากที่ seed สร้าง สังเกตได้จาก id ที่ไม่ใช่ `o-demo-*` / `p-*` / `pay-*` → ลบเองหรือรัน seed ใหม่
5. ~~รูป smoke test บน Cloudinary~~ → **✅ ลบจาก Media Library แล้ว** (unsigned preset ลบไฟล์จริงไม่ได้ เพราะต้องมี API secret)

### 📋 Bug Log เพิ่ม

| # | วันที่ | ส่วนที่พบ | อาการ | สาเหตุ | วิธีแก้ | สถานะ |
|---|---|---|---|---|---|---|
| 23 | 28 ก.ย. | `order_provider.dart` `place()` | สั่งซื้อด้วยตะกร้าว่าง/ที่อยู่เปล่า → ผ่านเข้า repo ทั้งที่ไม่ควร | ไม่มี guard ตรวจ precondition ฝั่ง provider | เพิ่ม guard `lines/storeId/address ว่าง → return null` | ✅ แก้แล้ว · test จับแล้ว |
| 24 | 28 ก.ย. | `payment_screen.dart` | เขียนออเดอร์พลาด (เช่น rules ปฏิเสธ) → crash ไร้ข้อความ | `OrderWriteException` ไม่ถูก catch | `try/on OrderWriteException` → แสดง `e.message` | ✅ แก้แล้ว |
| 25 | 28 ก.ย. | Empty views | หน้าไร้ข้อมูลกดปุ่มแล้ว nothing happen | EmptyView บางจุดไม่มี `onAction` | ใส่ `onAction: () => context.go(...)` (home / orders) | ✅ แก้แล้ว |
| 26 | 28 ก.ย. | `firestore.rules` `orders.read` | list ออเดอร์ตัวเองโดน `PERMISSION_DENIED` ทั้งที่ `get` ทีละ doc ผ่าน | read ใช้ `isOrderParty` ซึ่งเรียก `get()`/`exists()` ไปเอกสารอื่น → **list query ถูกปฏิเสธทั้ง query** | แยก `allow get` (ใช้ cross-doc ได้) กับ `allow list` (อ้างเฉพาะ `resource.data.buyerUid`) | ✅ แก้แล้ว · deploy + E2E ผ่าน |
| 27 | 28 ก.ย. | `order_detail_screen.dart` | หลังสั่งซื้อ `context.go(orderDetail)` แล้วไม่มีทางกลับถึงประวัติ (ไม่มี back button) | detail เปิดเป็นหน้าเดียวใน stack → AppBar ไม่มี leading | เพิ่มปุ่มท้ายหน้า "กลับไปรายการคำสั่งซื้อ" — `canPop()` ? pop : `context.go(orders)` | ✅ แก้แล้ว · test + E2E ผ่าน |
| 28 | 29 ก.ย. | `seller_store_edit_screen.dart` `_upload` | ปุ่มเดียวใช้ทั้ง cover และ logo → รูปโลโก้หายเมื่อกดขึ้น cover และโฟลเดอร์ถูกใช้ผิด | ฟังก์ชันเดียวเดาว่าจะอัปโหลดอะไรแทนที่จะรับเป้าหมายจากผู้เรียก | ส่ง `TextEditingController` เป้าหมายเข้าไป + แยก `folderForStoreLogo` ออกจาก cover | ✅ แก้แล้ว · test จับแล้ว |
| 29 | 29 ก.ย. | `firestore.rules` `stores.update` | เจ้าของร้านแก้ฟิลด์ตัวเองแล้วถูกปฏิเสธ เพราะกฎเดิมอนุญาตทุกฟิลด์ → กลัวว่าจะเขียนทับซ้ำ | กฎเดิมก็อนุญาตการเขียน `ownerUid`/`ratingAvg`/`commissionRate` ซึ่งควรเป็นของระบบ | อนุญาตเฉพาะฟิลด์ที่คนแก้ได้ + ให้ `updatedAt` เสมอ | ✅ แก้แล้ว |
| 30 | 29 ก.ย. | `seller_catalog_repository.dart` `updateStoreProfile` | กดลบโลโก้แล้วรูปเดิมยังอยู่ | เขียน `logoUrl` เฉพาะเมื่อมีค่า → ล้างค่าแล้วเป็น no-op | เขียน `logoUrl` เสมอ (ค่าว่าง = ลบ) | ✅ แก้แล้ว |
| 31 | 29 ก.ย. | `_ShipTrackingSheet` | ปิด dialog แล้ว Riverpod รายงาน `used after being disposed` | controller ถูกสร้างใน method ของ parent แล้ว dispose ตาม route ที่ถูก pop ทิ้ง | ย้าย controller เข้า `StatefulWidget` ที่ dialog เพื่อให้ dispose พร้อมตัว dialog | ✅ แก้แล้ว · test จับแล้ว |
| 32 | 29 ก.ย. | `test/seller_hub_test.dart` | เคสชื่อ "a cancelled order offers no step" แต่ fixture เป็น `completed` → ปกปิด regression ของสอง terminal state | เขียนชื่อเคสก่อนแก้ fixture | แยกเป็นสองเคส: `cancelled` กับ `completed` | ✅ แก้แล้ว |
| 33 | 29 ก.ย. | `test/seller_hub_test.dart` store form | กด Save ไม่ได้ แม้ validation ผ่าน | Scroll view สูง 2000px ทำให้ Save button อยู่นอก viewport ของ test | เพิ่ม `surface` param ใน `_pump` → กำหนด viewport สูงพอสำหรับฟอร์ม | ✅ แก้แล้ว |
| 34 | 29 ก.ย. | Cloudinary credential | ส่งค่าผิดสองรอบ: URL ของ console และ UUID → ทั้งคู่ตอบ *"Unknown API key"* เหมือน cloud ที่ไม่มีจริง | ค่า cloud name กับค่า ID ภายใน console เป็นคนละช่อง และ flag เป็นของ Vite (`VITE_`) ไม่ใช่ Flutter | เพิ่มวิธีแยกค่าที่สับสน + วิธี verify ด้วย `GET /v1_1/<cloud>/image/upload` ใน `docs/07_cloudinary_setup.md` | ✅ แก้แล้ว · smoke test ผ่าน |

---

## 🏪 Seller Hub + Order Status + Store Profile (เสร็จ 29 ก.ย. 2569)

> ปิดงานที่เหลือจาก Week 3 — ผู้ขายดูออเดอร์ เดินสถานะ กรอกเลขพัสดุ
> และแก้โปรไฟล์ร้าน โดยไม่ต้องใช้ Firestore admin SDK

### ขอบเขตที่ทำเสร็จ

| # | งาน | ผล | สถานะ |
|---|---|---|---|
| 1 | Seller home `/seller` | ทางเข้า 3 ทาง: ออเดอร์ · สินค้า · โปรไฟล์ร้าน | ✅ |
| 2 | Order inbox `/seller/orders` | กรองตาม storeId + status · loading/error/empty ครบ | ✅ |
| 3 | Role gate | ทุก route `/seller` ต้อง login และมี role `seller`/`admin` | ✅ test ครบทุก route |
| 4 | เดินสถานะ + เลขพัสดุ | ตอนจะเปลี่ยนเป็น `shipped` ถามเลขพัสดุ (ว่างได้ · ยกเลิกได้) | ✅ |
| 5 | แสดงเลขพัสดุ | บนแถวออเดอร์ เห็นทันทีว่าส่งอะไรไป | ✅ |
| 6 | Store profile `/seller/store` | แก้ข้อมูลร้าน + อัปโหลด cover และโลโก้แยกโฟลเดอร์กัน | ✅ |
| 7 | Rules ปิดช่องอันตราย | `stores.update` ห้ามแตะ `ownerUid`/`ratingAvg`/`commissionRate`/`otopCertified` | ✅ |
| 8 | Cloudinary | creds ตรวจแล้ว · upload/transform ผ่าน · ไม่ hardcode ใน source | ✅ |

### ✅ หลักฐาน

| คำสั่ง / การทดสอบ | ผลลัพธ์ |
|---|---|
| `flutter analyze --no-pub` | `No issues found!` |
| `flutter test --no-pub` | **168/168 ผ่าน** (11 ไฟล์) — นับจากการรันจริงล่าสุด ไม่ใช่ตัวเลขที่เคยบันทึกไว้ก่อนหน้า |
| `flutter test --no-pub test\seller_hub_test.dart` | **18/18 ผ่าน** |
| `flutter test integration_test -d emulator-5554` | Seller Product CRUD ผ่าน (`create → edit price → delete`) |
| `curl` upload จริง | ได้ `secure_url` + `public_id` · delivery 200 · transform `c_fill,g_auto,w_300,h_200,q_auto,f_auto` 200 |

### ✅ Test ของสัปดาห์นี้

| ไฟล์ | ครอบคลุม |
|---|---|
| `test/seller_hub_test.dart` | Seller home 3 ทาง · role gate · order filters · เดินสถานะ · ส่งเลขพัสดุ/ว่าง/ยกเลิก · terminal state (`cancelled` + `completed`) · store form validation · upload แยก cover-logo · Cloudinary ไม่ได้ตั้งค่า |
| `test/app_router_test.dart` | redirect ทุก seller route → login เมื่อไม่มีบัญชี |

### ⚠️ ข้อจำกัดที่เหลือ

1. ~~**ผู้ขายหลายร้าน**~~ → **ตัดสินใจแล้ว: 1 ผู้ขาย = 1 ร้าน** (commit `da8845c`) ร้าน `store-langdoi` ถูกรวมเข้า `store-singthai` ใน `tool/seed_firestore.js` จึงไม่ต้องมี store picker
2. **E2E ฝั่งผู้ขาย** — Product CRUD เดินบน emulator แล้ว (`create → edit price → delete`) แต่ order status + store profile ยังไม่ได้เดิน
3. ~~**`firestore.rules` ยังไม่ deploy**~~ → **✅ deploy แล้ว** และ emulator unit test ผ่าน 14/14 (ดูหัวข้อถัดไป)
4. ~~**ข้อมูลขยะ 41 เอกสาร**~~ → **✅ ล้างแล้ว 51 เอกสาร** (47 จากรอบ E2E + 4 ที่หลุดมาทีหลัง)

---

## 🚀 Cloudinary default + เครื่องมือรัน (29 ก.ย. 2569)

> ปิดช่องที่ `git clone` มาแล้ว build ได้แต่ปุ่มอัปโหลดทำงานไม่ได้

### ขอบเขตที่ทำเสร็จ

| # | งาน | ผล | สถานะ |
|---|---|---|---|
| 1 | ฝัง default ลง `cloudinary_config.dart` | `zqaixbny` + `otop_shop` เป็น `defaultValue` — build ไม่ต้องส่ง flag | ✅ |
| 2 | แก้ guard ใน service | เดิมเช็ค `CloudinaryConfig` (global) แต่ตัดสินกับ `_cloudName` (instance) → พอมี default แล้ว instance ที่ค่าว่างหลุดไปยิง URL ไม่มีชื่อ cloud | ✅ bug จริง |
| 3 | เอา flag ซ้ำออกจาก `run.ps1` + `launch.json` | เหลือจุดค่าเดียว คือ `cloudinary_config.dart` | ✅ |
| 4 | `tool/run.ps1` | จุดเดียวสำหรับ `up / start / stop / build / install / launch / logs / status` | ✅ |
| 5 | `.vscode/launch.json` | กด F5 ได้เลย (emulator / Chrome) | ✅ |
| 6 | `README.md` | เขียนใหม่ทั้งไฟล์ (เดิมเป็น stub ของ `flutter create`) | ✅ |

### ✅ หลักฐานการเชื่อม Cloudinary จริง

build **ไม่มี flag เลยสักตัว** แล้วอัปโหลดจาก emulator:

| ขั้น | ผล |
|---|---|
| build ไม่มี `--dart-define` | สำเร็จ 33.5 วิ |
| ค่าในไฟล์ที่ส่งลงเครื่อง | พบ `zqaixbny` + `otop_shop` ใน `kernel_blob.bin` (grep ไบต์ดิบ) |
| upload จากเครื่อง | `https://res.cloudinary.com/zqaixbny/image/upload/v1790676577/smoke-test/probe/....png` |
| delivery | `HTTP 200 image/png` |
| ลบรูปทิ้ง | ✅ `404` (Media Library) |

> ไฟล์ probe ถูกลบออกจาก `integration_test/` แล้ว เพราะรันทีไรก็สร้าง asset จริงทุกครั้ง

### ⚠️ ข้อจำกัดที่เหลือ

1. ~~**`firestore.rules` ยังไม่ deploy**~~ → **✅ deploy แล้ว** (ruleset `6f6769d3-971b-4305-8e4a-3420722aad43`)
2. **เครื่องมี Android Studio 2 ตัว** (`Android Studio` กับ `Android Studio1`) — ตัวที่ยังไม่เคยเปิดไม่มี config จะเห็น 0 AVD
3. ~~**ยังไม่ได้ deploy — ต้องขออนุมัติก่อน**~~ → **✅ deploy หลังได้รับอนุมัติ** · สำรองกฎเดิมไว้ที่ `%TEMP%\opencode\deployed-before-cloud.firestore.json`

---

## ✅ ปิดงาน: deploy กฎจริง + E2E ผู้ขาย + ล้างขยะ (29 ก.ย. 2569)

### ✅ กฎชุดใหม่ deploy แล้ว

commit `fd156e7` (22:09) เพิ่ม Admin Hub + order tracking + กฎ register/role ทำให้
`firestore.rules` ยาว 506 บรรทัด แต่ตัวที่ deploy ไว้ยังเป็นชุดเดิม 438 บรรทัด
(first diff บรรทัด 112 — กฎ `users.create` ตอนสมัครสมาชิก) ทำให้ **สมัครเป็นผู้ขาย
ไม่ได้** เพราะกฎเก่าบังคับ `roles == ['customer']` แต่โค้ดเขียน
`['customer','seller']` + `phone`/`province` (`auth_repository.dart:152`)

หลัง deploy ใหม่ → ruleset `c04029c3-2009-43d1-baad-62eeefc641d6`
ตรวจแล้วว่า **บน cloud ตรงกับไฟล์ในเครื่องทุกบรรทัด**

เพิ่มเทสต์ `users.create` / `users.update` อีก 22 เคส (เดิมมีแค่ orders/stores 14 เคส
คือกฎที่เพิ่ง deploy ไปไม่เคยถูกทดสอบเลย) รวมเป็น **36/36 ผ่าน**:

| ต้องผ่าน | ต้องถูกบล็อก |
|---|---|
| สมัคร `['customer']` / `['customer','seller']` | role `admin` ตั้งเอง |
| แก้ `displayName` ของตัวเอง | `['customer','superuser']` (role ไม่รู้จัก) |
| แอดมินเพิ่ม/ลบ role ได้ | `['seller']` โดยไม่มี `customer` |
| | `phone`/`province`/`displayName` ว่าง · ฟิลด์แปลกปลอม |
| | แก้ `roles`/`createdAt`/`email` ของตัวเอง · แก้โปรไฟล์คนอื่น |
| | แอดมินแตะ `email` หรือให้ `admin` |

> ระหว่างเขียนเทสต์เจอกับดักสองชั้นที่ทำให้ "เคสที่ควรถูกบล็อก" ผ่านมั่วโดยไม่ได้ทดสอบอะไรเลย:
> กฎบังคับ `request.auth.uid == userId` กับ `email == request.auth.token.email`
> ถ้าใช้ context เดียวเขียนหลาย uid ทุกเคสจะตกที่เงื่อนไข uid ก่อน → เคสที่ควร fail จะผ่าน
> และ `createdAt == request.time` บังคับให้ใช้ `serverTimestamp()` ค่าธรรมดาไม่ผ่าน

### กฎที่ deploy แล้ว (ชุดก่อน `fd156e7`) — สำรองไว้
`projects/thaiotop-587f1/rulesets/6f6769d3-971b-4305-8e4a-3420722aad43`
(สำรองกฎเดิม: ruleset `b771054f-d002-42a7-a9a6-f88ea93e67ce`)

| match | ที่เพิ่ม/แก้ | ผลต่อ E2E |
|---|---|---|
| `orders.list` | แยก `get`/`list` — ผู้ขาย list ได้เฉพาะ query ที่มี `where('storeId','==',…)` (พิสูจน์ความเป็นเจ้าของผ่าน `sellsInStore` ที่อ่าน store doc) | Seller inbox โหลดได้จริง |
| `stores.update` | กันแก้ `ratingAvg`/`ratingCount`/`commissionRate`/`otopCertified` | ฟอร์มแก้ร้านผ่าน ส่วนฟิลด์ระบบยังถูกกัน |

### หลักฐาน

| การทดสอบ | ผล |
|---|---|
| Rules unit test บน Firestore Emulator | ตอนนั้น **47/47 ผ่าน** — orders.list 6 · stores.update 5 · orders.get 3 · users.create 11 · users.update 6 · affiliate 16 (เทสต์ affiliate ถูกยกเลิกไปพร้อมการตัดขอบเขต 6 ต.ค. 2569 — ตัวเลขหลังตัดยังไม่ได้วัด ดูหัวข้อ "ตัดขอบเขต" ท้ายเอกสาร) |
| กฎบน cloud vs ไฟล์ในเครื่อง | ตรงกันทุกบรรทัด (ruleset `c04029c3`) · สำรองชุดก่อนหน้าไว้ที่ `%TEMP%\opencode\deployed-before-cloud.firestore.json` |
| E2E Seller CRUD บน emulator | ผ่าน (`create → edit price → delete`) |
| `flutter analyze --no-pub` | `No issues found!` |
| `flutter test --no-pub` | **168/168 ผ่าน** (11 ไฟล์) |
| ข้อมูลจริงหลัง seed | ร้าน 3 (1 ผู้ขาย = 1 ร้าน) · สินค้า 11 · variant 9 · ออเดอร์ 6 · payment 5 |

> Emulator ค้างครั้งแรก **ไม่ใช่** เพราะ Java — แต่เพราะ Firebase CLI ในเครื่องยังไม่ `login`
> (ค้างรอ prompt) พอส่ง `FIREBASE_TOKEN` คู่กับ `JAVA_HOME=jdk-23` ก็รันผ่านทันที

### ข้อมูลขยะที่ล้าง

ลบไป **51 เอกสาร** รวม 2 รอบ: 47 จากรอบ E2E (orders 11 · products 13 · variants 13 · payments 10)
และอีก 4 ที่หลุดมาทีหลัง (orders 3 · payments 1 — เป็นออเดอร์ของ demo customer
ที่มีที่อยู่ว่างและจำนวน 1 ชิ้น ตั้งเวลาตรงกับตอนรันเทสต์บนเครื่อง)

เหลือแต่ seed: products 11 · variants 9 · orders 6 · payments 5

> ยืนยันแล้วว่า `flutter test` ไม่เขียนลง Firestore (นับก่อน/หลังรันเท่ากันทุก collection)
> ขยะ 4 เอกสารจึงมาจากการเปิดแอปบน emulator ไม่ใช่จาก unit test

### ~~Affiliate Dashboard~~ — ถูกตัดออกแล้ว

หัวข้อนี้เคยบรรยายการสร้าง `lib/features/affiliate/screens/affiliate_home_screen.dart`
+ route `/affiliate` + เทสต์ 22 เคส + กฎ `affiliate_*` 11 เคส ซึ่งถูก deploy ไว้แล้ว

**ถูกยกเลิกทั้งหมดเมื่อ 6 ต.ค. 2569** — ดูหัวข้อ "ตัดขอบเขต: ลบ Affiliate" ท้ายเอกสาร
(โค้ด, กฎ, เทสต์, seed และเอกสารอ้างอิงถูกลบออกจาก repo แล้ว)

### ⚠️ ที่ยังค้าง

1. **รูป probe บน Cloudinary 2 ใบ** — `smoke-test/probe/…` และ `smoke-test/escaped/…` ลบเองไม่ได้
   (unsigned preset ต้องใช้ API secret) · ลบผ่าน Media Library หรือส่ง secret มาให้ลบแทน
2. **iOS ยังไม่ได้ build** — ต้องใช้ macOS + Xcode
3. ~~**เทสต์กฎ Firestore อยู่นอกโปรเจกต์**~~ → ✅ **ย้ายเข้าอยู่ใน repo แล้ว** ที่ `tool/rules-test/`
   (รันผ่าน Firestore Emulator, `npm test`) — **64/64 ผ่าน** และเจอ/แก้ bug จริงที่ `isParticipant()`
   ดูหัวข้อ "ตัดขอบเขต: ลบ Affiliate" ด้านล่าง
4. **E2E ฝั่งผู้ขาย** — ทดสอบแค่ Product CRUD (`create → edit price → delete`)
   ยังไม่ได้เดิน order status และ store profile บน emulator

### ✅ ปิดแล้วในรอบนี้

- deploy กฎชุดใหม่ (`c04029c3`) และยืนยันว่าตรงกับไฟล์ในเครื่องทุกบรรทัด
- เพิ่มเทสต์กฎ `users.create`/`users.update` 22 เคส → รวม 36/36 ผ่าน
- รัน seed ใหม่ + ลบ `store-langdoi` ที่ค้าง (เช็คทุก collection แล้วว่าไม่มีอะไรอ้างถึง)
  → 1 ผู้ขาย = 1 ร้าน ตรงกับโค้ดแล้ว
- ลบ `storage.rules` + ถอด block `storage` ออกจาก `firebase.json`
  (`firebase deploy` แบบไม่ระบุเป้าหมายจะไม่พยายามแตะ Storage อีก)
- ลบขยะ Firestore 4 เอกสารที่หลุดมาทีหลัง (รวมเป็น 51 จากรอบ E2E)
- แก้ตัวเลขเทสต์ในเอกสาร: 139/129 → **146** (จริงคือ commit `fd156e7` เพิ่ม
  `payment_and_order_test` จาก 14 → 21 เคส)


---

## ✂️ ตัดขอบเขต: ลบ Affiliate ออกจากระบบทั้งหมด (6 ต.ค. 2569)

**การตัดสินใจ:** เอาบทบาท/ฟีเจอร์ Affiliate (พาร์ทเนอร์/ครีเอเตอร์) ออกทั้งแอป เหลือ 3 บทบาท
ที่ผู้ใช้เลือกได้เอง — `customer`, `seller`, `admin` (ยังคงกติกาเดิมที่บัญชีเดียวถือหลาย role ได้)

### สิ่งที่ถูกลบ

| รายการ | รายละเอียด |
|---|---|
| หน้าจอ + route | โฟลเดอร์ `lib/features/affiliate/` ทั้งหมด · `/affiliate` · ปุ่ม affiliate บน Home และ Seller Dashboard |
| Model | `affiliate_link_model.dart` · `affiliate_commission_model.dart` · `affiliate_provider.dart` · `affiliate_repository.dart` |
| บทบาท + ฟิลด์ | `UserRole.affiliate` · `CommissionStatus` · `UserModel.affiliatePlatform/Handle/ProfileUrl` · ฟิลด์ register |
| ฟอร์มสมัคร | ตัวเลือก "Affiliate" ใน Register + validation `_validateProfileUrl` |
| Admin Hub | แท็บ Affiliate + `adminAffiliatesProvider` + `AdminAffiliateRecord` |
| Security Rules | บล็อก `affiliate_links` / `affiliate_clicks` / `affiliate_commissions` · ตัดฟิลด์/role affiliate ออกจาก `users.create` และ `users.update` (506 → 463 บรรทัด) |
| เทสต์ | `integration_test/affiliate_dashboard_flow_test.dart` · `test/affiliate_dashboard_test.dart` (22 เคส) |
| Seed | บัญชี `affiliate@example.com` · `AFFILIATE_LINKS` · `AFFILIATE_COMMISSIONS` ใน `tool/seed_firestore.js` |
| เอกสาร | `01` persona D + VP 3.3 · `02` section 3 · `03` บล็อกแนะนำพาร์ทเนอร์ · `05` folder tree + collections + role matrix |

### ผลตรวจหลังลบ

| การทดสอบ | ผล |
|---|---|
| `flutter analyze --no-pub` | **No issues found!** |
| `flutter test --no-pub` | **173/173 ผ่าน** |
| `dart format lib test integration_test tool` | แก้ 2 ไฟล์ (format ล้วน) |
| grep `affiliate` ใน `lib/` `integration_test/` `firestore.rules` `firestore.indexes.json` `tool/` | **0 จุดทุกไฟล์** |
| `node --check tool/seed_firestore.js` | ผ่าน |
| build + install + launch บน emulator (Pixel_7) | APK ติดตั้งและเปิดได้ ไม่มี FATAL / ไม่มี `Unhandled Exception` ใน logcat |
| deploy `firestore.rules` ขึ้น cloud | ruleset **`459d82c8-d412-4ea6-9ae4-ab362e56fbca`** (แทน `c04029c3`) |
| rules บน cloud vs ไฟล์ในเครื่อง | **IDENTICAL** · 463 บรรทัด · affiliate 0 จุด |
| ข้อมูล affiliate ใน Firestore | `affiliate_links` 5 · `affiliate_commissions` 4 ถูกลบหมด · users 6 รายโดนตัดฟิลด์ · เหลือ 0 |
| **rules regression test บน Firestore Emulator** (7 ต.ค. 2569) | **`tool/rules-test/` ใน repo — 64/64 ผ่าน**<br>เจอ bug จริง: `isParticipant()` อ่าน `resource.data` ของตัว message (เป็น null ตอนสร้าง) → **ส่งข้อความแชทไม่ได้ตลอด**<br>แก้ให้ hop ไปที่ `chat_threads/{threadId}` แล้ว deploy ใหม่ → ruleset **`5ff11dd7-9388-412b-ab40-411c7cec0099`**<br>cloud vs local: **IDENTICAL** · 468 บรรทัด · affiliate 0 จุด |

> เทสต์ `test/app_router_test.dart` เหลือ assertion 1 จุดที่จงใจเช็คว่า `find.text('Affiliate')` ได้ `findsNothing`
> ข้อมูลที่ลบสำรองไว้ที่ `%TEMP%\opencode\affiliate_backup.json` (17 KB) — restore ได้ถ้าต้องการ

### ⚠️ งานที่ยังค้างจากการตัดครั้งนี้

- ~~ยังไม่มี regression test สำหรับกฎ~~ → ✅ **เสร็จ: `tool/rules-test/` ใน repo 64/64 ผ่าน**
- ~~กฎชุดแรกที่ deploy (หลังตัด) ยังเป็นของเดิม~~ → ✅ **deploy รอบ 7 ต.ค. 2569 (ruleset `5ff11dd7…`) แก้ bug แชทแล้ว** (รายละเอียดตารางด้านบน)
- กำลังใส่ comment ภาษาไทยสำคัญ ๆ ลงไฟล์ lib ที่แก้ระหว่างลบ affiliate
