import 'package:flutter/foundation.dart';

/// DB 내용이 바뀌면 숫자가 올라감 → 홈·마이페이지가 듣고 있다가 다시 불러옴
final ValueNotifier<int> dataChanged = ValueNotifier<int>(0);

void notifyDataChanged() => dataChanged.value++;
