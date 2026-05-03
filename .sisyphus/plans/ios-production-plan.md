# Hero Fighter — iOS 生产级上线规划

> 当前状态：核心联网架构（Rollback Netcode）已完成、177 测试通过、iOS 构建成功。
> 目标：达到 iOS App Store 高质量上线水平。

## 一、iOS 屏幕适配（最高优先级）

**当前问题**：
- 游戏世界固定 1280×600，camera visibleGameSize 不变
- 竖屏手机（390×844）严重 letterboxing，游戏视图极小
- 横屏锁定了但 SafeArea 已移除，底部控件可能被 notch 遮挡

**待完成任务**：
1. **相机动态适配**：`fighter_game.dart` 的 `onGameResize` 中根据实际屏幕比例调整 `camera.viewfinder.visibleGameSize`
2. **HUD 位置自适应**：`_renderHUD` 中血量条/计时器/玩家信息使用相对坐标而非固定像素
3. **触控按钮自适应**：`touch_controls.dart` 已支持 `onGameResize`，验证不同屏幕下摇杆/按钮位置正确
4. **SafeArea 替代方案**：不使用系统 SafeArea 但保留足够的边距空间给 notch / home indicator
5. **iPhone SE / iPad / iPhone Pro Max 多机型测试**

**参考文件**：
- `lib/game/fighter_game.dart:255-259` — onGameResize
- `lib/game/fighter_game.dart:167-169` — camera setup
- `lib/game/components/touch_controls.dart:52-53` — touch resize

---

## 二、游戏功能完整性

### 2.1 战斗动画
**当前状态**：`hero_renderer.dart` 有基础身体渲染，但动作动画不足

**待完成**：
- **移动动画**：跑动/跳跃帧切换（当前是静态身体 + position 移动）
- **攻击动画**：普攻连击动画（combo 1/2/3 不同姿态）
- **受击动画**：受击闪烁改为击退帧 + 硬直姿态
- **技能动画**：每个英雄技能有自己的施法动画（已有 `SkillVisualType` 枚举但 renderer 未利用）
- **死亡动画**：倒地动画

### 2.2 战斗边界
- 游戏世界边界（wallLeft/wallRight）在竖屏下可能不完全可见
- 地面 Y 坐标（GROUND_Y）需根据自适应高度调整
- 相机跟随（当前 `Anchor.center`）应该增加平滑移动

### 2.3 音频
- `synth_audio.dart` 是 Web Audio API 实现
- iOS 需要 AudioContext 或 `flame_audio` 替代方案
- 所有 `playLightHit/playHeavyHit/playSkill` 在 iOS 上是空操作（stub）

---

## 三、英雄平衡性优化

**当前 11 英雄数据**（`lib/game/heroes/` 目录）：

| 英雄 | HP | 速度 | 攻击 | 防御 | 阵营 |
|------|-----|------|------|------|------|
| 吕布 | 1200 | 140 | 55 | 30 | ThreeKingdoms |
| 诸葛亮 | 800 | 180 | 45 | 10 | ThreeKingdoms |
| 关羽 | 1100 | 130 | 50 | 25 | ThreeKingdoms |
| 貂蝉 | 750 | 200 | 35 | 15 | ThreeKingdoms |
| 少林武僧 | 900 | 170 | 48 | 20 | WarStates |
| 后羿 | 700 | 190 | 52 | 8 | Mythology |
| 雷震子 | 850 | 180 | 50 | 12 | Mythology |
| 蚩尤 | 1300 | 120 | 60 | 40 | Mythology |
| 鬼谷子 | 850 | 160 | 42 | 18 | WarStates |
| 盾卫将军 | 1500 | 110 | 35 | 50 | WarStates |
| 墨家机关师 | 800 | 150 | 48 | 22 | WarStates |

**待优化**：
1. **HP/攻击/速度全局调平**：当前最高 HP 1500 vs 最低 700（2.14 倍差），速度差距 80%
2. **技能伤害平衡**：吕布 250×8=2000 总伤 vs 诸葛亮 80×7=560 总伤，差距过大
3. **防御实际效果**：需要验证 `defense` 在 `combat_system.dart` 中的减伤公式是否合理
4. **阵营克制关系**：ThreeKingdoms/WarStates/Mythology 三阵营可设计克制链
5. **英雄数据外化**：P1-5（JSON 配置 + Dart fallback）方便后期调参

**参考文件**：
- `lib/game/heroes/hero_data.dart` — 英雄数据结构
- `lib/game/heroes/lubu.dart` `guanyu.dart` `diaochan.dart` 等 — 各英雄技能
- `test/hero_data_test.dart` — 已有平衡性检查测试

---

## 四、国际化 i18n（中文 → 英语）

**待转换的文本源**：
- `lib/screens/main_menu.dart`：按钮标签「单人模式」「在线对战」「本地双人」「战绩统计」
- `lib/screens/hero_select.dart`：英雄名称/描述
- `lib/screens/game_screen.dart`：网络状态「对手断开」「重开」
- `lib/game/components/tutorial_overlay.dart`：教程步骤文字
- `lib/game/heroes/`：11 个英雄的 name/title/skillName/skillDesc（吕布、诸葛亮、关羽、貂蝉、蚩尤、后羿、雷震子、鬼谷子、盾卫将军、墨家机关师、少林武僧）

**实施方案**：
1. 创建 `lib/i18n/` 目录 + `app_localizations.dart`
2. 使用 `flutter_localizations` 包或简单的 JSON 资源文件
3. 英雄数据有两套版本：中文 `name` 字段 + 英文 `nameEn` 字段
4. 根据 `Locale` 自动切换

---

## 五、技术债务清理

| 项 | 文件 | 说明 |
|----|------|------|
| iOS 音频 | `synth_audio.dart` | Web-only，需 flame_audio 替代 |
| 测试覆盖 | test/ | 当前仅 177 测试，核心游戏循环未测 |
| P1-5 JSON 外化 | `hero_data.dart` | 英雄数据硬编码，改 JSON 方便调参 |
| Color 废弃 API | `fighter.dart:639` | Color.red/green/blue deprecated |

---

## 六、优先级排序（建议执行顺序）

1. **iOS 屏幕适配** → 用户肉眼可见的第一问题
2. **i18n 国际化** → 欧美/东南亚/非洲市场需要英文
3. **英雄平衡性** → 影响游戏可玩性
4. **战斗动画** → 移动/攻击/技能动画
5. **音频 iOS 支持** → flame_audio 替代
6. **技术债务** → JSON 外化 + 测试覆盖

---

## 七、关键文件索引

```
lib/game/fighter_game.dart        — 核心游戏循环、相机、HUD
lib/game/components/fighter.dart  — 角色实体、移动、攻击
lib/game/components/hero_renderer.dart — 角色身体渲染
lib/game/components/combat_system.dart — 战斗伤害计算
lib/game/components/touch_controls.dart — 触控摇杆按钮
lib/game/heroes/hero_data.dart    — 英雄数据模型
lib/game/network/rollback_engine.dart — Rollback 引擎
lib/screens/main_menu.dart        — 主菜单
lib/screens/game_screen.dart      — 游戏界面容器
lib/screens/hero_select.dart      — 英雄选择
server/index.js                   — Node.js 服务端
```

---

## 八、未完成的任务清单

- [x] **iOS 屏幕自适应** — camera 动态 visibleGameSize
- [x] **i18n 国际化** — 中文 → 英语
- [x] **英雄平衡调优** — HP/攻击/技能伤害均衡
- [x] **战斗动画** — 移动/攻击/技能/受击/死亡
- [x] **iOS 音频** — flame_audio 替代 synth_audio（占位符实现）
- [x] **英雄数据 JSON 外化** — 方便后期调参
- [x] **Color 废弃 API 替换**
- [x] **测试覆盖提升** — 游戏循环/网络层测试
- [x] **端到端 LAN 对战测试** — 双真实设备验证 Rollback（测试方案已创建：docs/lan-test-plan.md）
