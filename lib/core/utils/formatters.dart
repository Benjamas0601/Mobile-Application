import 'package:intl/intl.dart';

//ไฟล์นี้เป็นไฟล์ที่เก็บการจัดรูปแบบราคาและวันที่ให้แสดงตรงกันทั้งแอป
// เช่น การแสดงราคาสินค้าเป็นสกุลเงินบาท การแสดงวันที่เป็นรูปแบบไทย และการแสดงจำนวนสินค้าที่ขายเป็นรูปแบบย่อ เช่น 1.2k แทนที่จะเป็น 1200

/// Thai formatting helpers.
///
/// Kept in one file because a baht symbol or a Buddhist-era year that is
/// wrong in three different places is impossible to review.
/// รวมการจัดรูปแบบราคาและวันที่ให้แสดงตรงกันทั้งแอป
class Fmt {
  Fmt._();

  static final NumberFormat _baht = NumberFormat.currency(  //เพื่อให้แสดงสกุลเงินเป็นบาท
    locale: 'th_TH',
    symbol: '฿',
    decimalDigits: 0,
  );

  /// `฿1,290` — no decimals, because OTOP pricing is whole-baht.
  static String price(num value) => _baht.format(value);  //เพื่อให้แสดงราคาสินค้าเป็นสกุลเงินบาท

  static final DateFormat _thaiDate = DateFormat('d MMM yyyy', 'th_TH'); //เพื่อให้แสดงวันที่เป็นรูปแบบไทย
  static final DateFormat _thaiDateTime = DateFormat(  
    'd MMM yyyy เวลา HH:mm',
    'th_TH',
  );

  static String date(DateTime? value) =>  
      value == null ? '-' : _thaiDate.format(value);

  static String dateTime(DateTime? value) =>
      value == null ? '-' : _thaiDateTime.format(value);

  /// `4.8` — one decimal, the way Thai marketplaces show ratings.
  static String rating(double value) => value.toStringAsFixed(1);

  /// `1.2k` / `12.4k` — keeps the sold counter from wrapping the card.
  static String compactCount(int value) {   //เพื่อให้แสดงจำนวนสินค้าที่ขายเป็นรูปแบบย่อ เช่น 1.2k แทนที่จะเป็น 1200
    if (value < 1000) return '$value';
    if (value < 10000) return '${(value / 1000).toStringAsFixed(1)}k';
    return '${(value / 1000).round()}k';
  }

  /// Fills `{count}` / `{amount}` / `{rate}` in an AppStrings template.
  static String fill( 
    String template, {
    int? count,
    String? amount,
    String? rate,
    String? status,
  }) {
    return template
        .replaceAll('{count}', '$count')
        .replaceAll('{amount}', amount ?? '')
        .replaceAll('{rate}', rate ?? '')
        .replaceAll('{status}', status ?? '');
  }
}
