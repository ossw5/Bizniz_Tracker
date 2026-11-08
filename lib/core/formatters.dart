import 'package:intl/intl.dart';

String _currencyCode = 'PHP';
String _datePattern = 'MMM d, yyyy';

void configureAppFormatting({
  required String currencyCode,
  required String datePattern,
}) {
  _currencyCode = currencyCode;
  _datePattern = datePattern;
}

String formatAppCurrency(num value) {
  final (locale, symbol) = switch (_currencyCode) {
    'USD' => ('en_US', r'$'),
    'EUR' => ('de_DE', '€'),
    _ => ('en_PH', '₱'),
  };
  return NumberFormat.currency(
    locale: locale,
    symbol: symbol,
    decimalDigits: 2,
  ).format(value);
}

String formatCurrency(double value) => formatAppCurrency(value);

String formatAppDate(DateTime date) => DateFormat(_datePattern).format(date);
