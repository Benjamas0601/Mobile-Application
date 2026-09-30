# 07 — คู่มือตั้งค่า Cloudinary (เก็บรูปฝั่งขาย)

> โปรเจกต์นี้เก็บรูปบน **Cloudinary free** ไม่ใช่ Firebase Storage
> เพราะ Cloud Storage for Firebase บังคับให้อยู่บนแผน **Blaze** (ต้องผูกบัตรเครดิต)
> ดูเหตุผลเต็มใน [`06_week_plan.md`](06_week_plan.md#%EF%B8%8F-เก็บรูปด้วย-cloudinary-firebase-storage-ใช้ไม่ได้โดยไม่ผูกบัตร)

## ค่าที่ฝังไว้แล้ว

| ค่า | ตัวแปร | ค่าในโปรเจกต์ |
|---|---|---|
| Cloud name | `CLOUDINARY_CLOUD_NAME` | `zqaixbny` |
| Unsigned upload preset | `CLOUDINARY_UPLOAD_PRESET` | `otop_shop` |

ทั้งสองค่าฝังเป็น `defaultValue` ใน `lib/core/config/cloudinary_config.dart` จึง
`flutter run` แล้วอัปโหลดรูปได้เลยโดยไม่ต้องส่ง flag

**ทำไมฝังได้ทั้งที่เป็น credential** — เพราะสองค่านี้ไม่ใช่ความลับ:

- `cloudName` โผล่ใน URL ของรูปทุกใบ (`res.cloudinary.com/<cloud_name>/...`) ใครก็อ่านได้จากรูปที่เห็นอยู่แล้ว
- `uploadPreset` เป็น **unsigned preset** ที่ Cloudinary ออกแบบมาให้เป็น public โดยเฉพาะ
  ถ้าไม่ใช้ unsigned มือถือจะต้องฝัง API secret ในแอป ซึ่งแกะออกมาได้ทันที

> ⚠️ **ห้ามเด็ดขาด:** อย่าส่ง `CLOUDINARY_API_SECRET` เข้า build ที่ปล่อยจริง
> ใครก็แก้ไฟล์ APK ได้ แล้วเข้าถึงบัญชีของเราได้ (เช่น ลบทุกรูปใน Media Library)
> ค่านี้มีไว้แค่ตอน dev เพื่อ **ลบ** ไฟล์ทดสอบ

## รันแอป

```bash
flutter run
```

ถ้าอยากชี้คนละคลาวด์ (เช่นตอนทดสอบ preset ใหม่):

```bash
flutter run --dart-define=CLOUDINARY_CLOUD_NAME=<cloud_name> ^
            --dart-define=CLOUDINARY_UPLOAD_PRESET=<preset_name>
```

ตรวจว่าตั้งค่าแล้วหรือยัง:

```dart
CloudinaryConfig.isConfigured // cloudName + uploadPreset ต้องไม่ว่างทั้งคู่
```

ถ้าเป็น `false` แอปจะขึ้นข้อความแทนที่จะยิง request ไป URL ที่ไม่มีชื่อ cloud

## ถ้าจะสร้างค่าของตัวเอง

1. สมัครที่ [cloudinary.com](https://cloudinary.com) (free ไม่ต้องบัตร)
2. ดู **Cloud name** ได้จากหน้าแรกของ console — อยู่ใต้ชื่อบัญชี
   > ⚠️ มักสับสนกับ **API key** ซึ่งเป็นคนละช่อง ถ้าใส่ค่าผิดจะได้ `Unknown API key`
3. ไปที่ **Settings → Upload presets → Add upload preset**
   - Signing mode: **Unsigned**
   - Folder mode: เลือกตามต้องการ (โปรเจกต์นี้ส่ง folder ไปกับ request อยู่แล้ว)
   - Folder: เว้นว่าง
   - Max file size: 10 MB (แอปบังคับที่ 5 MB อยู่แล้ว)
4. เอาค่าชื่อ preset ไปใส่ใน `defaultValue` หรือส่งผ่าน `--dart-define`

## โครงสร้าง path

กำหนดไว้ใน `ImageUploadPolicy` (`lib/core/services/image/image_storage_service.dart`)
ใช้รูปแบบเดียวกับที่เคยวางไว้สำหรับ Firebase Storage เพื่อให้ย้ายกลับทีหลังได้โดยไม่ต้องแก้ข้อมูลใน Firestore

| รูป | path |
|---|---|
| รูปสินค้า | `stores/<storeId>/products/<productId>` |
| ภาพครอบร้าน | `stores/<storeId>/cover` |
| โลโก้ร้าน | `stores/<storeId>/logo` |
| รูปโปรไฟล์ผู้ใช้ | `users/<uid>/profile` |
| รูปรีวิว | `reviews/<productId>` |

`uploadImage` จะเรียก `sanitizeFolder()` ก่อนอัปโหลดเสมอ ซึ่งตัดส่วน `..` ทิ้ง
— Cloudinary เองไม่ได้กัน path traversal ฉะนั้นถ้าเรียก API ตรง ๆ อาจเขียนทับรูปนอกโฟลเดอร์ที่ตั้งใจได้

## สิ่งที่ต้องรู้

**ลบไฟล์ต้องมี API secret** — unsigned preset ลบไฟล์ไม่ได้ (เป็นข้อจำกัดของ Cloudinary free
ที่ออกแบบมาเพื่อความปลอดภัย) ถ้าเผลออัปโหลดรูปทดสอบ ให้ลบที่หน้า Media Library เอง

**โควตา** — free tier ให้ 25 credits/เดือน เช็คการใช้งานที่
[cloudinary.com/console/account/billing/history](https://cloudinary.com/console/account/billing/history)
ถ้าเกินโควตา รูปใหม่จะอัปโหลดไม่ได้ (รูปเก่าที่อัปโหลดแล้วยังใช้ได้)

**ข้อจำกัดของ `ImageStorageService`** — ตัว service ใช้ `MultipartFile.fromPath`
จึงรับได้เฉพาะไฟล์ที่มีอยู่จริงบนดิสก์ (`image_picker` ให้ path จริงเสมอ จึงไม่มีปัญหา
แต่ถ้าเขียนเทสต์เองต้องเขียนไฟล์ลงดิสก์ก่อน ใช้ `XFile.fromData` ไม่ได้)

## ตรวจสอบว่าต่อ Cloudinary ได้จริง

```bash
flutter analyze
flutter test
flutter test integration_test/seller_catalog_flow_test.dart -d emulator-5554
```

`test/image_storage_test.dart` ครอบคลุม:
- ต่อ Cloudinary จริง + override fake ได้
- ค่า config ว่าง → `ImageUploadException` พร้อมบอกว่าต้องตั้ง flag อะไร
- path ทุกแบบตรงกับที่กำหนด และ `..` ถูกตัดออก
- ชนิดไฟล์ที่ไม่รับถูกปฏิเสธก่อนออกไปเน็ต

การอัปโหลดจริงกับเครืองานควรทำครั้งเดียวตอนตั้งค่า credential เพราะกินโควตา
