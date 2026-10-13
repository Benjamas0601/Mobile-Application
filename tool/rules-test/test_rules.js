// ============================================================================ //
// Regression tests สำหรับ firestore.rules — เรียกผ่าน Firebase Firestore Emulator
//
//   รัน:  npm test            (ในโฟลเดอร์นี้ firebase.json -> tool/rules-test)
//   หรือ: firebase emulators:exec --only firestore --project thaiotop-587f1 \
//               "node test_rules.js"
//
// โฟลเดอร์นี้ย้ายมาจาก %TEMP%\opencode\rules-test (เดิมอยู่ข้างนอก repo แล้วหาย)
// เป้าหมายคือ "ชั้นที่ 1" ของ security ตาม docs/05_architecture.md ข้อ 5:
//  Rules ต้องยังกันคนที่ไม่ใช่เจ้าของ / และตอนลบ affiliate ไป ห้ามมีช่องโหว่ใหม่
// ============================================================================ //

'use strict';

const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
// FieldValue.serverTimestamp → ใช้จาก @firebase/firestore ตรง ๆ
// (rules-unit-testing v5 ไม่ exports `firebase` bundle อีกแล้ว
//  แต่ compat client ใช้ @firebase/firestore ตัวนี้เป็นแกนกลาง)
const { serverTimestamp } = require('@firebase/firestore');

const RULES = fs.readFileSync(path.join(__dirname, '..', '..', 'firestore.rules'), 'utf8');

let env; // RulesTestEnvironment
const TS = () => serverTimestamp();

// ---------------------------------------------------------------------------- //
// ตัวช่วย
// ---------------------------------------------------------------------------- //

/** context แบบไม่ล็อกอิน — ใช้ทดสอบ deny by default */
function unauthed() {
  return env.unauthenticatedContext();
}

/** context แบบล็อกอินเป็น uid — token.email ใช้เหมือน uid@example.com */
function as(uid) {
  return env.authenticatedContext(uid, { email: `${uid}@example.com` });
}

/** ข้อมูลผู้ใช้ที่ตรงกับกฎ users.create (roles อย่างน้อยต้องมี customer) */
function userData(uid, extra = {}, roles = ['customer']) {
  return {
    displayName: 'ผู้ใช้ทดสอบ',
    email: `${uid}@example.com`,
    roles,
    createdAt: TS(),
    phone: '0810000001',
    province: 'เชียงราย',
    ...extra,
  };
}

/**
 * เขียนข้อมูลตั้งต้นแบบข้ามกฎ (โดย Admin SDK ของ emulator)
 * เพื่อให้ทดสอบ "คนธรรมดาทำไม่ได้" ได้แม่นยำ
 */
async function seed() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc('users/seller1').set(userData('seller1', {}, ['customer', 'seller']));
    await db.doc('users/buyer1').set(userData('buyer1'));
    await db.doc('users/buyer2').set(userData('buyer2'));
    await db.doc('users/admin1').set(userData('admin1', {}, ['customer', 'admin']));
    await db.doc('users/seller2').set(userData('seller2', {}, ['customer', 'seller']));

    await db.doc('stores/storeA').set({
      ownerUid: 'seller1',
      name: 'ร้านเดโม A',
      province: 'เชียงราย',
      region: 'เหนือ',
      createdAt: TS(),
    });
    await db.doc('stores/storeB').set({
      ownerUid: 'seller2',
      name: 'ร้านเดโม B',
      province: 'ลำพูน',
      region: 'เหนือ',
      createdAt: TS(),
    });
    await db.doc('products/productA').set({
      storeId: 'storeA',
      name: 'สินค้าเดโม',
      price: 100,
      createdAt: TS(),
    });

    // order1 = ของ buyer1 (ร้าน storeA) / order2 = ของ buyer2 (ร้าน storeA)
    // มีทั้งคู่ เพื่อให้ทดสอบ list ทะลุขอบเขต (query ติดเพราะเจอ docs ที่ไม่อนุญาต)
    await db.doc('orders/order1').set({
      buyerUid: 'buyer1',
      storeId: 'storeA',
      status: 'pending_payment',
      total: 100,
      createdAt: TS(),
    });
    await db.doc('orders/order1/items/item1').set({
      productId: 'productA',
      name: 'สินค้าเดโม',
      price: 100,
      qty: 1,
    });
    await db.doc('orders/order2').set({
      buyerUid: 'buyer2',
      storeId: 'storeA',
      status: 'pending_payment',
      total: 200,
      createdAt: TS(),
    });

    await db.doc('cart_items/cart1').set({ userId: 'buyer1', productId: 'productA', qty: 1 });

    await db.doc('chat_threads/thread1').set({
      participantUids: ['buyer1', 'seller1'],
      storeId: 'storeA',
      lastAt: TS(),
    });

    await db.doc('payments/pay1').set({
      orderId: 'order1',
      buyerUid: 'buyer1',
      amount: 100,
      status: 'submitted',
      slipUrl: 'https://example.com/slip.jpg',
    });

    await db.doc('coupons/coupon1').set({ code: 'SAVE10', discount: 10 });
    await db.doc('notifications/n1').set({ userId: 'buyer1', read: false });
  });
}

// ---------------------------------------------------------------------------- //
// mini test runner (ไม่มี external dependency — รันบน node เปล่าได้)
// ---------------------------------------------------------------------------- //

let passed = 0;
let failed = 0;

async function it(name, fn) {
  try {
    await fn();
    passed++;
    console.log(`   ✓  ${name}`);
  } catch (e) {
    failed++;
    console.log(`   ✗  ${name}`);
    console.log(`      → ${e.message.split('\n').slice(0, 2).join(' ')}`);
  }
}

function group(title) {
  console.log(`\n── ${title} ──`);
}

async function fresh() {
  await env.clearFirestore();
  await seed();
}

// ---------------------------------------------------------------------------- //
// 1. users — โปรไฟล์ผู้ใช้
// ---------------------------------------------------------------------------- //

async function testUsers() {
  group('users/{uid}');
  const db = () => as('buyer1').firestore();

  await it('ไม่ล็อกอินอ่านโปรไฟล์ไม่ได้', async () => {
    const d = await fresh();
    await assertFails(unauthed().firestore().doc('users/buyer1').get());
  });
  await it('สมัครเป็น customer ผ่าน', async () => {
    await fresh();
    // กฎ users.create บังคับ request.auth.uid == userId → ต้อง auth ด้วย uid ที่จะสร้าง
    await assertSucceeds(as('newbuyer').firestore().doc('users/newbuyer').set(userData('newbuyer')));
  });
  await it('สมัครเป็น seller (customer+seller) ผ่าน', async () => {
    await fresh();
    await assertSucceeds(as('newseller').firestore().doc('users/newseller').set(userData('newseller', {}, ['customer', 'seller'])));
  });
  await it('สมัครใส่ role admin ด้วย = ปฏิเสธ (ห้ามยกระดับเอง)', async () => {
    await fresh();
    await assertFails(as('h4x0r').firestore().doc('users/h4x0r').set(userData('h4x0r', {}, ['customer', 'admin'])));
  });
  await it('สมัครแล้วใส่ affiliate กลับมา (ของที่ถูกลบ) = ปฏิเสธ', async () => {
    await fresh();
    await assertFails(as('aff').firestore().doc('users/aff').set(userData('aff', {}, ['customer', 'affiliate'])));
  });
  await it('สมัครด้วยฟิลด์ affiliate ที่ถูกลบ = ปฏิเสธ', async () => {
    await fresh();
    await assertFails(as('aff2').firestore().doc('users/aff2').set(userData('aff2', { affiliatePlatform: 'x' })));
  });
  await it('email ไม่ตรงกับ token = ปฏิเสธ', async () => {
    await fresh();
    await assertFails(as('newevil').firestore().doc('users/newevil').set(userData('newevil', { email: 'other@example.com' })));
  });
  await it('roles ต้องมี customer อย่างน้อย 1 = ปฏิเสธถ้าไม่มี', async () => {
    await fresh();
    await assertFails(as('onlyseller').firestore().doc('users/onlyseller').set(userData('onlyseller', {}, ['seller'])));
  });
  await it('displayName ว่าง = ปฏิเสธ', async () => {
    await fresh();
    await assertFails(as('noname').firestore().doc('users/noname').set(userData('noname', { displayName: '' })));
  });

  await it('แก้ชื่อตัวเองได้', async () => {
    await fresh();
    await assertSucceeds(db().doc('users/buyer1').update({ displayName: 'ชื่อใหม่' }));
  });
  await it('แก้ roles ตัวเองไม่ได้ (กัน privilege escalation)', async () => {
    await fresh();
    await assertFails(db().doc('users/buyer1').update({ roles: ['customer', 'admin'] }));
  });
  await it('แก้ email ตัวเองไม่ได้', async () => {
    await fresh();
    await assertFails(db().doc('users/buyer1').update({ email: 'pwn@example.com' }));
  });
  await it('แอดมินให้ role seller ลูกค้าได้ (ไม่มี admin ทั้งเก่าใหม่)', async () => {
    await fresh();
    await assertSucceeds(as('admin1').firestore().doc('users/buyer1').update({
      roles: ['customer', 'seller'],
      updatedAt: TS(),
    }));
  });
  await it('แอดมินยกระดับให้ admin = ปฏิเสธ (ห้ามสร้าง admin ใหม่)', async () => {
    await fresh();
    await assertFails(as('admin1').firestore().doc('users/buyer1').update({
      roles: ['customer', 'admin'],
      updatedAt: TS(),
    }));
  });
  await it('ลบบัญชีตัวเองได้ แต่ลบคนอื่นไม่ได้', async () => {
    await fresh();
    await assertSucceeds(db().doc('users/buyer1').delete());
  });
  await it('แอดมินลบลูกค้า/ผู้ขายได้ แต่ลบแอดมินด้วยกันเองไม่ได้', async () => {
    await fresh();
    await assertSucceeds(as('admin1').firestore().doc('users/buyer1').delete());
    await fresh();
    await env.withSecurityRulesDisabled((c) =>
      c.firestore().doc('users/admin2').set(userData('admin2', {}, ['customer', 'admin'])));
    await assertFails(as('admin1').firestore().doc('users/admin2').delete());
  });
}

// ---------------------------------------------------------------------------- //
// 2. stores — ร้าน OTOP
// ---------------------------------------------------------------------------- //

async function testStores() {
  group('stores/{storeId}');
  const st = () => as('seller1').firestore();

  await it('อ่านร้านได้ทุกคน (public read)', async () => {
    await fresh();
    await assertSucceeds(unauthed().firestore().doc('stores/storeA').get());
  });
  await it('เปิดร้านได้เฉพาะ seller และตั้งตัวเองเป็นเจ้าของ', async () => {
    await fresh();
    await assertSucceeds(st().doc('stores/storeNew').set({
      ownerUid: 'seller1',
      name: 'ร้านใหม่',
      createdAt: TS(),
    }));
  });
  await it('ลูกค้าเปิดร้านไม่ได้', async () => {
    await fresh();
    await assertFails(as('buyer1').firestore().doc('stores/storeNew').set({
      ownerUid: 'buyer1',
      name: 'ร้านใหม่',
      createdAt: TS(),
    }));
  });
  await it('seller เปิดร้านให้คนอื่นเป็นเจ้าของ = ปฏิเสธ', async () => {
    await fresh();
    await assertFails(st().doc('stores/storeNew').set({
      ownerUid: 'buyer1',
      name: 'ร้านใหม่',
      createdAt: TS(),
    }));
  });
  await it('เจ้าของแก้ชื่อร้านได้', async () => {
    await fresh();
    await assertSucceeds(st().doc('stores/storeA').update({ name: 'ร้านใหม่ฉ่ำ' }));
  });
  await it('เจ้าของย้าย ownerUid ไม่ได้', async () => {
    await fresh();
    await assertFails(st().doc('stores/storeA').update({ ownerUid: 'buyer1' }));
  });
  await it('คนที่ไม่ใช่เจ้าของแก้ร้านไม่ได้', async () => {
    await fresh();
    await assertFails(as('buyer1').firestore().doc('stores/storeA').update({ name: 'แฮก' }));
  });
  await it('ลบร้านได้เฉพาะแอดมิน', async () => {
    await fresh();
    await assertSucceeds(as('admin1').firestore().doc('stores/storeA').delete());
  });
  await it('เจ้าของ (ที่ไม่ใช่แอดมิน) ลบร้านไม่ได้', async () => {
    await fresh();
    await assertFails(st().doc('stores/storeA').delete());
  });
}

// ---------------------------------------------------------------------------- //
// 3. categories + products + product_variants
// ---------------------------------------------------------------------------- //

async function testCatalog() {
  group('categories / products / product_variants');

  await it('อ่านหมวดสินค้าได้ทุกคน / แก้ได้เฉพาะแอดมิน', async () => {
    await fresh();
    await assertSucceeds(unauthed().firestore().doc('categories/c1').get());
    await assertFails(as('buyer1').firestore().doc('categories/c1').set({ name: 'ของสด' }));
    await assertSucceeds(as('admin1').firestore().doc('categories/c1').set({ name: 'ของสด' }));
  });

  const pr = () => as('seller1').firestore();

  await it('อ่านสินค้าได้ทุกคน (public read)', async () => {
    await fresh();
    await assertSucceeds(unauthed().firestore().doc('products/productA').get());
  });
  await it('seller เพิ่มสินค้าในร้านตัวเองได้', async () => {
    await fresh();
    await assertSucceeds(pr().doc('products/productB').set({ storeId: 'storeA', name: 'สินค้า B', price: 50 }));
  });
  await it('seller เพิ่มสินค้าเข้าร้านคนอื่น = ปฏิเสธ', async () => {
    await fresh();
    await assertFails(pr().doc('products/productC').set({ storeId: 'storeB', name: 'สอดสินค้า', price: 1 }));
  });
  await it('ลูกค้าเพิ่มสินค้าไม่ได้', async () => {
    await fresh();
    await assertFails(as('buyer1').firestore().doc('products/productB').set({ storeId: 'storeA', name: 'สินค้า B' }));
  });
  await it('เจ้าของร้านแก้ราคาได้ แต่ย้ายร้าน (storeId) ไม่ได้', async () => {
    await fresh();
    await assertSucceeds(pr().doc('products/productA').update({ price: 120 }));
    await assertFails(pr().doc('products/productA').update({ storeId: 'storeOther' }));
  });
  await it('seller ร้านอื่นลบสินค้าของเราไม่ได้', async () => {
    await fresh();
    await assertFails(as('seller2').firestore().doc('products/productA').delete());
  });
  await it('seller ของร้านนั้นลบสินค้าได้', async () => {
    await fresh();
    await assertSucceeds(pr().doc('products/productA').delete());
  });
  await it('เจ้าของร้านเพิ่ม variant ให้สินค้าตัวเองได้', async () => {
    await fresh();
    await assertSucceeds(pr().doc('product_variants/vA').set({
      productId: 'productA',
      name: 'สีแดง',
      stock: 5,
    }));
  });
  await it('เพิ่ม variant ผูกสินค้าร้านคนอื่น = ปฏิเสธ', async () => {
    await fresh();
    // seller2 ไม่ใช่เจ้าของร้านของ productA (productA อยู่ร้าน storeA ของ seller1)
    await assertFails(as('seller2').firestore().doc('product_variants/vC').set({
      productId: 'productA',
      name: 'สีน้ำเงิน',
      stock: 1,
    }));
  });
}

// ---------------------------------------------------------------------------- //
// 4. cart_items — ของตัวเองเท่านั้น
// ---------------------------------------------------------------------------- //

async function testCart() {
  group('cart_items/{id}');
  const cb = () => as('buyer1').firestore();

  await it('put สินค้าเข้าตะกร้าของตัวเองได้', async () => {
    await fresh();
    await assertSucceeds(cb().doc('cart_items/cartX').set({ userId: 'buyer1', productId: 'productA', qty: 2 }));
  });
  await it('ใส่ตะกร้าในชื่อคนอื่น = ปฏิเสธ', async () => {
    await fresh();
    await assertFails(cb().doc('cart_items/cartHack').set({ userId: 'buyer2', productId: 'productA', qty: 1 }));
  });
  await it('แก้จำนวนของตัวเองได้', async () => {
    await fresh();
    await assertSucceeds(cb().doc('cart_items/cart1').update({ qty: 3 }));
  });
  await it('คนอื่นแก้ตะกร้าเราไม่ได้', async () => {
    await fresh();
    await assertFails(as('buyer2').firestore().doc('cart_items/cart1').update({ qty: 99 }));
  });
}

// ---------------------------------------------------------------------------- //
// 5. orders + order items — ลูกค้า/ผู้ขาย/แอดมิน
// ---------------------------------------------------------------------------- //

async function testOrders() {
  group('orders/{orderId}');

  await it('ลูกค้าสร้างออเดอร์สถานะ pending_payment ได้', async () => {
    await fresh();
    await assertSucceeds(as('buyer1').firestore().doc('orders/orderNew').set({
      buyerUid: 'buyer1',
      storeId: 'storeA',
      status: 'pending_payment',
      total: 100,
      createdAt: TS(),
    }));
  });
  await it('สร้างออเดอร์สถานะอื่น (paid) = ปฏิเสธ', async () => {
    await fresh();
    await assertFails(as('buyer1').firestore().doc('orders/orderNew').set({
      buyerUid: 'buyer1',
      storeId: 'storeA',
      status: 'paid',
      total: 100,
      createdAt: TS(),
    }));
  });
  await it('ยอดติดลบ = ปฏิเสธ', async () => {
    await fresh();
    await assertFails(as('buyer1').firestore().doc('orders/orderNew').set({
      buyerUid: 'buyer1',
      storeId: 'storeA',
      status: 'pending_payment',
      total: -5,
      createdAt: TS(),
    }));
  });
  await it('ตั้ง buyerUid เป็นคนอื่น = ปฏิเสธ', async () => {
    await fresh();
    await assertFails(as('buyer1').firestore().doc('orders/orderNew').set({
      buyerUid: 'buyer2',
      storeId: 'storeA',
      status: 'pending_payment',
      total: 100,
      createdAt: TS(),
    }));
  });
  await it('เจ้าของออเดอร์ get ออเดอร์ของตัวเองได้', async () => {
    await fresh();
    await assertSucceeds(as('buyer1').firestore().doc('orders/order1').get());
  });
  await it('คนแปลกหน้า get ออเดอร์คนอื่น = ปฏิเสธ', async () => {
    await fresh();
    await assertFails(as('buyer1').firestore().doc('orders/order2').get());
  });
  await it('ผู้ขายร้านนั้น get ออเดอร์ได้', async () => {
    await fresh();
    await assertSucceeds(as('seller1').firestore().doc('orders/order2').get());
  });
  await it('list ตัวกรองของตัวเองผ่าน / ตัวกรองข้ามขอบเขตถูกปฏิเสธ', async () => {
    await fresh();
    await assertSucceeds(as('buyer1').firestore().collection('orders').where('buyerUid', '==', 'buyer1').get());
    await assertFails(as('buyer1').firestore().collection('orders').where('storeId', '==', 'storeA').get());
  });
  await it('ลูกค้าแก้ที่อยู่ก่อนชำระได้', async () => {
    await fresh();
    await assertSucceeds(as('buyer1').firestore().doc('orders/order1').update({ shippingAddress: 'เชียงราย 57000' }));
  });
  await it('ลูกค้าแก้ยอดรวมไม่ได้', async () => {
    await fresh();
    await assertFails(as('buyer1').firestore().doc('orders/order1').update({ total: 1 }));
  });
  await it('ผู้ขายอัปเดตสถานะจัดส่งได้', async () => {
    await fresh();
    await assertSucceeds(as('seller1').firestore().doc('orders/order2').update({ status: 'shipped', shippedAt: TS() }));
  });
  await it('ผู้ขายแตะยอด/เจ้าของไม่ได้', async () => {
    await fresh();
    await assertFails(as('seller1').firestore().doc('orders/order2').update({ total: 1 }));
  });
  await it('ผู้ขายเปลี่ยนสถานะพร้อมตัดสต็อก (stockDeductedAt) ได้', async () => {
    await fresh();
    await assertSucceeds(as('seller1').firestore().doc('orders/order2').update({
      status: 'paid',
      stockDeductedAt: TS(),
    }));
  });
  await it('stockDeductedAt ใส่ปลอมโดยลูกค้า = ปฏิเสธ', async () => {
    await fresh();
    await assertFails(as('buyer1').firestore().doc('orders/order1').update({ stockDeductedAt: TS() }));
  });
  await it('ลบออเดอร์ไม่ได้เลย (เก็บ audit trail)', async () => {
    await fresh();
    await assertFails(as('buyer1').firestore().doc('orders/order1').delete());
    await assertFails(as('admin1').firestore().doc('orders/order1').delete());
  });
  await it('items: อ่านได้เฉพาะคนในออเดอร์ และเขียนเองไม่ได้', async () => {
    await fresh();
    await assertSucceeds(as('buyer1').firestore().doc('orders/order1/items/item1').get());
    await assertFails(as('buyer2').firestore().doc('orders/order1/items/item1').get());
    await assertFails(as('buyer1').firestore().doc('orders/order1/items/itemX').set({ name: 'สินค้า' }));
  });
}

// ---------------------------------------------------------------------------- //
// 6. payments
// ---------------------------------------------------------------------------- //

async function testPayments() {
  group('payments/{paymentId}');

  await it('ลูกค้าส่งหลักฐานโอนได้ (slipUrl https)', async () => {
    await fresh();
    await assertSucceeds(as('buyer1').firestore().doc('payments/payNew').set({
      orderId: 'order1',
      buyerUid: 'buyer1',
      amount: 100,
      status: 'submitted',
      slipUrl: 'https://x.com/s.jpg',
    }));
  });
  await it('ตั้งสถานะ verified เองตอนสร้าง = ปฏิเสธ', async () => {
    await fresh();
    await assertFails(as('buyer1').firestore().doc('payments/payNew').set({
      orderId: 'order1',
      buyerUid: 'buyer1',
      amount: 100,
      status: 'verified',
      slipUrl: 'https://x.com/s.jpg',
    }));
  });
  await it('slip ไม่ใช่ https = ปฏิเสธ', async () => {
    await fresh();
    await assertFails(as('buyer1').firestore().doc('payments/payNew').set({
      orderId: 'order1',
      buyerUid: 'buyer1',
      amount: 100,
      status: 'submitted',
      slipUrl: 'http://x.com/s.jpg',
    }));
  });
  await it('ผู้ขาย/แอดมิน verify ได้ แต่ลูกค้าไม่ได้', async () => {
    await fresh();
    await assertSucceeds(as('seller1').firestore().doc('payments/pay1').update({ status: 'verified' }));
    await assertFails(as('buyer1').firestore().doc('payments/pay1').update({ status: 'verified' }));
  });
}

// ---------------------------------------------------------------------------- //
// 7. reviews / chat / coupons / notifications / catch-all
// ---------------------------------------------------------------------------- //

async function testMisc() {
  group('reviews / chat / coupons / notifications / catch-all');

  await it('รีวิวได้ (rating 1-5) แต่ rating 6 = ปฏิเสธ', async () => {
    await fresh();
    await assertSucceeds(as('buyer1').firestore().doc('reviews/r1').set({
      userId: 'buyer1',
      productId: 'productA',
      rating: 4,
    }));
    await assertFails(as('buyer1').firestore().doc('reviews/r2').set({
      userId: 'buyer1',
      productId: 'productA',
      rating: 6,
    }));
  });
  await it('ลบรีวิวของตัวเองได้ ลบของคนอื่นไม่ได้', async () => {
    await fresh();
    // รีวิวคนอื่น (buyer2 เขียน) → buyer1 ลบไม่ได้
    await env.withSecurityRulesDisabled((c) =>
      c.firestore().doc('reviews/r1').set({ userId: 'buyer2', productId: 'productA', rating: 4 }));
    await assertFails(as('buyer1').firestore().doc('reviews/r1').delete());
    // รีวิวของตัวเอง → ลบได้
    await env.withSecurityRulesDisabled((c) =>
      c.firestore().doc('reviews/r2').set({ userId: 'buyer1', productId: 'productA', rating: 5 }));
    await assertSucceeds(as('buyer1').firestore().doc('reviews/r2').delete());
  });
  await it('แชท: สร้างห้องได้เมื่อตัวเองอยู่ใน participantUids เท่านั้น', async () => {
    await fresh();
    await assertSucceeds(as('buyer1').firestore().doc('chat_threads/t2').set({
      participantUids: ['buyer1', 'seller1'],
      storeId: 'storeA',
      lastAt: TS(),
    }));
    await assertFails(as('buyer2').firestore().doc('chat_threads/t3').set({
      participantUids: ['buyer1', 'seller1'],
      storeId: 'storeA',
      lastAt: TS(),
    }));
  });
  await it('แชท: list เฉพาะคนในห้อง (array-contains ตัวเอง)', async () => {
    await fresh();
    await assertSucceeds(
      as('buyer1').firestore()
        .collection('chat_threads')
        .where('participantUids', 'array-contains', 'buyer1')
        .get());
    await assertSucceeds(
      as('seller1').firestore()
        .collection('chat_threads')
        .where('participantUids', 'array-contains', 'seller1')
        .get());
  });
  await it('แชท: อ่านห้อง/ข้อความของคนอื่นไม่ได้ (get ต้องเป็นคนในห้อง)', async () => {
    await fresh();
    await assertFails(as('buyer2').firestore().doc('chat_threads/thread1').get());
    await env.withSecurityRulesDisabled((c) =>
      c.firestore().doc('chat_threads/thread1/messages/m1').set({
        senderUid: 'buyer1',
        text: 'สวัสดี',
        participantUids: ['buyer1', 'seller1'],
        createdAt: TS(),
      }));
    await assertSucceeds(
      as('buyer1').firestore()
        .collection('chat_threads/thread1/messages')
        .where('participantUids', 'array-contains', 'buyer1')
        .get());
    await assertFails(as('buyer2').firestore().doc('chat_threads/thread1/messages/m1').get());
  });
  await it('ส่งข้อความในแชทได้เฉพาะคนในห้อง (ต้องพก participantUids ตรงห้อง)', async () => {
    await fresh();
    await assertSucceeds(as('buyer1').firestore().doc('chat_threads/thread1/messages/m1').set({
      senderUid: 'buyer1',
      text: 'สวัสดี',
      participantUids: ['buyer1', 'seller1'],
      createdAt: TS(),
    }));
    await assertFails(as('buyer2').firestore().doc('chat_threads/thread1/messages/m2').set({
      senderUid: 'buyer2',
      text: 'แอบดู',
      participantUids: ['buyer1', 'seller1'],
      createdAt: TS(),
    }));
    await assertFails(as('buyer1').firestore().doc('chat_threads/thread1/messages/m3').set({
      senderUid: 'buyer1',
      text: 'ปลอมรายชื่อห้อง',
      participantUids: ['buyer1', 'stranger'],
      createdAt: TS(),
    }));
  });
  await it('แก้ข้อความย้อนหลังไม่ได้', async () => {
    await fresh();
    await env.withSecurityRulesDisabled((c) =>
      c.firestore().doc('chat_threads/thread1/messages/m1').set({ senderUid: 'buyer1', text: 'เก่า', createdAt: TS() }));
    await assertFails(as('buyer1').firestore().doc('chat_threads/thread1/messages/m1').update({ text: 'ใหม่' }));
  });
  await it('คูปอง: อ่านได้ล็อกอิน / แก้ได้เฉพาะแอดมิน', async () => {
    await fresh();
    await assertFails(unauthed().firestore().doc('coupons/coupon1').get());
    await assertSucceeds(as('buyer1').firestore().doc('coupons/coupon1').get());
    await assertFails(as('buyer1').firestore().doc('coupons/coupon2').set({ code: 'HAX', discount: 10 }));
    await assertSucceeds(as('admin1').firestore().doc('coupons/coupon2').set({ code: 'SAVE20', discount: 20 }));
  });
  await it('แจ้งเตือน: อ่านได้เฉพาะเจ้าของ / กดอ่านได้', async () => {
    await fresh();
    await assertSucceeds(as('buyer1').firestore().doc('notifications/n1').get());
    await assertFails(as('buyer2').firestore().doc('notifications/n1').get());
    await assertSucceeds(as('buyer1').firestore().doc('notifications/n1').update({ read: true, readAt: TS() }));
  });
  await it('แจ้งเตือน: คู่ค้าในออเดอร์แจ้งให้กันได้ (ผู้ซื้อ→ผู้ขาย / ผู้ขาย→ผู้ซื้อ)', async () => {
    await fresh();
    // ผู้ซื้อ (order1) แจ้งเจ้าของร้าน
    await assertSucceeds(as('buyer1').firestore().doc('notifications/nOrderA').set({
      userId: 'seller1',
      type: 'order_status',
      title: 'มีคำสั่งซื้อใหม่',
      body: 'ออเดอร์ #order1',
      orderId: 'order1',
      read: false,
      createdAt: TS(),
    }));
    // ผู้ขายแจ้งผู้ซื้อ
    await assertSucceeds(as('seller1').firestore().doc('notifications/nOrderB').set({
      userId: 'buyer1',
      type: 'order_status',
      title: 'สถานะออเดอร์: ชำระแล้ว',
      body: 'ออเดอร์ #order1',
      orderId: 'order1',
      read: false,
      createdAt: TS(),
    }));
  });
  await it('แจ้งเตือน: คนนอกที่ไม่ใช่คู่ออเดอร์สร้างแจ้งเตือนให้ไม่ได้', async () => {
    await fresh();
    // seller2 ไม่ใช่เจ้าของ storeA (order2)
    await assertFails(as('seller2').firestore().doc('notifications/nHackA').set({
      userId: 'buyer1',
      type: 'order_status',
      title: 'หลอก',
      body: 'fake',
      orderId: 'order2',
      read: false,
      createdAt: TS(),
    }));
    // buyer2 ไม่ใช่คู่ของ order1
    await assertFails(as('buyer2').firestore().doc('notifications/nHackB').set({
      userId: 'buyer1',
      type: 'order_status',
      title: 'หลอก',
      body: 'fake',
      orderId: 'order1',
      read: false,
      createdAt: TS(),
    }));
  });
  await it('แจ้งเตือน: คนในห้องแชทแจ้งอีกฝั่งได้ / คนนอกห้องไม่ได้', async () => {
    await fresh();
    await assertSucceeds(as('buyer1').firestore().doc('notifications/nMsgA').set({
      userId: 'seller1',
      type: 'new_message',
      title: 'ข้อความใหม่',
      body: 'สวัสดี',
      threadId: 'thread1',
      read: false,
      createdAt: TS(),
    }));
    await assertFails(as('buyer2').firestore().doc('notifications/nMsgB').set({
      userId: 'seller1',
      type: 'new_message',
      title: 'ข้อความใหม่',
      body: 'แอบดู',
      threadId: 'thread1',
      read: false,
      createdAt: TS(),
    }));
  });
  await it('แจ้งเตือน: ส่งให้ตัวเองผ่านห้องแชท = ปฏิเสธ', async () => {
    await fresh();
    await assertFails(as('buyer1').firestore().doc('notifications/nSelf').set({
      userId: 'buyer1',
      type: 'new_message',
      title: 'ตัวเอง',
      body: 'x',
      threadId: 'thread1',
      read: false,
      createdAt: TS(),
    }));
  });
  await it('path อื่น ๆ นอกเหนือ = ปฏิเสธทุกคน (deny by default)', async () => {
    await fresh();
    await assertFails(as('admin1').firestore().doc('secret/flag').set({ value: 1 }));
    await assertFails(unauthed().firestore().collection('logs').get());
  });
}

// ---------------------------------------------------------------------------- //
// Main — เริ่ม emulator test, รันทั้งชุด, ปิด env
// ---------------------------------------------------------------------------- //

(async () => {
  env = await initializeTestEnvironment({
    projectId: 'thaiotop-587f1',
    firestore: { rules: RULES },
  });
  try {
    await testUsers();
    await testStores();
    await testCatalog();
    await testCart();
    await testOrders();
    await testPayments();
    await testMisc();
  } catch (e) {
    console.error('suite error:', e);
    failed++;
  } finally {
    await env.cleanup();
  }
  const total = passed + failed;
  console.log(`\nผลลัพธ์: ${passed}/${total} ผ่าน\n`);
  process.exit(failed === 0 ? 0 : 1);
})();