# Design Direction — ธีม รูปลักษณ์ และ 3D — Week 2

> Identity: **Modern Thai + Premium + Friendly + Trustworthy**
> สิ่งที่ **ไม่** ต้องการ: UI แบบนักศึกษา · เลียนแพลตฟอร์มใหญ่ตรง ๆ · gradient เยอะ ·
> animation เยอะ · 3D ทุกหน้า · หน้าจอรก

---

## 1. Visual Identity

### 1.1 สี (Design tokens → `lib/core/theme/app_colors.dart`)

| Token | ค่า | บทบาท | เหตุผล |
|---|---|---|---|
| `primary` | `#146356` | ปุ่มหลัก, สีแบรนด์, แท็บที่เลือก | Jade = ความน่าเชื่อถือ + การเติบโต สีเขียวที่ดู "พรีเมียม" ในบริบทไทย (ไม่เขียวสดแบบเก่า) |
| `primaryDark` | `#0B4439` | เฉดเงาด้านข้างของวัตถุ 3D | ทำให้สีเขียวมีมิติ ไม่แปลน |
| `accent` | `#E4A11B` | ราคาที่ลด, คะแนน, ค่าคอมมิชชัน | ทองไทย = premium + reward |
| `clay` | `#C1462F` | คูปอง, ส่วนลด, แบนเนอร์ชาว OTOP | ดินเผา = อบอุ่น ผูกกับงานฝีมือ |
| `background` | `#FAF7F2` | พื้นหลังแอป | ขาวอุ่น ไม่ขาวจนแสบตา ให้รูปสินค้าเด่น |
| `surface` | `#FFFFFF` | การ์ด | ยกจากพื้นด้วยเส้นขอบบาง ๆ แทนเงา |
| `ink` / `inkMuted` / `inkSubtle` | `#1C1B1A` / `#6B6660` / `#9A948C` | ตัวอักษร 3 ระดับ | เทาอุ่น ไม่ใช่เทาเย็น |

**สีภูมิภาค** — แต่ละภาคได้สีตัวเอง เพื่อให้การ "สำรวจตามจังหวัด" รู้สึกเหมือน
การเดินทาง ไม่ใช่การกดตัวกรอง

| ภาค | สี |
|---|---|
| เหนือ | `#3E6B8A` น้ำเงินเขียว |
| อีสาน | `#8A6A3E` น้ำตาลดิน |
| กลาง | `#7A4E8A` ม่วงอมชมพู |
| ตะวันออก | `#2E7D6F` เขียวมรกต |
| ตะวันตก | `#4E7A3E` เขียวมะกอก |
| ใต้ | `#8A3E5E` ชมพูเข้ม |

### 1.2 Typography (`app_typography.dart`)

ไม่ผูก `fontFamily` เป็นค่าเดียว เพราะฟอนต์สละอักษรไทยที่มี Latin เต็ม ๆ ไม่พบ
และการบังคับ font จะทำให้ข้อความไทยตกไปใช้ฟอนต์สำรองแบบไม่คาดคิดในแต่ละเครื่อง
→ ให้แต่ละแพลตฟอร์มใช้ฟอนต์ไทยของตัวเอง (Noto Sans Thai / Thonburi / Leelawadee UI)

> **งาน Week 5:** bundle `Noto Sans Thai` (SIL Open Font License) ลง `assets/fonts/`
> แล้วเปิดสวิตช์ `kAppFontFamily` จุดเดียว — ไม่ต้องแก้ไฟล์อื่น

สเกล: `displayLarge 34` · `displayMedium 28` · `headline 24/20/17` · `body 16/14/13` · `label 15/13/11`
ราคาใช้ weight 800 เสมอ เพื่อให้กวาดราคาได้เร็วและตัวเลขเรียงกัน

### 1.3 Spacing & Radius (`app_spacing.dart`)

- ขั้นฐาน 4px: `xxs 2 · xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24 · xxxl 32`
- gutter ของทุกหน้า = 20
- radius: `sm 8 · md 12 · lg 16 · xl 24 · pill 999`
- **กฎ:** ห้ามใส่ตัวเลขดิบใน `padding`/`margin` — ต้องใช้ token

### 1.4 กฎการออกแบบ 5 ข้อ

1. **สินค้าคือพระเอก** — พื้นหลังอุ่น ไม่มี gradient รัวหลายชั้น การ์ดใช้เส้นขอบบางแทนเงา
2. **หนึ่งหน้าหนึ่งงาน** — ปุ่มหลักได้หน้าละ 1 อัน
3. **ราคาต้องเห็นทันที** — `priceLarge` + ตำแหน่งเดียวกันทุกหน้า
4. **48px ขึ้นไปสำหรับปุ่มและ tab** — เพื่อ accessibility
5. **gradient ใช้ได้ที่เดียวคือ hero** — ที่อื่นใช้สีทึบ

---

## 2. 3D Direction

### 2.1 หลักการจากโจทย์

> **3D = Attention · 2D = Function**

ดังนั้น **3D ใช้เฉพาะหน้า Login** และ Product Card ทั้งหมดเป็น **2D** เพื่อให้โหลดเร็ว
และเลื่อนลื่น

### 2.2 วิธีทำ 3D ที่เลือก (และเหตุผลที่ไม่ใช้ 3D engine)

| ทางเลือก | ผลลัพธ์ | ตัดสินใจ |
|---|---|---|
| `model_viewer_plus` / WebGL | ต้องมีไฟล์ `.glb` ที่ต้องหามา กินเฟรมเรตบน Android รุ่นเก่า (กลุ่มผู้ซื้อ OTOP หลัก) | ❌ |
| Lottie | เป็น 2D แบบเคลื่อนไหว ไม่ใช่ 3D | ❌ ไม่ตรงโจทย์ |
| **Isometric CustomPainter (เลือก)** | เป็นการฉาย 3D จริง (x,y,z → 2D) แล้ววาดด้วยเส้น/พื้นที่ จึงได้มิติจริงแบบ 60fps | ✅ |

**สิ่งที่ได้ (อยู่ใน `lib/features/auth/widgets/hero_3d.dart`):**

- กล่องของฝากชาว OTOP วาดเป็น isometric จริง 6 หน้า
- ผ้าใบจากกระดาษห่อสีทอง คาดเส้นผม + โบว์สีดินเผา
- แสงจากด้านบน (top face สว่างสุด → right face เข้มสุด) = สร้าง volume
- เงาแบบ ellipse แบนตามระนาบพื้น isometric
- glow แบบ radial เบื้องหลัง
- จุดแสงลอย 5 จุด (อ่านว่า "งานฝีมือ" ไม่ใช่ "เทค")
- ลอยขึ้นลง + เอียงเล็กน้อย วนลูป 6 วินาที
- **เคารพ `MediaQuery.disableAnimations`** — ถ้าผู้ใช้เปิด "ลดการเคลื่อนไหว" จะหยุดทันที
- ห่อ `Semantics(image: true, label: ...)` เพื่อ screen reader

> จุดเสียบที่ไว้: ถ้าภายหลังมีไฟล์ 3D จริง ให้เปลี่ยนเฉพาะ widget ข้างใน — layout ไม่ต้องแก้

### 2.3 Product Card = 2D เสมอ

เหตุผลทางเทคนิค: หน้า Home มีรายการยาว (สินค้าเด่น + ร้าน + เรื่องราว + แนะนำโปรโมต)
ถ้าทุกใบเป็น 3D จะทำให้ **scroll ไม่ลื่นและกินแบตเตอรี่** ซึ่งขัดกับคุณค่า
"เร็วและไม่หนัก" ของแอป → Product Card จึงเป็นภาพ 2D + `cached_network_image`
เพื่อไม่โหลดซ้ำตอนเลื่อน

---

## 3. เส้นทางการทำภาพ (Assets)

| ภาพ | แหล่ง | หมายเหตุ |
|---|---|---|
| Hero 3D | โค้ด (`hero_3d.dart`) | ไม่ต้องมีไฟล์ |
| รูปสินค้า | Cloudinary (อัปโหลดจริง, free ไม่ต้องผูกบัตร) | มี 2 รูปขึ้นไปต่อสินค้า |
| รูปปกร้าน | Cloudinary | 1 รูป ใช้ทั้งแบนเนอร์และหน้าร้าน |
| แผนที่ไทย 2D | โค้ด/วาดเอง | ไม่ใช้ 3D map |

**Demo store policy:** ทุกร้านในข้อมูล demo ต้องเป็น **ร้านสมมติ มีคำว่า "Demo"**
และห้ามอ้างว่าเป็นร้านที่เข้าร่วม Platform จริง

---

## 4. Accessibility (ตั้งใจตั้งแต่ต้น)

| ข้อกำหนด | ทำอย่างไร |
|---|---|
| ขนาดแตะขั้นต่ำ | `AppSizes.minTapTarget = 48` บังคับใน button theme ทุกปุ่ม |
| ไม่ใช้สีสื่อความหมายเพียงอย่างเดียว | สถานะสินค้าหมดมีทั้งข้อความ + ขีดฆ่า + ปุ่ม disabled |
| ลดการเคลื่อนไหว | `Hero3d` หยุดเมื่อ `disableAnimations = true` |
| อ่านด้วย screen reader | Hero มี `Semantics(label:)` |
| ความคมชัดของตัวอักษร | ตัวเลขราคาใช้ weight 800 บนพื้นสว่าง คอนทราสต์ผ่าน |
| Error ต้องเห็น | `errorStyle` ใน `InputDecorationTheme` + ไม่พึ่งสีแดงอย่างเดียว |

---

## 5. สิ่งที่ทำในโค้ดแล้ว (Week 2)

- [x] `app_colors.dart` — palette + สีภูมิภาค + gradient helper
- [x] `app_typography.dart` — 15 text styles + กลไกสลับ font ใน Week 5
- [x] `app_spacing.dart` — spacing ladder, radius, elevation, min tap target
- [x] `app_theme.dart` — ThemeData light/dark + component themes ครบ
- [x] `app_strings.dart` — ข้อความไทยทั้งหมดรวม empty/error state
- [x] `hero_3d.dart` — isometric 3D + animation + accessibility
- [x] `login_screen.dart` — โครงหน้า Login ตาม W1
- [x] `flutter analyze` = 0 issue, `flutter build web` = สำเร็จ
