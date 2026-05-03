import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../heroes/hero_data.dart';
import '../heroes/lubu.dart';
import '../heroes/guanyu.dart';
import '../heroes/zhuge.dart';
import '../heroes/diaochan.dart';
import '../heroes/lee_sin.dart';
import '../heroes/ironman.dart';
import '../heroes/thor.dart';
import '../heroes/twisted_fate.dart';
import '../heroes/ashe.dart';
import '../heroes/thanos.dart';
import '../heroes/captain.dart';

/// Loads hero data from JSON files with Dart constructor fallback.
/// JSON files are stored in assets/heroes/ directory.
class HeroLoader {
  static final HeroLoader _instance = HeroLoader._internal();
  factory HeroLoader() => _instance;
  HeroLoader._internal();

  final Map<String, Map<String, dynamic>> _jsonCache = {};
  bool _jsonLoaded = false;

  /// Load hero JSON data from assets
  Future<void> loadHeroJson() async {
    if (_jsonLoaded) return;

    try {
      // Try loading hero JSON files
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest = json.decode(manifestContent);

      for (final path in manifest.keys) {
        if (path.startsWith('assets/heroes/') && path.endsWith('.json')) {
          final heroId = path.split('/').last.replaceAll('.json', '');
          try {
            final jsonString = await rootBundle.loadString(path);
            _jsonCache[heroId] = json.decode(jsonString);
            debugPrint('HeroLoader: loaded $heroId from JSON');
          } catch (e) {
            debugPrint('HeroLoader: failed to load $path: $e');
          }
        }
      }
      _jsonLoaded = true;
    } catch (e) {
      debugPrint('HeroLoader: AssetManifest not found, using Dart fallback only');
      _jsonLoaded = true;
    }
  }

  /// Get hero data by ID - tries JSON first, falls back to Dart constructor
  HeroData? getHero(String heroId) {
    // Check JSON cache first
    if (_jsonCache.containsKey(heroId)) {
      return _heroFromJson(_jsonCache[heroId]!);
    }

    // Fallback to Dart constructors
    return _getHeroFromDart(heroId);
  }

  /// Create HeroData from JSON (simplified - full parsing would need more fields)
  HeroData? _heroFromJson(Map<String, dynamic> json) {
    // For full implementation, parse all JSON fields
    // This is a simplified version that demonstrates the pattern
    final id = json['id'] as String?;
    if (id == null) return null;

    // Return null to use Dart fallback for now - full JSON parsing
    // would require mapping all hero properties
    debugPrint('HeroLoader: JSON for $id found, using Dart fallback (full JSON parsing TBD)');
    return _getHeroFromDart(id);
  }

  /// Get hero from Dart constructors (original implementation)
  HeroData? _getHeroFromDart(String heroId) {
    switch (heroId) {
      case 'lubu':
        return LubuHero();
      case 'guanyu':
        return GuanyuHero();
      case 'zhuge':
        return ZhugeHero();
      case 'diaochan':
        return DiaochanHero();
      case 'lee_sin':
        return ShaolinMonkHero();
      case 'ironman':
        return MohistHero();
      case 'thor':
        return LeizhenziHero();
      case 'twisted_fate':
        return GuiguziHero();
      case 'ashe':
        return HouyiHero();
      case 'thanos':
        return ChiyouHero();
      case 'captain':
        return ShieldGeneralHero();
      default:
        debugPrint('HeroLoader: unknown hero $heroId');
        return null;
    }
  }

  /// Get all heroes as a list
  List<HeroData> getAllHeroes() {
    return [
      LubuHero(),
      GuanyuHero(),
      ZhugeHero(),
      DiaochanHero(),
      ShaolinMonkHero(),
      MohistHero(),
      LeizhenziHero(),
      GuiguziHero(),
      HouyiHero(),
      ChiyouHero(),
      ShieldGeneralHero(),
    ];
  }

  /// Check if JSON data is available for a hero
  bool hasJsonData(String heroId) => _jsonCache.containsKey(heroId);

  /// Get JSON data for a hero (returns null if not loaded)
  Map<String, dynamic>? getJsonData(String heroId) => _jsonCache[heroId];
}