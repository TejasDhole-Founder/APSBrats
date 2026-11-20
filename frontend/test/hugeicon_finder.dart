import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';

/// Finds the HugeIcon widget drawing [icon] (an exact `HugeIcons` constant).
Finder hugeIcon(List<List<dynamic>> icon) =>
    find.byWidgetPredicate((w) => w is HugeIcon && identical(w.icon, icon));
