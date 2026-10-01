/// ค่าจัดส่งแบบเหมาจ่ายตามโมเดลข้อมูลตั้งต้นของแอป
///
/// Lives here rather than in the cart or the order repository because both
/// sides need the same numbers: the cart shows a total before an order exists,
/// and the order repository recomputes the total when writing the document.
/// A second copy of the threshold would eventually disagree with the first and
/// produce orders whose total differs from the checkout the buyer approved.
library;

const double kShippingFee = 50;

const double kFreeShippingOver = 1000;

double shippingFeeFor(double subtotal) =>
    (subtotal <= 0 || subtotal >= kFreeShippingOver) ? 0 : kShippingFee;

double totalFor(double subtotal) => subtotal + shippingFeeFor(subtotal);
