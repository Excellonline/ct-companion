import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PasteboardService {
  static const _channel = MethodChannel('io.cardtrove.companion/pasteboard');

  Future<Uint8List?> readImage() async {
    if (kIsWeb || !Platform.isMacOS) return null;
    final data = await _channel.invokeMethod<Uint8List>('readImage');
    if (data == null || data.isEmpty) return null;
    return data;
  }
}
