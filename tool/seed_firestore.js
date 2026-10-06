'use strict';
/**
 * Seed ข้อมูลตั้งต้นลง Firestore ผ่าน Admin API
 *
 * ข้อมูลทุกชิ้นถูกออกแบบให้ตรงกับ firestore.rules ที่ deploy ไปแล้ว
 * (ชื่อ field ต้องตรงทุกตัว ไม่งั้น Rules จะอ่านไม่ออก)
 *
 * วิธีใช้
 *   1) firebase login                      (ครั้งเดียว)
 *   2) node tool/seed_firestore.js <projectId>
 *   3) firebase deploy --only firestore:rules
 *
 * ทำซ้ำได้ปลอดภัย — ใช้ document id แบบคงที่ ไม่สร้างข้อมูลซ้ำ
 *
 * ⚠️ บัญชีที่สร้างเป็นบัญชีสาธิต มีรหัสผ่านเดียวกันหมด ใช้ล็อกอินได้ทันที
 *    เพื่อสาธิต/ทดสอบเท่านั้น — ถ้าจะเอาโปรเจกต์นี้ไปใช้จริง
 *    ให้ลบบัญชีเหล่านี้ทิ้งก่อน โดยเฉพาะบัญชี admin
 */
const fs = require('fs');
const path = require('path');

// ใช้ OAuth client ของ firebase-tools ซึ่งเป็นค่าสาธารณะในแพ็กเกจ npm
// (ต้องการเพียง refresh_token ของผู้ใช้เอง ไม่ใช่ secret)
const CONFIG = path.join(process.env.USERPROFILE, '.config', 'configstore', 'firebase-tools.json');
const CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';
const PROJECT = process.argv[2] || 'thaiotop-587f1';
const DEMO_PASSWORD = 'OtopDemo123';

// ------------------------------------------------------------------ //
// Firestore value helpers — REST API ต้องห่อค่าแบบ typed
// ------------------------------------------------------------------ //
const S = (v) => ({ stringValue: v });
const N = () => ({ nullValue: null });
const T = (v) => ({ timestampValue: (v instanceof Date ? v : new Date(v)).toISOString() });

function toValue(v) {
  if (v === null || v === undefined) return N();
  if (v instanceof Date) return T(v);
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toValue) } };
  if (typeof v === 'string') return S(v);
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') {
    return Number.isInteger(v)
      ? { integerValue: String(v) }
      : { doubleValue: v };
  }
  const fields = {};
  for (const [k, val] of Object.entries(v)) {
    if (val !== undefined) fields[k] = toValue(val);
  }
  return { mapValue: { fields } };
}

function plain(v) {
  return toValue(v).mapValue.fields;
}

const DAY = 86400000;
const daysAgo = (n) => new Date(Date.now() - n * DAY);

// ------------------------------------------------------------------ //
// Demo accounts — สร้าง Firebase Auth จริง เพื่อให้ล็อกอินได้ทันที
// ------------------------------------------------------------------ //
const USERS = [
  { key: 'sellerNorth',  email: 'seller.north@example.com',  name: 'แม่ชมพร วงศ์ทอง',     phone: '0812345671', province: 'เชียงใหม่',      roles: ['customer', 'seller'] },
  { key: 'sellerCentral',email: 'seller.central@example.com',name: 'ลุงบุญส่ง ศรีสุขใจ',   phone: '0812345672', province: 'สุราษฎร์ธานี',  roles: ['customer', 'seller'] },
  { key: 'sellerSouth',  email: 'seller.south@example.com',  name: 'ป้าสมจิตร์ แก้วงาม',   phone: '0812345673', province: 'นครศรีธรรมราช', roles: ['customer', 'seller'] },
  { key: 'customer',     email: 'customer@example.com',     name: 'ณัฐวุฒิ วัฒนกิจ',      phone: '0812345674', province: 'กรุงเทพมหานคร',  roles: ['customer'] },
  { key: 'admin',        email: 'admin@example.com',         name: 'ผู้ดูแลระบบ',          phone: '0812345675', province: 'กรุงเทพมหานคร',  roles: ['customer', 'admin'] },
];

const CATEGORIES = [
  { id: 'handicraft', name: 'หัตถกรรม',                 slug: 'handicraft',  icon: '🎨', sortOrder: 1 },
  { id: 'food',       name: 'อาหารและขนมไทย',           slug: 'food',        icon: '🍜', sortOrder: 2 },
  { id: 'coffee',     name: 'กาแฟและชา',                slug: 'coffee',      icon: '☕', sortOrder: 3 },
  { id: 'fashion',    name: 'เสื้อผ้าแฟชั่น',            slug: 'fashion',     icon: '👗', sortOrder: 4 },
  { id: 'homeDecor',  name: 'ของตกแต่งบ้าน',            slug: 'home-decor',  icon: '🏠', sortOrder: 5 },
  { id: 'agriculture',name: 'สินค้าเกษตร',               slug: 'agriculture', icon: '🌾', sortOrder: 6 },
  { id: 'health',     name: 'สมุนไพรและสุขภาพ',         slug: 'health',      icon: '🌿', sortOrder: 7 },
  { id: 'cosmetics',  name: 'เครื่องสำอางธรรมชาติ',      slug: 'cosmetics',   icon: '🧴', sortOrder: 8 },
  { id: 'jewelry',    name: 'เครื่องประดับ',             slug: 'jewelry',     icon: '💍', sortOrder: 9 },
  { id: 'gifts',      name: 'ของขวัญและของที่ระลึก',     slug: 'gifts',       icon: '🎁', sortOrder: 10 },
];

const img = (seed) => `https://picsum.photos/seed/otop-${seed}/900/900`;

const STORES = [
  {
    id: 'store-singthai', ownerKey: 'sellerNorth',
    name: 'ชิงไทย ผ้าไหมและของดีล้านนา',
    province: 'เชียงใหม่', region: 'north', community: 'บ้านปางลาง',
    description: 'ชุมชนบ้านปางลาง อำเภอแม่ริม ผลิตผ้าไหมลายมือ ย้อมสีธรรมชาติ และกาแฟเขาสูงคั่วไม้ ทอมือทุกผืน',
    otopCertified: true, commissionRate: 0.08, ratingAvg: 4.8, ratingCount: 214,
  },
  {
    id: 'store-sawatdee', ownerKey: 'sellerCentral',
    name: 'สวัสดี ขนมไทยโบราณ',
    province: 'สุราษฎร์ธานี', region: 'central', community: 'ตลาดสดสุราษฎร์ธานี',
    description: 'ร้านในตลาดสด ทำขนมไทยโบราณสูตรโบราณ ขายสดทุกวัน และทำชุดของขวัญให้ตั้งแต่ปี 2538',
    otopCertified: true, commissionRate: 0.06, ratingAvg: 4.7, ratingCount: 1876,
  },
  {
    id: 'store-tanwa', ownerKey: 'sellerSouth',
    name: 'ตำรับ อาหารปักษ์ใต้',
    province: 'นครศรีธรรมราช', region: 'south', community: 'ตลาดใหญ่นครศรีธรรมราช',
    description: 'สายตระกูลแก้วงาม ทำน้ำปลาสูตรโบราณหมักถังไม้ 2 ปี และอาหารปักษ์ใต้สด ไม่ใส่สารกันเสีย',
    otopCertified: true, commissionRate: 0.07, ratingAvg: 4.6, ratingCount: 943,
  },
];

// story = เรื่องราวสินค้า (ฟีเจอร์หัวใจของโปรเจกต์ ต้องมีของจริง)
const PRODUCTS = [
  {
    id: 'p-silk-scarf-red', storeId: 'store-singthai', categoryId: 'fashion',
    name: 'ผ้าไหมแดงลายไทย', price: 1290, stockTotal: 24, soldCount: 342,
    ratingAvg: 4.9, ratingCount: 168, days: 45,
    description: 'ผ้าไหมแท้ 100% ย้อมสีแดงจากรากมะม่วง ลายไทยทอมือ ใช้ได้ทั้งชุดลำลองและผ้าคลุมไหล่',
    story: {
      community: 'บ้านปางลาง อำเภอแม่ริม จังหวัดเชียงใหม่',
      ingredients: 'ไหมแท้ ไหมฟอร์สอิล สีย้อมจากรากมะม่วง หมาก คุมะ',
      productionMethod: 'ปั่นเยื่อไหมเอง ย้อมแบบจากยอก ทอมือบนกี่พื้นด้วยมือคนละเส้น',
      uniqueness: 'ถ้าลอกลายมาไม่ได้ เพราะลายถอดจากการวางเส้นจริงของผู้ทอ ไม่ใช่การพิมพ์',
    },
  },
  {
    id: 'p-silk-scarf-gold', storeId: 'store-singthai', categoryId: 'fashion',
    name: 'ผ้าไหมสีทอง ลายนกฉลาม', price: 1490, stockTotal: 12, soldCount: 187,
    ratingAvg: 4.8, ratingCount: 96, days: 38,
    description: 'ผ้าไหมสีทองผสมเส้นเงิน ลายนกฉลามโบราณ ทอมือยาว 2 เมตร',
    story: {
      community: 'บ้านปางลาง อำเภอแม่ริม จังหวัดเชียงใหม่',
      ingredients: 'ไหมแท้ เส้นเงินเบอร์มิ สีทองจากเปลือกหอก',
      productionMethod: 'ทอมือ 3 วันต่อผืน ใช้กี่พื้นเดิมของชุมชน',
      uniqueness: 'ลายนกฉลามเป็นลายเฉพาะของชุมชน ถ้าซื้อจากร้านอื่นจะไม่เหมือน',
    },
  },
  {
    id: 'p-thai-linen', storeId: 'store-singthai', categoryId: 'homeDecor',
    name: 'ผ้าลินินไทยลายจก', price: 890, stockTotal: 30, soldCount: 96,
    ratingAvg: 4.7, ratingCount: 54, days: 30,
    description: 'ผ้าลินินไทยถักมือ ลายจกสี่ทิศ หนา ทน ดูดความชื้นได้ดี เหมาะใช้เป็นผ้ารองจานหรือผ้าปูโต๊ะ',
    story: {
      community: 'บ้านปางลาง อำเภอแม่ริม จังหวัดเชียงใหม่',
      ingredients: 'เยื่อลินินธรรมชาติจากป่าเขาหลวง ปมฝ้ายย้อมสี',
      productionMethod: 'ถักมือด้วยกี่ไม้แบบเดิมของชุมชน',
      uniqueness: 'ลายจกสี่ทิศต้องวางมือซ้ายขวาด้วยจังหวะเดียวกัน มือใหม่ทอไม่ได้ใน 3 เดือน',
    },
  },
  {
    id: 'p-arabica-250', storeId: 'store-singthai', categoryId: 'coffee',
    name: 'กาแฟอาราบิก้าดอย 250 กรัม', price: 420, stockTotal: 80, soldCount: 1204,
    ratingAvg: 4.9, ratingCount: 623, days: 25,
    description: 'เมล็ดกาแฟอาราบิก้าพันธุ์เดิม คั่วกลาง เหมาะทั้งเครื่องกรองและเอสเปรสโซ่',
    story: {
      community: 'บ้านมะขามหวาน อำเภอดอยสะเก็ด จังหวัดเชียงใหม่',
      ingredients: 'เมล็ดกาแฟอาราบิก้าพันธุ์คาติมอร์ ปลูกที่ความสูง 1,400 เมตร',
      productionMethod: 'เก็บมือเฉพาะผลสุก แล้วคั่วบนเตาไม้ ปรับความร้อนด้วยมือ',
      uniqueness: 'คั่วด้วยไม้จากชุมชน จึงมีกลิ่นไม้หอมติดมากว่ากาแฟที่คั่วด้วยแก๊ส',
    },
  },
  {
    id: 'p-arabica-1kg', storeId: 'store-singthai', categoryId: 'coffee',
    name: 'กาแฟอาราบิก้าดอย 1 กิโลกรัม (คั่วตอนสั่งซื้อ)', price: 1450, stockTotal: 40, soldCount: 587,
    ratingAvg: 4.8, ratingCount: 341, days: 22,
    description: 'ถุงใหญ่สำหรับร้านกาแฟหรือคนที่ดื่มเอง คั่วสดตอนสั่งซื้อ ส่งถึงภายใน 5 วัน',
    story: {
      community: 'บ้านมะขามหวาน อำเภอดอยสะเก็ด จังหวัดเชียงใหม่',
      ingredients: 'เมล็ดกาแฟอาราบิก้าคั่วกลาง เก็บสดรอบคั่ว',
      productionMethod: 'คั่วสดหลังยืนยันออเดอร์ ส่งทันทีในวันถัดจากคั่ว',
      uniqueness: 'ไม่เก็บสต็อกคั่วไว้ล่วงหน้า จึงได้ความสดที่กาแฟสูตรรี้ทำไม่ได้',
    },
  },
  {
    id: 'p-cold-brew', storeId: 'store-singthai', categoryId: 'coffee',
    name: 'กาแฟสกัดเย็น 250 มล. (ขวดแก้ว)', price: 120, stockTotal: 150, soldCount: 2088,
    ratingAvg: 4.6, ratingCount: 912, days: 20,
    description: 'สกัดเย็นนาน 18 ชั่วโมง ไม่ใส่น้ำตาล ไม่ใส่สารอย่างอื่น ปิดแก้วและส่งเย็น',
    story: {
      community: 'บ้านมะขามหวาน อำเภอดอยสะเก็ด จังหวัดเชียงใหม่',
      ingredients: 'น้ำกรอง กาแฟอาราบิก้าดอย',
      productionMethod: 'สกัดเย็น 18 ชั่วโมง เก็บในตู้เย็น 4 องศา',
      uniqueness: 'สกัดนานกว่าปกติถึงสามเท่า ได้รสที่หวานกลมกลืนโดยไม่ต้องใส่น้ำตาล',
    },
  },
  {
    id: 'p-khanom-thai', storeId: 'store-sawatdee', categoryId: 'food',
    name: 'ขนมไทยชุดรับเยี่ยม 6 ชนิด', price: 380, stockTotal: 60, soldCount: 1420,
    ratingAvg: 4.7, ratingCount: 688, days: 18,
    description: 'ขนมชั้น ทองหยิบฝอย ชั้นเขียว วุ้นกะทิ ขนมเบื้องญวน และขนมใส่ไส้ บรรจุกล่องของขวัญ',
    story: {
      community: 'ตลาดสดสุราษฎร์ธานี อำเภอเมือง จังหวัดสุราษฎร์ธานี',
      ingredients: 'แป้งถั่วตัด น้ำตาลปี๊บ กะทิสด ไข่ไก่จากฟาร์มใกล้บ้าน',
      productionMethod: 'นึ่งสดทุกวันตอนตีสี่ ไม่ใช้สารกันเสีย',
      uniqueness: 'ทองหยิบฝอยต้องเทใสถ้วย ไม่ใช่เทสีเหลือง เป็นวิธีตรวจง่ายที่สุด',
    },
  },
  {
    id: 'p-palm-sugar', storeId: 'store-sawatdee', categoryId: 'food',
    name: 'น้ำตาลปี๊บธรรมชาติ 1 กก.', price: 150, stockTotal: 200, soldCount: 2230,
    ratingAvg: 4.8, ratingCount: 1104, days: 16,
    description: 'น้ำตาลปี๊บจากอ้อดอ ต้มแบบโบราณ ไม่ใส่สี ไม่ใส่กลิ่น ใช้แทนน้ำตาลขาวได้เลย',
    story: {
      community: 'หมู่บ้านเกาะเปริด อำเภอสิงหนคร จังหวัดสุราษฎร์ธานี',
      ingredients: 'น้ำอ้อดอ ต้มคั่วบนกระทะเบ้าด้วยไฟฟืน',
      productionMethod: 'ต้มและคั่วด้วยไฟฟืน ใช้เวลานานกว่าน้ำตาลขาว 3 เท่า',
      uniqueness: 'มีกลิ่นอ้อและกลิ่นไม้จากความร้อนที่ใช้คั่ว รสต่างจากน้ำตาลปี๊บอุตสาหกรรมชัดเจน',
    },
  },
  {
    id: 'p-rice-barn', storeId: 'store-sawatdee', categoryId: 'agriculture',
    name: 'ข้าวกำเนิดภาคเหนือ 5 กก.', price: 350, stockTotal: 45, soldCount: 763,
    ratingAvg: 4.6, ratingCount: 298, days: 12,
    description: 'ข้าวหอมมะลิไทย ปลูกแบบอินทรีย์ ไม่ใช้สารเคมี บดใหม่ทุกเดือน',
    story: {
      community: 'หมู่บ้านแพร่ อำเภอปางมะผ้า จังหวัดแม่ฮ่องสอน',
      ingredients: 'ข้าวพันธุ์พื้นเมือง ปุ๋ยหมักชีวภาพ',
      productionMethod: 'ปลูกแบบอินทรีย์ ตีนนาน้ำ ใช้ปุ๋ยหมักจากฟางข้าวในนา',
      uniqueness: 'ชื่อพันธุ์เดียวกันนี้ถูกเลือกมาจากนาเก่าแปลงนา ไม่ใช่พันธุ์สายพันธุ์',
    },
  },
  {
    id: 'p-fishsauce', storeId: 'store-tanwa', categoryId: 'food',
    name: 'น้ำปลาตั้งสูตร 700 มล.', price: 290, stockTotal: 90, soldCount: 3410,
    ratingAvg: 4.7, ratingCount: 1533, days: 10,
    description: 'น้ำปลาแท้ตั้งสูตร หมักถังไม้โอ๊คนาน 2 ปี เข้ม หอม ใส่ได้ทั้งทอดและน้ำยำ',
    story: {
      community: 'ตลาดใหญ่นครศรีธรรมราช อำเภอเมือง จังหวัดนครศรีธรรมราช',
      ingredients: 'ปลาแก้วงามสด ตากแดด 5 แดด เกลือหิมะ',
      productionMethod: 'หมักถังไม้โอ๊ค 2 ปี ตรวจความเค็มทุก 3 เดือน',
      uniqueness: 'หมักถังไม้ ไม่ใช่ถังสแตนเลส จึงได้สีเข้มกว่าและมีรสกลมกลืน',
    },
  },
  {
    id: 'p-seaweed-capsule', storeId: 'store-tanwa', categoryId: 'health',
    name: 'สมุนไพรแก้ปวดเมื่อย แคปซูล 60 เม็ด', price: 480, stockTotal: 70, soldCount: 1877,
    ratingAvg: 4.4, ratingCount: 642, days: 8,
    description: 'สมุนไพรรวม 7 ชนิด สกัดเข้มข้น ไม่ใส่สี ไม่ใส่สารกันเสีย ผลิตในไทย ขึ้นทะเบียน อย.9',
    story: {
      community: 'ตลาดใหญ่นครศรีธรรมราช อำเภอเมือง จังหวัดนครศรีธรรมราช',
      ingredients: 'สมุนไพรท้องถิ่น 7 ชนิด เช่น หมามุ่ย กระวาน ปัญจนครี',
      productionMethod: 'สกัดแบบไอน้ำที่อุณหภูมิต่ำ เพื่อรักษาสารออกฤทธิ์',
      uniqueness: 'ใช้สมุนไพรจากบ้านสวนตัวเองทุกชนิด ไม่ใช้ผงสกัดนำเข้า',
    },
  },
];

const VARIANTS = [
  { id: 'p-silk-scarf-red-v1',  productId: 'p-silk-scarf-red',  name: 'สีแดง',  options: { color: 'แดง',  size: null }, priceDelta: 0,    stock: 14, days: 45 },
  { id: 'p-silk-scarf-red-v2',  productId: 'p-silk-scarf-red',  name: 'สีทอง',  options: { color: 'ทอง',  size: null }, priceDelta: 200,  stock: 10, days: 45 },
  { id: 'p-thai-linen-v1',      productId: 'p-thai-linen',      name: 'ผ้ารองจาน 45x30 ซม.', options: { color: null, size: '45x30' }, priceDelta: 0,  stock: 18, days: 30 },
  { id: 'p-thai-linen-v2',      productId: 'p-thai-linen',      name: 'ผ้าปูโต๊ะ 150x50 ซม.', options: { color: null, size: '150x50' }, priceDelta: 350, stock: 12, days: 30 },
  { id: 'p-arabica-250-v1',     productId: 'p-arabica-250',     name: 'คั่วกลาง',        options: { color: null, size: '250 กรัม' }, priceDelta: 0,   stock: 50, days: 25 },
  { id: 'p-arabica-250-v2',     productId: 'p-arabica-250',     name: 'คั่วเข้ม',        options: { color: null, size: '250 กรัม' }, priceDelta: 30,  stock: 30, days: 25 },
  { id: 'p-khanom-thai-v1',    productId: 'p-khanom-thai',    name: 'ชุด 6 ชนิด',       options: { color: null, size: 'ชุด' },      priceDelta: 0,    stock: 60, days: 18 },
  { id: 'p-seaweed-capsule-v1', productId: 'p-seaweed-capsule', name: 'กล่อง 1 เดือน',  options: { color: null, size: '60 เม็ด' }, priceDelta: 0,    stock: 45, days: 8 },
  { id: 'p-seaweed-capsule-v2', productId: 'p-seaweed-capsule', name: 'กล่อง 3 เดือน',  options: { color: null, size: '180 เม็ด' }, priceDelta: 620, stock: 25, days: 8 },
];

// ------------------------------------------------------------------ //
// Demo orders — ให้หน้าประวัติ/สถานะมีข้อมูลให้ดูทุกสถานะ (เขียนผ่าน
// Admin API ซึ่งข้าม firestore.rules ได้ เพราะลูกค้าทั่วไปจะสร้างแค่
// status == 'pending_payment' เท่านั้น)
// ------------------------------------------------------------------ //
const ORDERS = [
  {
    id: 'o-demo-1', storeId: 'store-singthai', method: 'promptpay',
    status: 'completed', paymentStatus: 'verified', days: 30,
    shippedAt: daysAgo(24), tracking: 'TH2219067845123',
    items: [
      { productId: 'p-silk-scarf-red', name: 'ผ้าไหมแดงลายไทย', price: 1290, quantity: 1 },
      { productId: 'p-thai-linen', name: 'ผ้าลินินไทยลายจก', price: 890, quantity: 1 },
    ],
  },
  {
    id: 'o-demo-2', storeId: 'store-singthai', method: 'bank_transfer',
    status: 'shipped', paymentStatus: 'verified', days: 20,
    shippedAt: daysAgo(8), tracking: 'TH2219067891234',
    items: [
      { productId: 'p-arabica-1kg', name: 'กาแฟอาราบิก้าดอย 1 กิโลกรัม (คั่วตอนสั่งซื้อ)', price: 1450, quantity: 1 },
    ],
  },
  {
    id: 'o-demo-3', storeId: 'store-singthai', method: 'promptpay',
    status: 'awaiting_shipment', paymentStatus: 'verified', days: 12,
    items: [
      { productId: 'p-arabica-250', name: 'กาแฟอาราบิก้าดอย 250 กรัม', price: 420, quantity: 2 },
    ],
  },
  {
    id: 'o-demo-4', storeId: 'store-sawatdee', method: 'promptpay',
    status: 'paid', paymentStatus: 'awaiting_transfer', days: 6,
    items: [
      { productId: 'p-khanom-thai', name: 'ขนมไทยชุดรับเยี่ยม 6 ชนิด', price: 380, quantity: 2 },
    ],
  },
  {
    id: 'o-demo-5', storeId: 'store-singthai', method: 'promptpay',
    status: 'pending_payment', paymentStatus: 'awaiting_transfer', days: 2,
    items: [
      { productId: 'p-cold-brew', name: 'กาแฟสกัดเย็น 250 มล. (ขวดแก้ว)', price: 120, quantity: 6 },
    ],
  },
  {
    id: 'o-demo-6', storeId: 'store-tanwa', method: 'promptpay',
    status: 'cancelled', paymentStatus: 'awaiting_transfer', days: 1,
    skipPayment: true,
    items: [
      { productId: 'p-palm-sugar', name: 'น้ำตาลปี๊บธรรมชาติ 1 กก.', price: 150, quantity: 2 },
    ],
  },
];

// ------------------------------------------------------------------ //
// Auth + Firestore helpers
// ------------------------------------------------------------------ //
async function getToken(tokens) {
  if (tokens.access_token && tokens.expires_at > Date.now() + 60000) return tokens.access_token;
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: CLIENT_ID, client_secret: CLIENT_SECRET,
      refresh_token: tokens.refresh_token, grant_type: 'refresh_token',
    }),
  });
  const j = await res.json();
  if (!j.access_token) throw new Error('token refresh failed: ' + j.error);
  return j.access_token;
}

async function api(url, token, init, what) {
  const res = await fetch(url, { ...init, headers: { ...(init && init.headers), Authorization: `Bearer ${token}` } });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch (_) { /* non-JSON */ }
  if (!res.ok) {
    throw new Error(`${what} failed (${res.status}): ${json && json.error ? json.error.message : text.slice(0, 200)}`);
  }
  return json;
}

/** สร้างผู้ใช้ Auth ถ้ายังไม่มี — คืน uid (localId) */
async function ensureAuthUser(token, user) {
  const idToolkit = `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT}/accounts`;

  const created = await fetch(idToolkit, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: user.email,
      password: DEMO_PASSWORD,
      displayName: user.name,
      emailVerified: true,
    }),
  });
  const cj = await created.json();

  if (created.ok) {
    console.log(`  created auth user  ${user.email}  uid=${cj.localId}`);
    return cj.localId;
  }

  // มีอยู่แล้ว → ค้น uid จากอีเมล
  if (created.status === 400 || created.status === 409) {
    const found = await api(`${idToolkit}:lookup`, token, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: [user.email] }),
    }, 'accounts:lookup');

    const u = found.users && found.users[0];
    if (u) {
      // ตั้งรหัสผ่านใหม่ เผื่อที่เคยเขียน seed ไปแล้วแต่รหัสไม่ตรง
      // (fail ได้โดยไม่ทำให้ seed พัง เพราะรหัสอาจถูกต้องอยู่แล้ว)
      try {
        await api(`${idToolkit}:update`, token, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            localId: u.localId,
            email: user.email,
            password: DEMO_PASSWORD,
          }),
        }, 'accounts:update');
      } catch (e) {
        console.log(`  (ข้ามการรีเซ็ตรหัสผ่าน: ${e.message.slice(0, 80)})`);
      }
      console.log(`  exists auth user   ${user.email}  uid=${u.localId}`);
      return u.localId;
    }
  }
  throw new Error(`cannot create/lookup ${user.email}: ${JSON.stringify(cj).slice(0, 200)}`);
}

// ------------------------------------------------------------------ //
// Main
// ------------------------------------------------------------------ //
(async () => {
  const cfg = JSON.parse(fs.readFileSync(CONFIG, 'utf8'));
  const token = await getToken(cfg.tokens || {});

  const docsPath = `projects/${PROJECT}/databases/(default)/documents`;
  const docsBase = `https://firestore.googleapis.com/v1/${docsPath}`;
  const writes = [];
  const add = (collection, id, data) =>
    writes.push({ update: { name: `${docsPath}/${collection}/${id}`, fields: plain(data) } });

  console.log('1) create demo auth users');
  const uids = {};
  for (const u of USERS) uids[u.key] = await ensureAuthUser(token, u);

  console.log('\n2) build documents');

  for (const u of USERS) {
    add('users', uids[u.key], {
      displayName: u.name,
      email: u.email,
      phone: u.phone,
      roles: u.roles,
      province: u.province,
      avatarUrl: null,
      createdAt: daysAgo(60),
    });
  }

  for (const c of CATEGORIES) {
    add('categories', c.id, { ...c, active: true, createdAt: daysAgo(60) });
  }

  for (const s of STORES) {
    add('stores', s.id, {
      storeId: s.id,
      ownerUid: uids[s.ownerKey],
      name: s.name,
      province: s.province,
      region: s.region,
      community: s.community,
      description: s.description,
      coverImageUrl: img(s.id + '-cover'),
      logoUrl: null,
      otopCertified: s.otopCertified,
      ratingAvg: s.ratingAvg,
      ratingCount: s.ratingCount,
      commissionRate: s.commissionRate,
      status: 'active',
      createdAt: daysAgo(55),
    });
  }

  const storeProvince = Object.fromEntries(STORES.map((s) => [s.id, { province: s.province, region: s.region }]));

  for (const p of PRODUCTS) {
    const loc = storeProvince[p.storeId];
    add('products', p.id, {
      storeId: p.storeId,
      name: p.name,
      description: p.description,
      price: p.price,
      categoryId: p.categoryId,
      province: loc.province,
      region: loc.region,
      imageUrls: [img(p.id + '-1'), img(p.id + '-2'), img(p.id + '-3')],
      stockTotal: p.stockTotal,
      status: 'active',
      story: p.story,
      ratingAvg: p.ratingAvg,
      ratingCount: p.ratingCount,
      soldCount: p.soldCount,
      createdAt: daysAgo(p.days),
      updatedAt: daysAgo(Math.max(1, p.days - 5)),
    });
  }

  for (const v of VARIANTS) {
    add('product_variants', v.id, {
      productId: v.productId,
      name: v.name,
      options: v.options,
      priceDelta: v.priceDelta,
      stock: v.stock,
      imageUrl: null,
      createdAt: daysAgo(v.days),
    });
  }

  // ออเดอร์ตัวอย่างของบัญชี demo customer — หลากหลายสถานะเพื่อสาธิตหน้า
  // ประวัติ/ไทม์ไลน์ และปุ่มผู้ขาย (1 ผู้ขาย : 1 ร้านค้า โดย sellerNorth เป็นเจ้าของ store-singthai)
  console.log('\n2.5) demo orders for the demo customer');
  const storeNames = Object.fromEntries(STORES.map((s) => [s.id, s.name]));
  let ordersCount = 0;
  let paymentsCount = 0;
  for (const o of ORDERS) {
    const subtotal = o.items.reduce((s, i) => s + i.price * i.quantity, 0);
    const shipping = subtotal >= 1000 ? 0 : 50;
    const total = subtotal + shipping;
    add('orders', o.id, {
      buyerUid: uids['customer'],
      buyerName: 'ณัฐวุฒิ วัฒนกิจ',
      storeId: o.storeId,
      storeName: storeNames[o.storeId],
      items: o.items.map((i) => ({ ...i })),
      subtotal: subtotal,
      shippingFee: shipping,
      total: total,
      status: o.status,
      paymentMethod: o.method,
      paymentStatus: o.paymentStatus,
      shippingAddress: { full: '99/1 ถนนราชดำริ แขวงลุมพินี เขตปทุมวัน กรุงเทพมหานคร 10330' },
      note: null,
      createdAt: daysAgo(o.days),
      ...(o.shippedAt ? { shippedAt: o.shippedAt, trackingNumber: o.tracking } : {}),
    });
    ordersCount += 1;

    if (o.method !== 'cash_on_delivery' && !o.skipPayment) {
      add('payments', 'pay-' + o.id, {
        orderId: o.id,
        buyerUid: uids['customer'],
        method: o.method,
        amount: total,
        status: o.paymentStatus,
        createdAt: daysAgo(o.days),
        ...(o.paymentStatus === 'verified'
          ? { verifiedAt: daysAgo(Math.max(1, o.days - 1)) }
          : {}),
      });
      paymentsCount += 1;
    }
  }

  console.log('3) batchWrite ' + writes.length + ' documents');
  const res = await api(docsBase + ':batchWrite', token, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ writes }),
  }, 'batchWrite');

  if (res.writeResults && res.writeResults.some((r) => r.updateTime === undefined)) {
    throw new Error('some writes did not return updateTime');
  }

  console.log('\n=== seed complete ===');
  console.log('  users               ' + USERS.length);
  console.log('  categories          ' + CATEGORIES.length);
  console.log('  stores              ' + STORES.length);
  console.log('  products            ' + PRODUCTS.length);
  console.log('  product_variants    ' + VARIANTS.length);
  console.log('  orders              ' + ordersCount);
  console.log('  payments            ' + paymentsCount);
  console.log('\ndemo accounts (password: ' + DEMO_PASSWORD + ')');
  for (const u of USERS) {
    console.log('  ' + u.roles.join('+').padEnd(16) + u.email);
  }
})().catch((e) => { console.error('ERROR: ' + e.message); process.exit(1); });
