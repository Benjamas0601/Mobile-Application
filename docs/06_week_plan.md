# แผนและสถานะรายสัปดาห์ (Process Tracking)

> เกณฑ์ให้คะแนน **8 คะแนนจากการติดตาม process รายสัปดาห์** จึงต้องมี
> บันทึกว่า "สัปดาห์นี้ทำอะไร / ผลเป็นอย่างไร / สัปดาห์หน้าจะทำอะไร" ทุกสัปดาห์
> ไม่ใช่เพิ่มตอนจะส่งงาน

---

## สรุปภาพรวม

| สัปดาห์ | ส่ง | สถานะ |
|---|---|---|
| Week 2 | 30 ก.ย. 2569 | ✅ **เสร็จ** |
| Week 3 | 7 ต.ค. 2569 | 🔄 **กำลังทำ** (เสร็จ 6/9 ของรายการ — เหลือ Product CRUD) |
| Week 4 | 14 ต.ค. 2569 | ⏳ |
| Week 5 | 21 ต.ค. 2569 | ⏳ |
| Week 6 | 4 พ.ย. 2569 | ⏳ |

---

## ✅ Week 2 (เสร็จ 27 ก.ย. 2569)

### สิ่งที่ทำ

| # | งาน | หลักฐาน | สถานะ |
|---|---|---|---|
| 1 | Problem / Target User / Value Prop | `docs/01_product_problem.md` | ✅ |
| 2 | โฟลว์หลัก 4 บทบาท + error/empty state | `docs/02_user_flows.md` | ✅ |
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

### 🖼️ เปลี่ยนเก็บรูปจาก Firebase Storage เป็น Cloudinary

| เรื่อง | รายละเอียด |
|---|---|
| เหตุผล | Cloud Storage for Firebase ใช้ได้เฉพาะแผน **Blaze** → ต้องผูกบัตรเครดิต ผู้ใช้ไม่ต้องการ |
| ทางเลือกที่เลือก | **Cloudinary free tier** — 25 GB / 25 GB ต่อเดือน / 25,000 transforms ไม่ต้องผูกบัตร |
| สิ่งที่ยังใช้ Firebase | Auth + Firestore เหมือนเดิม เปลี่ยนเฉพาะส่วนเก็บรูป |
| โค้ด | `ImageStorageService` (interface) + `CloudinaryImageService` — สลับผู้ให้บริการได้โดยแก้บรรทัดเดียว |
| เก็บค่า credential | ผ่าน `--dart-define` ไม่ hardcode ใน source |
| รูปแบบโฟลเดอร์ | ออกแบบตรงกับ `storage.rules` เดิม → ย้ายกลับ Firebase Storage ทีหลังได้โดยไม่ต้องแก้ฐานข้อมูล |
| รูปใน seed | ใช้ `picsum.photos` เป็นรูปตัวอย่างชั่วคราว (เปลี่ยนเป็นรูปจริงตอนผู้ขายอัปโหลด) |

### ⏳ เหลือ 1 อย่างที่ทำผ่าน API ไม่ได้

| งาน | ทำไมทำแทนไม่ได้ | สถานะ |
|---|---|---|
| **Get Started** Firebase Storage | ยังไม่มี default bucket — ต้องกด Get Started เพื่อสร้าง bucket | ⏸️ ไม่จำเป็นแล้ว เพราะเปลี่ยนไปใช้ Cloudinary |

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
| 7 | Local guest cart | เพิ่ม/ลด/ลบ/ล้าง + clamp ไม่เกินสต็อก + ค่าส่ง ฿50 / ฟรีเมื่อครบ ฿500 | ✅ |
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

1. **Product CRUD ฝั่งผู้ขาย** — เพิ่ม/แก้/ลบสินค้า + variant + สต็อก + อัปโหลดหลายรูป
   (ยังไม่เริ่ม · เป็นงานใหญ่สุดที่เหลือ · ต่อ `CloudinaryImageService` ที่เขียนเตรียมไว้แล้ว)
2. **อัปโหลดรูปจริง** — รอผู้ใช้ตั้ง `CLOUDINARY_CLOUD_NAME` + `CLOUDINARY_UPLOAD_PRESET`
   (ตอนนี้ seed ใช้ `picsum.photos` เป็นรูปตัวอย่าง)
3. **Error/Empty state ครบทุกหน้า** — มี `state_views.dart` แล้ว แต่ยังไม่ได้ไปเรียกใช้ครบ

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

