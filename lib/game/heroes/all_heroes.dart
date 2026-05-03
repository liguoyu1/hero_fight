import 'hero_registry.dart';

// 三国英雄
import 'lubu.dart';
import 'zhuge.dart';
import 'guanyu.dart';
import 'diaochan.dart';

// 神话英雄
import 'lee_sin.dart';    // 少林武僧
import 'ashe.dart';       // 后羿
import 'thor.dart';       // 雷震子
import 'thanos.dart';     // 蚩尤

// 战国英雄
import 'twisted_fate.dart'; // 鬼谷子
import 'captain.dart';      // 盾卫将军
import 'ironman.dart';      // 墨家机关师

/// Register all 11 heroes into the global registry.
/// Call this once at game startup.
void registerAllHeroes() {
  final registry = HeroRegistry.instance;

  // 三国英雄
  registry.register(LubuHero());
  registry.register(ZhugeHero());
  registry.register(GuanyuHero());
  registry.register(DiaochanHero());

  // 神话英雄
  registry.register(ShaolinMonkHero());  // 少林武僧
  registry.register(HouyiHero());        // 后羿
  registry.register(LeizhenziHero());    // 雷震子
  registry.register(ChiyouHero());       // 蚩尤

  // 战国英雄
  registry.register(GuiguziHero());        // 鬼谷子
  registry.register(ShieldGeneralHero());  // 盾卫将军
  registry.register(MohistHero());         // 墨家机关师
}
