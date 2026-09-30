# thai_otop_marketplace

ตลาดออนไลน์ OTOP — ผู้ซื้อดูของได้โดยไม่ต้องมีบัญชี · ผู้ขายจัดการร้าน สินค้า
และออเดอร์ผ่าน Seller Hub

Flutter + Riverpod · Firestore (`thaiotop-587f1`) · Cloudinary (เก็บรูป)

---

## เริ่มใช้งานเร็ว

```powershell
.\tool\run.ps1
```

คำสั่งเดียวจบ: เปิด emulator → build APK → ติดตั้ง → เปิดแอป

> ต้องเปิด PowerShell ที่โฟลเดอร์โปรเจกต์นี้ (ถ้าอยู่นอก ใช้ path เต็ม)

| คำสั่ง | ทำอะไร |
|---|---|
| `.\tool\run.ps1` | เปิด emulator + build + ติดตั้ง + เปิดแอป |
| `.\tool\run.ps1 up -SkipBuild` | ข้าม build (ติดตั้ง APK ที่มีอยู่แล้ว — เร็วกว่ามาก) |
| `.\tool\run.ps1 start` | เปิด emulator อย่างเดียว |
| `.\tool\run.ps1 stop` | ปิด emulator |
| `.\tool\run.ps1 build` | build APK debug |
| `.\tool\run.ps1 install` | ติดตั้ง APK ล่าสุด |
| `.\tool\run.ps1 launch` | เปิดแอปที่ติดตั้งแล้ว |
| `.\tool\run.ps1 logs` | ดู logcat ของแอป (Ctrl+C หยุด) |
| `.\tool\run.ps1 status` | ดูอุปกรณ์และ emulator ที่มี |

### เปลี่ยนไปใช้ AVD อื่น

มี 2 ตัว: `Pixel_9` (Android 16, ค่าเริ่มต้น) และ `Pixel_7`

```powershell
.\tool\run.ps1 up -Avd Pixel_7
flutter emulators        # ดูรายชื่อทั้งหมด
```

---

## Android Studio

Android Studio **เปิด emulator ให้เองไม่ได้** ต้องกดเองทุกครั้ง — ใช้สคริปต์ข้างบนแทน
หรือกด Run ที่ Device Manager > Virtual Devices

AVD ไม่ได้อยู่ในโฟลเดอร์ `android/` ของโปรเจกต์ แต่อยู่ที่:

| อะไร | ที่ไหน |
|---|---|
| ตัวโปรแกรม emulator | `D:\Android\sdk\emulator\emulator.exe` |
| นิยาม AVD (Pixel_7 / Pixel_9) | `C:\Users\HP\.android\avd\` |
| system image | `D:\Android\sdk\system-images\` |
| path ที่ SDK/AVD ชี้ไป | `android/local.properties` → `sdk.dir` |

> เครื่องนี้มี Android Studio 2 ตัว (`Android Studio` กับ `Android Studio1`)
> ถ้าเปิดผิดตัวจะไม่เห็น AVD — ตัวที่ใช้ config แล้วคือ `Android Studio`

## VS Code

ติดตั้ง Flutter + Dart extensions แล้วเลือก device จากมุมขวาล่าง
หรือกด **F5** ได้เลย — `.vscode/launch.json` ตั้งค่าไว้ให้แล้ว 2 แบบ:

- `thai_otop_marketplace (emulator-5554)` — บน emulator
- `thai_otop_marketplace (Chrome)` — บนเว็บ

PATH ตั้งครบแล้ว (`D:\flutter\bin`, `platform-tools`, `emulator`) จึงไม่ต้องแก้อะไรเพิ่ม
> F5 จะ build ใหม่ทุกครั้ง (ช้าประมาณ 1–2 นาที) ถ้าอยากเร็วให้ใช้
> `.\tool\run.ps1 up -SkipBuild` แทน

---

## เข้าสู่ระบบ (บัญชีทดสอบ)

รหัสผ่านเดียวกันทุกบัญชี: `OtopDemo123`

| บัญชี | บทบาท |
|---|---|
| `customer@example.com` | ผู้ซื้อ |
| `seller.north@example.com` | ผู้ขาย (ร้านชิงไทย) |
| `seller.central@example.com` | ผู้ขาย (ร้านสวัสดี) |
| `seller.south@example.com` | ผู้ขาย (ร้านตำรับ) |
| `admin@example.com` | แอดมิน |

ดูวิธีสร้างข้อมูลตั้งต้นใหม่ที่ `tool/seed_firestore.js`

---

## เก็บรูปด้วย Cloudinary

ใช้ **unsigned upload preset** จึงไม่ต้องฝัง API secret ในแอป (คนอื่นแก้ APK
ได้ ถ้าฝัง secret ไว้รั่วแน่นอน)

ค่า cloud name + preset ฝัง default ไว้ใน `lib/core/config/cloudinary_config.dart`
แล้ว — **`git clone` มาแล้ว `flutter run` อัปโหลดรูปได้เลย ไม่ต้องส่ง flag**
ทั้งสองค่าไม่ใช่ความลับ (cloud name โผล่ใน URL รูป · unsigned preset เป็น public
โดยการออกแบบ) ดูเหตุผลแบบเต็มที่ `docs/07_cloudinary_setup.md`

> `CLOUDINARY_API_SECRET` คือค่าเดียวที่ห้ามฝังและห้ามส่งเข้า build ที่ปล่อยจริง
> ต้องการชี้ cloud อื่นตอน build:
> `--dart-define=CLOUDINARY_CLOUD_NAME=...`

---

## ตรวจสอบก่อนส่งงาน

```powershell
flutter analyze        # ต้องเป็น No issues found!
flutter test           # 146 เคส
```

E2E ต้องใช้ emulator ที่เปิดไว้ก่อน:

```powershell
.\tool\run.ps1 start
flutter test integration_test -d emulator-5554
```

---

## โครงสร้าง

```
lib/
  core/          config, routes, theme, services, constants
  models/        fromFirestore / toFirestore
  repositories/  business logic (ห้ามคำนวณใน Widget)
  providers/     Riverpod ระดับแอป
  features/      auth home products stores cart orders seller
  widgets/       ใช้ร่วมทั้งแอป
tool/
  run.ps1                เปิด emulator + ติดตั้งแอป
  seed_firestore.js      สร้างข้อมูลตั้งต้น
docs/
  01_product_problem.md  02_user_flows.md      03_wireframes.md
  04_design_direction.md 05_architecture.md   06_week_plan.md
  07_cloudinary_setup.md
```

**กฎที่บังคับ**
- `core/` ห้าม import จาก `features/`
- หน้าจอห้ามเรียก Firebase SDK ตรง ๆ ต้องผ่าน Repository
- business logic (ส่วนลด / commission / สต็อก) ห้ามอยู่ใน Widget
- ข้อความ UI ใหม่ต้องอยู่ใน `AppStrings`
