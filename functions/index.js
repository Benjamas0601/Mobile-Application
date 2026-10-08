/**
 * Thai OTOP Marketplace — Cloud Functions
 *
 * client SDK ไม่มีทางลบ *บัญชี Firebase Auth ของคนอื่น* ได้
 * (`auth.deleteUser` ต้องเป็นฝั่ง server เท่านั้น) หน้าจอผู้ดูแลจึงเรียก
 * `adminDeleteUser` ที่นี่ ซึ่งทำงานด้วยสิทธิ์ Admin SDK เพื่อลบทั้งบัญชี Auth
 * และโพรไฟล์ Firestore + ร้าน/สินค้าของคนนั้น
 *
 * หลักการ: งานที่ต้องไว้ใจได้ (ลบบัญชี, ตรวจราคา, แจ้งเตือน) อยู่ที่นี้
 * เพราะ `firestore.rules` ไว้ใจตัวเลข/รหัสที่ client ส่งมาไม่ได้ และลบ
 * บัญชี Auth ไม่ได้
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

const CHUNK = 400;

/** Firestore batch จำกัด 500 write ต่อครั้ง จึงแบ่งลบเป็นก้อน ๆ */
async function deleteInBatches(refs) {
  let offset = 0;
  while (offset < refs.length) {
    const batch = db.batch();
    refs.slice(offset, offset + CHUNK).forEach((ref) => batch.delete(ref));
    await batch.commit();
    offset += CHUNK;
  }
}

/**
 * ลบร้านพร้อมสินค้า ตัวแปรสินค้า และรีวิวของร้านนั้น ประวัติคำสั่งซื้ออยู่
 * ในออเดอร์แบบภาพนิ่งของสินค้า จึงไม่เสียหายเมื่อลบ
 */
async function deleteStoreData(storeId) {
  const refs = [];

  const products = await db
    .collection('products')
    .where('storeId', '==', storeId)
    .get();
  for (const product of products.docs) {
    const variants = await db
      .collection('product_variants')
      .where('productId', '==', product.id)
      .get();
    variants.docs.forEach((v) => refs.push(v.ref));

    const reviews = await db
      .collection('reviews')
      .where('productId', '==', product.id)
      .get();
    reviews.docs.forEach((r) => refs.push(r.ref));

    refs.push(product.ref);
  }

  refs.push(db.collection('stores').doc(storeId));
  await deleteInBatches(refs);
}

/**
 * ลบบัญชี Auth และข้อมูล Firestore ของผู้ใช้ ตรวจผู้เรียกจากโพรไฟล์
 * `users/{uid}` (Admin SDK ข้าม rules จึงต้องตรวจที่นี่ ไม่ใช่ใน rules)
 *
 * เงื่อนไขเดียวกับฝั่ง client:
 *   * ต้องล็อกอินและมีบทบาท `admin`;
 *   * ห้ามลบบัญชีตัวเอง;
 *   * ห้ามลบบัญชีแอดมินด้วยกัน
 */
exports.adminDeleteUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'ต้องเข้าสู่ระบบก่อน');
  }
  const callerUid = context.auth.uid;
  const targetUid = data && data.uid;
  if (typeof targetUid !== 'string' || targetUid.length === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'ต้องระบุ uid ของผู้ใช้ที่จะลบ'
    );
  }
  if (targetUid === callerUid) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'ลบบัญชีของตัวเองไม่ได้'
    );
  }

  const callerDoc = await db.collection('users').doc(callerUid).get();
  const callerRoles = callerDoc.exists ? callerDoc.data().roles : [];
  if (!Array.isArray(callerRoles) || !callerRoles.includes('admin')) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'เฉพาะผู้ดูแลระบบเท่านั้น'
    );
  }

  const targetDoc = await db.collection('users').doc(targetUid).get();
  const targetRoles = targetDoc.exists ? targetDoc.data().roles : [];
  if (Array.isArray(targetRoles) && targetRoles.includes('admin')) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'ลบบัญชีผู้ดูแลระบบไม่ได้'
    );
  }

  // ลบร้านและสินค้าในร้านก่อน (ประวัติออเดอร์คงอยู่)
  const stores = await db
    .collection('stores')
    .where('ownerUid', '==', targetUid)
    .get();
  for (const store of stores.docs) {
    await deleteStoreData(store.id);
  }

  if (targetDoc.exists) {
    await targetDoc.ref.delete();
  }

  // ลบบัญชี Auth เป็นขั้นสุดท้าย — ถ้าเขียน Firestore พังกลางคัน จะได้ไม่
  // เหลือบัญชีไร้โพรไฟล์ที่ยังเข้าใช้ได้
  await admin.auth().deleteUser(targetUid);

  return { uid: targetUid };
});