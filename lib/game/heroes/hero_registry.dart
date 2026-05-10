import 'hero_data.dart';

/// Singleton registry for all hero definitions
class HeroRegistry {
  HeroRegistry._();
  static final HeroRegistry instance = HeroRegistry._();

  final Map<String, HeroData> _heroes = {};
  final Map<String, HeroData Function()> _factories = {};

  /// Register a hero data instance (for lookup/display)
  void register(HeroData hero) {
    _heroes[hero.id] = hero;
  }

  /// Register a factory function for creating new hero instances
  void registerFactory(String id, HeroData Function() factory) {
    _factories[id] = factory;
  }

  /// Get a hero by id (returns reference to registered instance)
  HeroData? get(String id) => _heroes[id];

  /// Create a new hero instance by id (uses factory, falls back to registered instance)
  HeroData? create(String id) {
    final factory = _factories[id];
    if (factory != null) return factory();
    return _heroes[id]; // fallback: return existing instance
  }

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
