import 'package:intl/intl.dart';

String formatMoney(double value) =>
    NumberFormat.currency(locale: 'es', symbol: r'$ ', decimalDigits: 2).format(value);

String formatQty(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toString();
}