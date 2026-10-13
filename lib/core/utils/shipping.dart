/// ค่าจัดส่งแบบเหมาจ่ายตามโมเดลข้อมูลตั้งต้นของแอป
///
/// Lives here rather than in the cart or the order repository because both
/// sides need the same numbers: the cart shows a total before an order exists,
/// and the order repository recomputes the total when writing the document.
/// A second copy of the threshold would eventually disagree with the first and
/// produce orders whose total differs from the checkout the buyer approved.
library;

const double kShippingFee = 50; //เพื่อให้ค่าจัดส่งเป็น 50 บาท

const double kFreeShippingOver = 1000; //เพื่อให้ค่าจัดส่งฟรีเมื่อซื้อสินค้ามากกว่า 1000 บาท

double shippingFeeFor(double subtotal) => //เพื่อให้ค่าจัดส่งเป็น 0 บาทเมื่อซื้อสินค้ามากกว่า 1000 บาท
    (subtotal <= 0 || subtotal >= kFreeShippingOver) ? 0 : kShippingFee;

double totalFor(double subtotal) => subtotal + shippingFeeFor(subtotal); //เพื่อให้ค่ารวมทั้งหมดเป็นราคาสินค้า + ค่าจัดส่ง
