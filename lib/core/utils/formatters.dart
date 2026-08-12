import 'package:intl/intl.dart';

/// Shared formatting helpers (LKR, Colombo timezone display).
class Formatters {
  Formatters._();

  static final NumberFormat _lkr = NumberFormat.currency(
    locale: 'en_LK',
    symbol: 'Rs. ',
    decimalDigits: 2,
  );

  static final DateFormat _date = DateFormat('dd MMM yyyy');
  static final DateFormat _time = DateFormat('hh:mm a');
  static final DateFormat _dateTime = DateFormat('dd MMM yyyy · hh:mm a');

  static String currency(num amount) => _lkr.format(amount);

  static String date(DateTime value) => _date.format(value.toLocal());

  static String time(DateTime value) => _time.format(value.toLocal());

  static String dateTime(DateTime value) => _dateTime.format(value.toLocal());
}
