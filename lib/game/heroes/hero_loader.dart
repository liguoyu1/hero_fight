import '../heroes/hero_data.dart';
import '../heroes/hero_registry.dart';

/// Loads hero data via HeroRegistry factory methods (OCP-compliant).
/// New heroes only need to be registered in all_heroes.dart (1 location).
class HeroLoader {
  static final HeroLoader _instance = HeroLoader._internal();
  factory HeroLoader() => _instance;
  HeroLoader._internal();

  /// Get hero by ID via registry factory (no hardcoded switch-case).
  HeroData? getHero(String heroId) {
    return HeroRegistry.instance.create(heroId);
  }

  /// Get all heroes via registry.
  List<HeroData> getAllHeroes() {
    return HeroRegistry.instance.getAll();
  }
}
