import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// 與 dHealth 同一套（`lib/utils/log.dart`）：release 也把真正的失敗送進 logcat。
///
/// 之前全案沒有任何 log 出口，`_readOr` / `_writeHungerQuietly` 的 catch 把異常吞掉，
/// 於是「餓度沒存進去」與「根本沒存過」在外面完全無法區分（DEVICE_TEST.md A-5 要靠這裡）。
void appError(String message, Object error, [StackTrace? stackTrace]) {
  developer.log('$message: $error', name: 'dneko.error', error: error, stackTrace: stackTrace);
  if (kDebugMode) debugPrint('$message: $error');
}
