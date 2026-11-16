import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Riconosce TV / Firestick e dispositivi datati, per alleggerire la grafica.
class Device {
  static bool isTv = false;
  static bool lowEnd = false;

  static Future<void> init() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final f = info.systemFeatures;
      isTv = f.contains('android.software.leanback') || f.contains('android.hardware.type.television');
      lowEnd = info.version.sdkInt <= 25; // Android 7.1 o precedente (Fire TV Stick di vecchia generazione)
    } catch (_) {}
  }
}
