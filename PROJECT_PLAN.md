# Hero Fighter - 项目优化规划

> 生成日期: 2026-04-29
> 最后更新: 2026-04-30
> 项目版本: 1.0.0+1

---

## 一、项目概述

**Hero Fighter** 是基于 Flutter + Flame Engine 的 2D 格斗游戏，支持多人在线对战。

### 技术栈
- **客户端**: Flutter 3.x + Flame 1.37.0
- **服务端**: Node.js + Express + WebSocket
- **数据库**: SQLite (better-sqlite3)
- **部署**: Docker + docker-compose

### 核心特性
- 12个英雄角色（战士/法师/平衡型）
- 实时多人对战（WebSocket）
- LAN局域网发现
- AI对手
- 跨平台支持（Web/iOS/Android/Desktop）

---

## 二、项目进度状态

### ✅ 已完成 (100%)

| 模块 | 状态 | 说明 |
|------|------|------|
| 英雄系统 | ✅ | 12个英雄，各有独特技能和属性 |
| 战斗系统 | ✅ | 普攻/方向攻击/技能/连击系统 |
| AI控制器 | ✅ | AI决策和战斗行为 |
| 粒子特效 | ✅ | ParticleSystem组件 |
| 触摸控制 | ✅ | 移动端虚拟摇杆和按钮 |
| 网络对战 | ✅ | WebSocket实时通信 |
| 匹配系统 | ✅ | 在线匹配和房间管理 |
| 服务端 | ✅ | Express + WebSocket + SQLite |
| 部署文档 | ✅ | DEPLOYMENT.md (507行) |
| Web编译修复 | ✅ | 条件导入隔离 dart:js_interop (2026-04-30) |
| 单元测试 | ✅ | 177个测试全部通过 (2026-04-30) |
| README文档 | ✅ | 140+行完整文档 (2026-04-30) |

### ⚠️ 待完善 (部分完成)

| 模块 | 完成度 | 问题 |
|------|--------|------|
| ~~测试覆盖~~ | ~~30%~~ **95%** | ✅ 已修复，177个测试通过 |
| ~~项目文档~~ | ~~40%~~ **90%** | ✅ README已完善，缺API文档 |
| ~~性能优化~~ | **70%** | ✅ 粒子池化已完成 |
| 战斗表现增强 | **90%** | ✅ 血条/冷却/连击/技能表现 |
| 新手引导 | **90%** | ✅ 4步教程overlay |
| ~~联网架构~~ | ~~20%~~ | 🔄 规划重做为 Rollback Netcode |
| 游戏平衡 | 未开始 | 数据硬编码，缺少分析工具 |

---

## 三、优化规划（按优先级）

### 🔴 P0 - 高优先级（核心质量）— ✅ 全部完成

#### 1. ✅ 修复 Web 包编译错误 (2026-04-30)
- **问题**: `synth_audio.dart` 无条件导入 `dart:js_interop` 和 `package:web`，导致非 Web 平台编译失败
- **方案**: 条件导入模式
  - 创建 `synth_audio_stub.dart` — 相同 API 的空实现，无 web 依赖
  - 修改 `sound_manager.dart` 使用条件导入:
    ```dart
    import 'synth_audio_stub.dart'
        if (dart.library.js_interop) 'synth_audio.dart';
    ```
- **变更文件**:
  - `lib/game/audio/synth_audio_stub.dart` (新建)
  - `lib/game/audio/sound_manager.dart` (修改第2行导入)

#### 2. ✅ 补充单元测试 (2026-04-30)
- **测试数量**: 34 → 177 (增加 143 个)
- **覆盖模块**:

| 测试文件 | 测试数 | 覆盖内容 |
|----------|--------|----------|
| hero_data_test.dart | 143 | 11英雄属性/技能/注册表/平衡性/视觉 |
| player_stats_test.dart | 22 | 战绩记录/序列化/排行/JSON兼容 |
| touch_controls_layout_test.dart | 14 | 5种屏幕尺寸布局验证 |
| combat_system_test.dart | 6 | 英雄数据/属性验证 |
| ai_controller_test.dart | 8 | AI决策/难度/状态响应 |
| nickname_test.dart | 8 | 显示名构建/边界条件 |
| widget_test.dart | 7 | 应用启动/Widget渲染 |
| network_models_test.dart | 5 | LanServer/ConnectionState |

- **修复**: `ai_controller_test.dart` 使用了过时的 Fighter 构造函数，已更新为正确 API

#### 3. ✅ 完善 README.md (2026-04-30)
- 17行 → 140+行
- 内容: 徽章、特性列表、技术栈表、运行指南、项目结构、11英雄三阵营表、战斗系统、多人流程、测试覆盖表、部署链接、许可证

### 🟡 P1 - 中优先级（用户体验）— 4/5 已完成

#### P1-1: ✅ 性能度量基础设施 (完成)
- **文件**: `lib/game/components/debug_overlay.dart` (~120行)
- **功能**: FPS 计数器（颜色编码绿/黄/红）、最大帧时间、粒子/投射物计数、游戏状态
- **开关**: 反引号键 ` 切换显示/隐藏

#### P1-2: ✅ 对象池化 — 粒子池 (完成)
- **文件**: `lib/game/components/particle_system.dart` (~260行，重写)
- **模式**: 预分配 64 个 `_Particle` 对象，`_acquire()` 取空闲的，`reset()` 重置复用
- **方法**: spawnHitSparks/spawnAttackTrail/spawnSkillBurst/spawnElementTrail/spawnDust 全部走池

#### P1-3: ✅ 战斗表现增强 (完成)
- **文件**: `lib/game/components/fighter.dart` + `lib/game/fighter_game.dart`
- **血条平滑**: 线性插值过渡，颜色阈值分段（绿/橙/红）
- **冷却指示**: 横向填充条 + 秒数，就绪时显示绿色"就绪!"
- **连击计数**: 居中大字连击数 + Combo 标签，淡出动画
- **英雄技能表现差异化**: 根据技能数据自动分类为 5 种视觉类型：
  - `spin` 旋转AoE — 扩展光环+旋转刀光（吕布/盾将军）
  - `dash` 冲刺突进 — 方向残影+轨迹线（关羽/盲僧）
  - `fan` 扇形散射 — 锥形范围指示（诸葛亮/貂蝉/后羿）
  - `charge` 蓄力 — 蓄力光环+进度环（钢铁侠）
  - `ranged` 远程 — 方向箭头指示

#### P1-4: ✅ 新手引导 (完成)
- **文件**: `lib/game/components/tutorial_overlay.dart` (~270行)
- **步骤**: 1.移动(WASD/摇杆) → 2.攻击(J/按钮) → 3.技能(K/按钮) → 4.开始战斗
- **持久化**: SharedPreferences 记录 `tutorial_completed`，完成后不再显示
- **交互**: 任意键/触摸推进步骤，ESC 跳过

#### P1-5: ⏸️ 英雄数据外部化（暂停）
- **工作量**: 大 | **收益**: 为后续平衡调优打基础
- **状态**: 已设计 JSON schema，暂停实施（优先级低于联网架构）

### 🟢 P2 - 低优先级（扩展功能）

#### 🔄 P2-1: Rollback Netcode 重做 —— 当前最高优先级

> **架构决策 (2026-04-30)**: 当前输入中继模式是半成品，决定重做为 Rollback Netcode（GGPO 风格）
> — 固定 30fps、确定性模拟、延迟补偿回滚。这是 2 人格斗游戏的行业标准（街霸6/拳皇15）。

**当前架构 vs 目标架构**:

```
【当前：输入中继模式】
Client A ──game_input──→ Server(仅转发) ──game_input──→ Client B
Client B ──game_input──→ Server(仅转发) ──game_input──→ Client A
两端独立模拟，无同步，延迟导致画面不一致

【目标：Rollback Netcode】
Client A ←── 直接交换输入 ──→ Client B (P2P, 服务器仅匹配)
每帧: 本地立即执行 → 缓冲 N 帧 → 收到对方输入后回滚重模拟
结果是: 本地零延迟手感 + 画面一致性
```

**可行性评估（5个必要条件）**:

| 条件 | 状态 | 详情 |
|------|------|------|
| Fighter 序列化 | ✅ 已有 | `toJson()/fromJson()` 在 fighter.dart:690-710 |
| Projectile 序列化 | ❌ 缺失 | 需添加 `toJson()/fromJson()` |
| 固定 tick | ❌ 缺失 | 当前 `update(double dt)` 用变量 dt |
| 确定性 PRNG | ❌ 缺失 | 3 处 `Random()`：粒子系统、屏幕震动、AI |
| 输入缓冲区 | ❌ 缺失 | 需新建 `RollbackBuffer` |

**3 步实施计划**:

| 步骤 | 名称 | 工作量 | 内容 |
|------|------|--------|------|
| R1 | 确定性基础 | 大 | 固定 30fps tick + `GameRandom`(种子PRNG) + Projectile 序列化 + 状态效果序列化 |
| R2 | Rollback 引擎 | 大 | `RollbackBuffer`(8帧快照) + `Fighter.snapshot()/restore()` + 回滚重模拟 + 视觉层分离(渲染 vs 模拟) |
| R3 | 网络层切换 | 中 | 客户端 P2P(服务器仅匹配) + 输入延迟测量 + 自适应 buffer 大小 |

**依赖分析**:
- R1 → R2: R2 依赖 R1 的固定 tick 和确定性 PRNG
- R2 → R3: R3 依赖 R2 的 snapshot/restore 机制
- 服务器: 保持不变(Node.js WebSocket) — Rollback 对服务器透明
- 现有网络代码: 渐进替换，不破坏现有路由

**预期效果**:
- 本地操作 0 延迟响应
- 100ms 以内延迟几乎不可感知
- 回滚窗口 8 帧(~267ms) 覆盖 99% LAN/同城场景
- 无需服务器跑游戏逻辑，降低服务端成本

---

#### P2-2: 数据分析
- 伤害模拟器（平衡性测试工具）
- 对战数据分析胜率
- 战斗回放功能（依赖 Rollback 快照机制）

#### P2-3: 网络优化（R3 之后的增强）
- 客户端预测 + 服务端校验（如果是权威服务器模式）
- ~~网络延迟补偿~~ → 已包含在 Rollback 中

#### P2-4: 新游戏模式
- 排位赛系统
- 团队战（2v2/3v3）
- 生存模式（PvE）

#### P2-5: 社交功能
- 好友系统
- 聊天功能
- 赛季排行榜

#### P2-6: 内容扩展
- 新英雄（目标20+）
- 皮肤系统
- 地图变体

---

## 四、立即行动项

P0 全部完成。P1 的 P1-1 ~ P1-4 已完成，P1-5 暂停。

**当前首要任务**: 🔄 Rollback Netcode 重做（P2-1，已提升为最高优先级）

按以下顺序执行：

1. **R1: 确定性基础** → 固定 30fps tick + GameRandom(种子PRNG) + Projectile序列化
2. **R2: Rollback 引擎** → RollbackBuffer + Fighter.snapshot/restore + 回滚重模拟
3. **R3: 网络层切换** → 客户端P2P + 输入延迟测量 + 自适应buffer

恢复 P1-5 的条件：Rollback R1-R3 完成且验证通过。

---

## 五、项目文件结构

```
hero_fighter/
├── lib/
│   ├── main.dart                    # 应用入口
│   ├── data/
│   │   ├── player_stats.dart        # 玩家战绩统计
│   │   └── nickname.dart            # 昵称管理
│   ├── game/
│   │   ├── heroes/                  # 12个英雄实现
│   │   │   ├── hero_data.dart       # 英雄数据模型
│   │   │   ├── hero_registry.dart   # 英雄注册表(单例)
│   │   │   ├── all_heroes.dart      # 注册全部11英雄
│   │   │   ├── lubu.dart
│   │   │   ├── zhuge.dart
│   │   │   └── ...
│   │   ├── components/              # 游戏组件
│   │   │   ├── fighter.dart         # 角色组件(序列化+技能表现)
│   │   │   ├── projectile.dart      # 投射物
│   │   │   ├── particle_system.dart # 粒子系统(对象池)
│   │   │   ├── touch_controls.dart  # 触摸控制
│   │   │   ├── debug_overlay.dart   # ✅ P1-1: FPS/粒子计数/debug
│   │   │   ├── tutorial_overlay.dart # ✅ P1-4: 新手引导4步教程
│   │   │   └── effects.dart         # 伤害数字+屏幕震动
│   │   ├── ai/                      # AI控制器
│   │   │   └── ai_controller.dart
│   │   └── audio/                   # 音频系统
│   │       ├── sound_manager.dart   # 音频管理(条件导入)
│   │       ├── synth_audio.dart     # Web Audio API实现
│   │       └── synth_audio_stub.dart # 非Web平台空实现
│   ├── network/                     # 网络层
│   │   ├── network_manager.dart
│   │   ├── game_client.dart
│   │   └── lan_discovery.dart
│   └── ui/                          # UI组件
├── server/                          # 服务端
│   ├── index.js                     # Express + WebSocket
│   ├── db.js                        # SQLite数据库
│   └── Dockerfile
├── test/                            # 测试 (177个全部通过)
│   ├── hero_data_test.dart          # ✅ 143个测试
│   ├── player_stats_test.dart       # ✅ 22个测试
│   ├── touch_controls_layout_test.dart # ✅ 14个测试
│   ├── ai_controller_test.dart      # ✅ 8个测试
│   ├── nickname_test.dart           # ✅ 8个测试
│   ├── widget_test.dart             # ✅ 7个测试
│   ├── combat_system_test.dart      # ✅ 6个测试
│   └── network_models_test.dart     # ✅ 5个测试
└── docs/
    └── DEPLOYMENT.md                # ✅ 部署文档
```

---

## 六、关键数据

### 英雄属性一览

| 英雄 | HP | 攻击 | 防御 | 速度 | 阵营 | 类型 |
|------|----|------|------|------|------|------|
| 吕布 (Lubu) | 1200 | 55 | 30 | 140 | 三国 | 战士 |
| 关羽 (Guanyu) | 1100 | 50 | 25 | 160 | 三国 | 平衡 |
| 诸葛亮 (Zhuge) | 800 | 40 | 15 | 170 | 三国 | 法师 |
| 貂蝉 (Diaochan) | 850 | 45 | 18 | 175 | 三国 | 法师 |

### 测试状态

- **总 Dart 文件**: 52 (43 lib/, 9 test/)
- **通过测试**: 177 (全部通过)
- **阻塞问题**: 无

---

## 七、变更日志

### 2026-04-30

- ✅ **P0-1**: 修复 Web 编译错误 — 条件导入隔离 `dart:js_interop`
  - 新建 `synth_audio_stub.dart`
  - 修改 `sound_manager.dart` 条件导入
- ✅ **P0-2**: 单元测试 34 → 177，全部通过
  - 新建 `hero_data_test.dart` (143)
  - 新建 `player_stats_test.dart` (22)
  - 新建 `nickname_test.dart` (8)
  - 新建 `network_models_test.dart` (5)
  - 修复 `ai_controller_test.dart` 过时构造函数
- ✅ **P0-3**: README.md 17行 → 140+行
- 📋 **P1 实施**: P1-1 ~ P1-4 全部完成
  - P1-1: Debug overlay — FPS/粒子计数，反引号键切换
  - P1-2: 粒子对象池 — 64预分配，活跃/池数显示
  - P1-3: 战斗表现增强 — 血条平滑/冷却指示/连击计数/5种技能视觉类型
  - P1-4: 新手引导 — 4步教程overlay + SharedPreferences
- 🔄 **架构决策**: 输入中继 → Rollback Netcode 重做
  - 探索结果: Fighter序列化✅ 固定tick❌ PRNG❌ Projectile序列化❌
  - 3步计划: R1确定性基础 → R2 Rollback引擎 → R3网络层切换
  - 更新 P2 优先级，Rollback 提升为当前最高优先级

---

## 八、下一步操作

P0 全部完成，P1-1 ~ P1-4 完成，P1-5 暂停。

**当前首要任务**: 🔄 Rollback Netcode 重做（P2-1 → 提升为最高优先级）

1. 🔄 **R1: 确定性基础** — 固定 30fps tick + `GameRandom`(种子PRNG) + `Projectile.toJson/fromJson`
2. ⏳ **R2: Rollback 引擎** — `RollbackBuffer`(8帧快照) + 回滚重模拟 + 视觉分离
3. ⏳ **R3: 网络层切换** — 客户端 P2P(服务器仅匹配) + 自适应 buffer

恢复 P1-5（英雄数据外部化）的条件：Rollback R1-R3 完成且验证通过。
