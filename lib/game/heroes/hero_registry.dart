import 'hero_data.dart';

/// Singleton registry for all hero definitions
class HeroRegistry {
  HeroRegistry._();
  static final HeroRegistry instance = HeroRegistry._();

  final Map<String, HeroData> _heroes = {};

  /// Register a hero data instance
  void register(HeroData hero) {
    _heroes[hero.id] = hero;
  }

  /// Get a hero by id (returns a reference, stats are const)
  HeroData? get(String id) => _heroes[id];

  /// Get all registered heroes
  List<HeroData> getAll() => _heroes.values.toList();

  /// Get heroes filtered by faction
  List<HeroData> getByFaction(Faction faction) =>
      _heroes.values.where((h) => h.faction == faction).toList();

  /// Get all hero ids
  List<String> get ids => _heroes.keys.toList();

  /// Total registered count
  int get count => _heroes.length;
}
