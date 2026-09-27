# แผนและสถานะรายสัปดาห์ (Process Tracking)

> เกณฑ์ให้คะแนน **8 คะแนนจากการติดตาม process รายสัปดาห์** จึงต้องมี
> บันทึกว่า "สัปดาห์นี้ทำอะไร / ผลเป็นอย่างไร / สัปดาห์หน้าจะทำอะไร" ทุกสัปดาห์
> ไม่ใช่เพิ่มตอนจะส่งงาน

---

## สรุปภาพรวม

| สัปดาห์ | ส่ง | สถานะ |
|---|---|---|
| Week 2 | 30 ก.ย. 2569 | ✅ **เสร็จ** |
| Week 3 | 7 ต.ค. 2569 | ⏳ รอเริ่ม |
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

- **Firebase ยังไม่ได้เชื่อม** — รอ `firebase login` (ต้องใช้ browser) แล้วรัน
  `flutterfire configure --project=thaiotop-587f1` → เป็นงานของ Week 3
- **ยังไม่มี test** — เขียนใน Week 5 ตามที่กำหนด (≥ 10 เคส)
- **ยังไม่ได้ bundle ฟอนต์ Noto Sans Thai** — ดาวน์โหลดจากเน็ตถูกบล็อกในเครื่องนี้
  จึงใช้ฟอนต์ระบบก่อน พร้อมวางจุดเปลี่ยนไว้ที่ `kAppFontFamily` แล้ว (Week 5)

### ⚠️ ความเสี่ยงที่พบ และการจัดการ

| ความเสี่ยง | ผลกระทบ | การจัดการ |
|---|---|---|
| Firebase ยังไม่ได้ login | บล็อก Week 3 ทั้งสัปดาห์ | ต้อง login **ภายใน 28 ก.ย.** ไม่งั้นเสี่ยง |
| Android toolchain ไม่ครบ (ไม่มี `cmdline-tools`, ยังไม่ accept license) | สร้าง APK ไม่ได้ → บล็อก Week 6 | ตั้งค่าใน Week 3 (ต้องใช้เวลาราว 1 ชม.) |
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

## 📌 วิธีอัปเดตสถานะทุกสัปดาห์

ทุกสัปดาห์ต้องเพิ่มหัวข้อลงล่างในไฟล์นี้ และ commit ด้วยข้อความรูปแบบ:

```
week3(auth): เชื่อม Firebase Auth + เขียน Security Rules
week3(products): CRUD สินค้า + variant + อัปโหลดรูป
week4(chat): แชทลูกค้า-ร้าน + ส่งรูป
...
```

**เกณฑ์วัดว่า process แข็งแรง:** commit สม่ำเสมอทุกวัน/สัปดาห์
ไม่ใช่ 1 commit ใหญ่ตอนใกล้ส่ง · มี bug log ที่แก้จริง · มี commit ที่ย้อนกลับได้

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
