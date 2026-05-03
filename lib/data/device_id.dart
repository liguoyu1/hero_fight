import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kDeviceIdKey = 'hero_fighter_device_id';

Future<String> getDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  final cached = prefs.getString(_kDeviceIdKey);
  if (cached != null && cached.isNotEmpty) return cached;

  final id = await _fetchHardwareId();
  await prefs.setString(_kDeviceIdKey, id);
  return id;
}

Future<String> _fetchHardwareId() async {
  final info = DeviceInfoPlugin();

  if (kIsWeb) {
    final web = await info.webBrowserInfo;
    final raw = '${web.browserName.name}_${web.platform ?? ''}_${web.userAgent ?? ''}';
    return _fnvHash(raw);
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      final android = await info.androidInfo;
      return android.id;
    case TargetPlatform.iOS:
      final ios = await info.iosInfo;
      return ios.identifierForVendor ?? _fallbackId();
    case TargetPlatform.macOS:
      final mac = await info.macOsInfo;
      return mac.systemGUID ?? _fallbackId();
    case TargetPlatform.windows:
      final win = await info.windowsInfo;
      return win.deviceId;
    case TargetPlatform.linux:
      final linux = await info.linuxInfo;
      return linux.machineId ?? _fallbackId();
    default:
      return _fallbackId();
  }
}

String _fallbackId() {
  final ts = DateTime.now().microsecondsSinceEpoch;
  return 'fb_${ts.toRadixString(36)}';
}

// FNV-1a hash for Web browser fingerprinting
String _fnvHash(String input) {
  var h = 0x811c9dc5;
  for (var i = 0; i < input.length; i++) {
    h ^= input.codeUnitAt(i);
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return 'web_${h.toRadixString(16).padLeft(8, '0')}';
}
