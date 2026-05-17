import 'package:intl/intl.dart';

class AppDateUtils {
  const AppDateUtils._();

  static String dMy(DateTime value) => DateFormat('d MMM y').format(value);

  static String dateTimeShort(DateTime value) {
    return DateFormat('d MMM, hh:mm a').format(value);
  }
}
