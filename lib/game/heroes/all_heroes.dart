import 'hero_registry.dart';

// 三国英雄
import 'lubu.dart';
import 'zhuge.dart';
import 'guanyu.dart';
import 'diaochan.dart';

// 神话英雄
import 'shaolin_monk.dart';    // 少林武僧
import 'hou_yi.dart';       // 后羿
import 'lei_zhen_zi.dart';       // 雷震子
import 'chi_you.dart';     // 蚩尤

// 战国英雄
import 'gui_guzi.dart'; // 鬼谷子
import 'shield_general.dart';      // 盾卫将军
import 'mo_hist.dart';      // 墨家机关师
import 'jingke.dart';       // 荆轲

/// Register all 12 heroes into the global registry.
/// Call this once at game startup.
void registerAllHeroes() {
  final r = HeroRegistry.instance;

  // 三国英雄
  r.register(LubuHero());          r.registerFactory('lubu', () => LubuHero());
  r.register(ZhugeHero());         r.registerFactory('zhuge', () => ZhugeHero());
  r.register(GuanyuHero());        r.registerFactory('guanyu', () => GuanyuHero());
  r.register(DiaochanHero());      r.registerFactory('diaochan', () => DiaochanHero());

  // 神话英雄
  r.register(ShaolinMonkHero());   r.registerFactory('lee_sin', () => ShaolinMonkHero());
  r.register(HouyiHero());         r.registerFactory('ashe', () => HouyiHero());
  r.register(LeizhenziHero());     r.registerFactory('thor', () => LeizhenziHero());
  r.register(ChiyouHero());        r.registerFactory('thanos', () => ChiyouHero());

  // 战国英雄
  r.register(GuiguziHero());       r.registerFactory('twisted_fate', () => GuiguziHero());
  r.register(ShieldGeneralHero()); r.registerFactory('captain', () => ShieldGeneralHero());
  r.register(MohistHero());        r.registerFactory('ironman', () => MohistHero());
  r.register(JingkeHero());        r.registerFactory('jingke', () => JingkeHero());
}
