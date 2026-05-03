import 'package:shared_preferences/shared_preferences.dart';

const _kNicknameKey = 'hero_fighter_nickname';
const int maxNicknameLength = 8;

/// Get saved nickname, returns null if not set.
Future<String?> getNickname() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kNicknameKey);
}

/// Save nickname after validation. Returns true if saved, false if invalid.
Future<bool> saveNickname(String nickname) async {
  final trimmed = nickname.trim();
  if (trimmed.isEmpty || trimmed.length > maxNicknameLength) return false;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kNicknameKey, trimmed);
  return true;
}

/// Build display name for leaderboard: nickname + last 4 chars of deviceId.
String buildDisplayName(String nickname, String deviceId) {
  final suffix = deviceId.length >= 4
      ? deviceId.substring(deviceId.length - 4)
      : deviceId;
  return '$nickname#$suffix';
}
