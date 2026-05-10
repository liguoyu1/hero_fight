# Hero Fighter — App Store 上线 & 用户体验全面审计报告

**审计日期**: 2026-05-07  
**项目路径**: /Users/guoyuli/Documents/code_s/hero_fighter  
**项目概况**: Flutter + Flame 格斗游戏，11 英雄，支持 AI/本地双人/在线匹配，已部署 Railway 后端

---

## 一、编译/构建阻塞问题 (Critical — 必须先修复)

### 1.1 🔴 fighter_game.dart 第1行 corrupted
**文件**: `lib/game/fighter_game.dart:1`  
**问题**: 第1行为 `s d dimport 'dart:math';` — 应改为 `import 'dart:math';`  
**影响**: flutter analyze 报 69 issues，其中 20+ 个是此文件的级联错误。项目无法编译。
**修复**: 修改第1行，删掉前面的 `s d d`

### 1.2 🔴 SizeViewport / Viewport API 不存在
**文件**: `lib/game/fighter_game.dart:53`  
**问题**: `Viewport createViewport() => SizeViewport();` — Flame 1.37 中这两个类都不存在。使用 `camera.viewfinder.visibleGameSize` 替代。
**影响**: 编译错误，无法构建
**修复**: 删除 `createViewport()` 覆写方法，或使用 Flame 1.37 正确的 viewport API

### 1.3 🔴 OverlayBuilder 未导出
**文件**: `lib/screens/game_screen.dart:5`  
**问题**: `show OverlayBuilder` — `package:flame/game.dart` 不导出此成员
**修复**: 删除该 show 限定

### 1.4 🔴 onGameStateChanged 类型不匹配
**文件**: `lib/screens/game_screen.dart:88`  
**问题**: `void Function()` 被赋给 `void Function(GameState)?` 类型的字段
**修复**: 统一回调签名

---

## 二、App Store 上线合规 (iOS 特定)

### 2.1 🔴 iOS 方向配置与游戏冲突
**文件**: `ios/Runner/Info.plist:56-61`  
**问题**: Info.plist 支持 Portrait 方向，但游戏 `main.dart` 强制 Landscape。App Store 审核会因不匹配而拒绝。
**修复**: 删除 `UISupportedInterfaceOrientations` 中的 Portrait 条目，只保留 LandscapeLeft/LandscapeRight

### 2.2 🔴 iPad 方向配置同样含 Portrait
**文件**: `ios/Runner/Info.plist:62-68`  
**问题**: iPad 配置包含 Portrait 和 PortraitUpsideDown
**修复**: 同样只保留 Landscape 方向

### 2.3 🔴 缺少隐私清单 (Privacy Manifest)
**文件**: `ios/Runner/PrivacyInfo.xcprivacy` — **不存在**  
**问题**: 从 2024 年 5 月起，Apple 要求所有 App 提交时必须包含 `PrivacyInfo.xcprivacy` 文件，声明使用的隐私相关 API。
**影响**: 直接导致 App Store 审核拒绝
**修复**: 创建 PrivacyInfo.xcprivacy，声明：
- `NSPrivacyAccessedAPICategoryFileTimestamp` (shared_preferences)
- `NSPrivacyAccessedAPICategoryDiskSpace` (device_info_plus)
- `NSPrivacyAccessedAPICategoryUserDefaults` (shared_preferences)
- `NSPrivacyCollectedDataTypes` (声明"不收集数据")
- 注意：http 网络请求 (privacy-affecting) 也需要声明

### 2.4 🔴 缺少 NSAppTransportSecurity 例外
**文件**: `ios/Runner/Info.plist`  
**问题**: 后端使用 HTTPS (Railway)，且 LAN 发现可能用本地 HTTP，但未声明 ATS 例外。
**影响**: LAN 匹配模式下，本地 HTTP 连接可能被阻止
**修复**: 若需要 localhost HTTP 连接，添加 NSAppTransportSecurity 例外：
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

### 2.5 🔴 iOS 部署目标过低
**文件**: `ios/Podfile:2`  
**问题**: `platform :ios, '13.0'` 被注释掉，默认为 Flutter 最低版本。App Store 现在要求最低 iOS 15.0（即将要求 16.0）。
**修复**: 取消注释并改为 `platform :ios, '15.0'`

### 2.6 🔴 CFBundleName 使用 snake_case
**文件**: `ios/Runner/Info.plist:18`  
**问题**: `<string>hero_fighter</string>` — App Store 显示名称不应是 snake_case
**修复**: 改为 `Hero Fighter`

### 2.7 🔴 缺少应用图标 (App Icon)
**目录**: `ios/Runner/Assets.xcassets/AppIcon.appiconset`  
**问题**: 不清楚是否有实际图标替换默认 Flutter 图标。默认图标会被 App Store 拒绝。
**修复**: 需要 1024x1024 的 App Store 图标 + 所有分辨率的图标集

### 2.8 🔴 缺少启动画面 (Launch Screen)
**问题**: iOS 默认启动画面是白色，但游戏是黑暗主题 → 白闪问题
**修复**: 修改 `LaunchScreen.storyboard`，背景设为深色 (#0D0D2B)

### 2.9 🔴 缺少隐私政策 URL
**问题**: 代码库中没有隐私政策页面、链接或文档。App Store 要求所有 App 必须提供隐私政策 URL。
**影响**: 直接审核拒绝
**修复**: 
- 创建隐私政策页面（可托管在 GitHub Pages）
- 在 App Store Connect 填写隐私政策 URL
- 在 App 内设置页面添加隐私政策入口
- 声明：不收集个人数据，或如实列出收集的数据

### 2.10 🔴 缺少 App Store 元数据
**缺失项**:
- App 描述（多语言）
- 关键词
- 截图（6.7"/6.5"/5.5" iPhone, 12.9" iPad）
- 宣传文本
- 年龄分级问卷

---

## 三、游戏设计与平衡性审计

### 3.1 🟡 英雄数量不足 (11 vs 12)
**文件**: `lib/game/heroes/all_heroes.dart`  
**问题**: 注释说 "Register all 11 heroes"，且代码中实际注册 11 个英雄（三国 4 + 神话 4 + 战国 3）。用户提到应有 12 个英雄。
**影响**: 匹配模式中英雄池偏小，选择体验不佳
**建议**: 补上第 12 个英雄，使三方阵营各 4 个（三国 4、神话 4、战国 4）

### 3.2 🟡 英雄平衡性未经测试验证
所有英雄数据中都标注了 `// Balanced: was XXX`，说明数值经过初步调整但未经充分测试。
**核心问题**:

| 英雄 | HP | 攻 | 防 | 技能伤害 | CD | 评估 |
|------|-----|-----|-----|-----|-----|------|
| 吕布 | 1150 | 52 | 28 | 240(8方向) | 8s | 偏强，8方向AOE+高HP |
| 关羽 | 1080 | 50 | 28 | 300(突进) | 10s | 平衡 |
| 诸葛亮 | 880 | 40 | 18 | 80×7=560 | 6s | 🔴 技能总伤过高！560 理论最高，全中瞬间秒杀 |
| 貂蝉 | 880 | 38 | 18 | 90×5=450 | 5s | 🟡 极高机动性+最短CD+冻结 |
| 后羿 | 880 | 42 | 16 | 250(贯穿冻结2s) | 12s | 🟡 2秒冻结偏长 |
| 少林武僧 | 980 | 48 | 24 | 200+150=350 | 9s | 平衡 |
| 蚩尤 | 1150 | 52 | 32 | 350(眩晕1.5s) | 12s | 🔴 高HP+高攻+高防+最长眩晕，可能是最强英雄 |
| 雷震子 | 1000 | 48 | 24 | 220(眩晕1s) | 7s | 🟡 从天而降弹道难命中 |
| 盾卫将军 | 1200 | 42 | 38 | 150(弹跳3次) | 6s | 🟡 最高HP+最高防+最短CD，但伤害低 |
| 鬼谷子 | 950 | 44 | 20 | 70×5=350 | 5s | 平衡 |
| 墨家机关师 | 920 | 45 | 24 | 280(贯穿充能0.5s) | 8s | 🟡 充能0.5s=易被打断 |

**高危发现**:
- 诸葛亮技能理论最高伤害 560，远超其他所有英雄
- 蚩尤集高HP(1150)、高攻(52)、高防(32)、长眩晕(1.5s)于一身
- 貂蝉 CD 仅 5s 且带冻结，高频控制

### 3.3 🟡 缺少新手教学
**文件**: `lib/game/components/tutorial_overlay.dart` 存在但需要确认是否完整实现  
**问题**: 格斗游戏对新手不友好，没有引导学习操作、技能释放时机
**影响**: 用户留存率低，差评率高

### 3.4 🟡 游戏模式完整度
- ✅ AI 对战
- ✅ 本地双人
- ✅ 在线匹配 (LAN/Online)
- 🟡 缺少：练习模式（无对手自由练习连招）、训练模式

### 3.5 🟡 缺少游戏经济/进度系统
**问题**: 没有角色解锁、皮肤、货币等长期留存机制
**影响**: 缺乏重复游玩动机，留存率堪忧

---

## 四、UI/UX 用户体验审计

### 4.1 🟡 主菜单缺少匹配对战入口
**文件**: `lib/screens/main_menu.dart:145-148`  
**问题**: 按钮有 VS AI, Online Battle, Local 2P, Stats。用户之前明确要求"主菜单统一为匹配对战"，但当前仍分散为多个入口。没有 LAN 专用按钮。
**建议**: 统一为一个"匹配对战"入口

### 4.2 🟡 缺少生命周期暂停
**问题**: 全局搜索 `WidgetsBindingObserver` 返回 0 结果。游戏切到后台不会自动暂停。
**影响**: 对战中被电话/通知打断会导致角色自动死亡，极易差评
**修复**: 在 GameScreen 中 implement WidgetsBindingObserver，在 `didChangeAppLifecycleState` 中暂停/恢复游戏

### 4.3 🟡 设置按钮无功能
**文件**: `lib/screens/main_menu.dart:190-192`  
**问题**: 设置按钮 `onPressed: () {}` 是空操作
**影响**: 用户预期有音效开关、语言切换等功能

### 4.4 🟡 多处 print() 残留在生产代码中
**文件**: `lib/network/game_client.dart`, `lib/screens/game_screen.dart` (共 20+ 处)  
**问题**: 所有 `print()` 调用输出到控制台，iOS App Store 构建中不应有调试输出
**修复**: 替换为条件日志（仅在 debug mode）

### 4.5 🟡 触摸控件适配问题
**文件**: `lib/game/components/touch_controls.dart`  
**问题**: 摇杆和按钮使用硬编码位置 (100,480 / 1140,480)，在 iPhone SE vs iPhone 15 Pro Max 上体验差异大
**修复**: 使用 `onGameResize` 动态计算，按屏幕百分比定位

### 4.6 🟡 缺少返回确认
**问题**: 游戏中按系统返回键直接退出，没有"确认退出"对话框
**影响**: 误触导致对战中断

### 4.7 🟡 缺少音效开关/音量控制
**问题**: SoundManager 实现了但主菜单没有音效开关
**影响**: 公共场合无法静音

### 4.8 🟡 缺少震动反馈 (Haptic)
**问题**: 无 Haptic 反馈，打击感纯靠画面
**建议**: 关键操作（攻击命中、技能释放、被击中、胜利）添加震动

### 4.9 🟡 游戏结果界面简陋
**问题**: 没有击杀回放、战斗统计、伤害详情等
**建议**: 添加战斗数据面板（总伤害、连击数、技能命中率）

### 4.10 🟡 英雄选择界面性能
**文件**: `lib/screens/hero_select.dart` (987行)  
**问题**: 单个文件过长，界面上动画较多（glow controller），可能在低端设备卡顿

---

## 五、性能与稳定性审计

### 5.1 🟡 服务端配置硬编码
**文件**: `lib/config/app_config.dart:21`  
**问题**: 生产环境 URL 硬编码为 `herofight-production.up.railway.app`  
**风险**: Railway 可能随时回收免费实例，URL 变更需要客户端更新

### 5.2 🟡 缺少 Crash 报告
**问题**: 无 Firebase Crashlytics / Sentry 集成  
**影响**: 无法追踪线上崩溃

### 5.3 🟡 缺少性能监控
**问题**: 无 FPS 监控、内存泄漏检测  
**建议**: 集成 Firebase Performance 或至少添加 FPS 计数器（debug overlay 已有）

### 5.4 🟡 网络断开处理不够健壮
**问题**: 对手断线时只有 SnackBar 提示，没有自动重连机制
**影响**: 在线对战体验差

### 5.5 🟡 符号化崩溃日志
**问题**: iOS 需要 dSYM 文件来符号化崩溃日志。Flutter 默认不生成。
**修复**: 构建时添加 `--split-debug-info` 参数

### 5.6 🟡 缺少单元测试覆盖
**文件**: `test/` 目录有 11 个测试文件  
**问题**: 但代码覆盖率未知。战斗逻辑、网络同步、回滚引擎缺乏充分测试。

---

## 六、安全与隐私合规审计

### 6.1 🔴 客户端可保存任意战绩
**文件**: `server/index.js:55-65`  
**问题**: `/api/game_record` 端点接受客户端直接 POST 战绩数据，没有签名验证。恶意用户可伪造任何战绩。
**修复**: 添加 HMAC 签名或使用服务器权威验证

### 6.2 🔴 device_id 明文传输
**文件**: `lib/data/device_id.dart`  
**问题**: 设备 ID 作为玩家标识明文传输，可以被抓包获取
**建议**: 使用 UUID v4 随机生成，不与硬件 ID 绑定

### 6.3 🟡 WebSocket 连接无认证
**文件**: `server/index.js`  
**问题**: WebSocket 连接无任何认证机制，任何客户端都可连接
**建议**: 添加 token 认证

### 6.4 🟡 LAN 发现安全性
**问题**: UDP 广播发现无加密，局域网内可被中间人攻击
**建议**: 对于本地游戏场景可接受，但需在隐私政策中说明

### 6.5 🟡 缺少数据删除机制
**问题**: 没有用户数据删除的途径，GDPR/CCPA 合规缺失
**修复**: 添加数据删除 API 或在隐私政策中说明联系邮箱

---

## 七、后端与网络问题

### 7.1 🟡 服务端内存泄漏风险
**文件**: `server/index.js`  
**问题**: rooms Map 和 clients Map 的清理逻辑不够健壮。IDLE_ROOM_TIMEOUT = 300000 (5分钟) 偏长。
**建议**: 缩短超时时间，确保断连立即清理

### 7.2 🟡 缺少速率限制
**问题**: API 端点没有 rate limiting，可以被 DDoS
**修复**: 添加 express-rate-limit 中间件

### 7.3 🟡 服务端无健康检查自动恢复
**问题**: Railway 的免费实例会休眠，客户端需要处理连接超时

---

## 八、优先修复排序

### P0 — App Store 阻止上线 (必须修复)
1. 编译错误 (1.1-1.4)
2. 隐私清单 (2.3)  
3. 隐私政策 URL (2.9)
4. iOS 方向配置 (2.1, 2.2)
5. 应用图标 + 启动画面 (2.7, 2.8)
6. iOS 部署目标升级 (2.5)
7. App Store 元数据 (2.10)

### P1 — 严重影响用户体验
8. 生命周期暂停 (4.2)
9. 打印日志清理 (4.4)
10. 游戏内返回确认 (4.6)
11. 客户端战绩伪造 (6.1)
12. 英雄选择界面 TabBar 安全 (确保 3 阵营各 4 英雄)
13. 服务端认证 (6.3)

### P2 — 平衡性与体验优化
14. 诸葛亮/蚩尤平衡性调整 (3.2)
15. 新手引导完善 (3.3)
16. 音效开关 (4.7)
17. 设置按钮功能 (4.3)
18. 触摸控件适配 (4.5)
19. 战绩防篡改 (6.1)

### P3 — 长期留存与品质
20. 游戏进度系统
21. 战斗数据面板
22. Crash 报告集成
23. Haptic 反馈
24. 数据删除机制 (GDPR)
