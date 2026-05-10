# Hero Fighter — iOS App Store 发布流程指南

> 项目: hero_fighter | 版本: 1.0.0 | 日期: 2026-05-08
> 技术栈: Flutter 3.x + Flame | 服务端: Node.js + Railway

---

## 目录

1. [前置准备](#1-前置准备)
2. [Apple Developer 账号](#2-apple-developer-账号)
3. [App Store Connect 配置](#3-app-store-connect-配置)
4. [项目最终检查](#4-项目最终检查)
5. [构建与归档](#5-构建与归档)
6. [TestFlight 内测](#6-testflight-内测)
7. [提交审核](#7-提交审核)
8. [审核期间](#8-审核期间)
9. [上线后](#9-上线后)
10. [常见拒审原因](#10-常见拒审原因)

---

## 1. 前置准备

### 1.1 硬件要求

- [ ] Mac 电脑（macOS 最新或上一个大版本）
- [ ] Xcode 最新稳定版（App Store 下载）
- [ ] 至少 20GB 可用磁盘空间

### 1.2 软件安装

```bash
# 确保 Flutter 环境正常
flutter doctor -v

# 确保 Xcode 命令行工具已安装
xcode-select --install

# 安装 CocoaPods（iOS 依赖管理）
sudo gem install cocoapods
```

### 1.3 项目已完成的优化

本项目已通过 6 个 Phase、47 项优化：

| Phase | 内容 | 状态 |
|-------|------|------|
| 01 | 致命修复（HUD/防御/音频/性能/屏幕自适应） | ✅ |
| 02 | 核心重构（FighterGame拆分/服务端模块化/跳跃/安全） | ✅ |
| 03 | 体验提升（i18n/AI强化/RTT自适应） | ✅ |
| 04 | 完善打磨（注释/渲染裁剪/阴影/触觉/教程） | ✅ |
| 05 | iOS上线合规（Info.plist/PrivacyInfo/音频/测试） | ✅ |
| 06 | App Store最终审核（隐私政策/支持URL/安全/图标） | ✅ |

---

## 2. Apple Developer 账号

### 2.1 注册

1. 访问 [developer.apple.com](https://developer.apple.com)
2. 点击 "Account" → "Enroll"
3. 选择 **Apple Developer Program**（$99/年）
4. 填写组织信息（个人或公司）
5. 支付年费
6. 等待审核确认邮件（通常 1-2 天）

### 2.2 生成证书

```bash
# 打开 Xcode → Settings → Accounts
# 添加你的 Apple ID
# 点击 "Manage Certificates" → "+" → "Apple Development"
# 同样生成 "Apple Distribution" 证书
```

或使用自动签名（推荐）：

> Xcode → 项目 → Signing & Capabilities → 勾选 "Automatically manage signing"

### 2.3 创建 App ID

1. 登录 [developer.apple.com/account](https://developer.apple.com/account)
2. Certificates, Identifiers & Profiles → Identifiers
3. 点击 "+" → App IDs
4. Bundle ID: `com.herofighter.heroFighter`（**必须与 Xcode 项目一致**）
5. 勾选需要的 Capabilities（本项目无需特殊 Capability）

---

## 3. App Store Connect 配置

### 3.1 创建 App 记录

1. 登录 [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. 点击 "My Apps" → "+" → "New App"
3. 填写：

| 字段 | 值 |
|------|-----|
| Platform | iOS |
| Name | **Hero Fighter** |
| Primary Language | Simplified Chinese |
| Bundle ID | `com.herofighter.heroFighter` |
| SKU | `hero_fighter_ios_001` |
| User Access | Full Access |

### 3.2 必须填写的 App 信息

#### App 信息

| 字段 | 内容 |
|------|------|
| 名称 | Hero Fighter |
| 副标题 | 12 Heroes Fighting Game |
| 类别 | Games → Action, Games → Fighting |
| 年龄分级 | 12+（含卡通/幻想暴力） |
| 隐私政策 URL | `https://herofight-production.up.railway.app/privacy` |
| 支持 URL | `https://herofight-production.up.railway.app/support` |

#### 版本信息

| 字段 | 内容 |
|------|------|
| 版本号 | 1.0.0 |
| 宣传文本 | Epic 2D fighting game with 12 unique heroes and online multiplayer |
| 描述 | 见下方模板 |
| 关键词 | 格斗,对战,英雄,街机,action,hero,fighter,battle,multiplayer |

#### App 描述（中英文）

```
【中文】
Hero Fighter 是一款热血 2D 格斗游戏，12 位来自三国、神话和战国的英雄等你驾驭！

游戏特色：
• 12 位独特英雄 — 吕布、关羽、诸葛亮、荆轲、后羿…各有专属技能
• 在线实时对战 — GGPO 回滚网络代码，低延迟流畅对战
• 局域网联机 — 同一 WiFi 下自动发现对手
• AI 对战 — 三种难度，随时练习
• 精美像素特效 — 粒子系统、屏幕震动、连击计数
• 战绩排行榜 — 全球玩家排位

拿起武器，成为最强英雄！

【English】
Hero Fighter is a 2D fighting game featuring 12 heroes from Chinese mythology and history.

Features:
• 12 Unique Heroes — each with special skills and combos
• Online Multiplayer — GGPO rollback netcode for smooth matches
• LAN Battle — auto-discover opponents on same WiFi
• AI Opponents — 3 difficulty levels for practice
• Visual Effects — particle system, screen shake, combo counter
• Global Leaderboard — compete with players worldwide

Choose your hero and fight!
```

### 3.3 截图要求

| 设备 | 尺寸 | 数量 |
|------|------|------|
| iPhone 6.7" (Pro Max) | 1290×2796 | 至少 3 张 |
| iPhone 6.5" (Pro) | 1284×2778 | 至少 3 张 |
| iPhone 5.5" (Plus) | 1242×2208 | 至少 3 张 |

**截图内容建议：**
1. 主菜单界面（展示游戏标题和模式选择）
2. 英雄选择界面（展示英雄阵容和阵营）
3. 对战画面（展示 HUD/特效/技能）
4. 战绩排行榜界面
5. 在线匹配界面

### 3.4 App 审核信息

| 字段 | 值 |
|------|-----|
| 登录信息 | **不需要**（无需账号登录） |
| 联系人 | 你的姓名 + 邮箱 + 电话 |
| 备注 | 可附上游戏特色说明、测试环境说明 |
| 加密出口 | 勾选"是"，但声明使用标准加密（ITSAppUsesNonExemptEncryption = false） |

---

## 4. 项目最终检查

### 4.1 代码层面

```bash
cd /Users/guoyuli/Documents/code_s/hero_fighter

# 1. 确保所有测试通过
flutter test
# 预期: All tests passed! (233/233)

# 2. 静态分析 0 错误
flutter analyze
# 预期: No issues found!

# 3. 确保生产环境配置
cat lib/config/app_config.dart | grep environment
# 预期: static const Environment environment = Environment.production;
```

### 4.2 iOS 配置文件

```bash
# 检查 Info.plist 关键项
cat ios/Runner/Info.plist | grep -E "CFBundleDisplayName|ITSAppUsesNonExempt|NSAppTransport|UISupportedInterface"
```

预期输出应包含：
- `CFBundleDisplayName` = "Hero Fighter"
- `ITSAppUsesNonExemptEncryption` = false
- `NSAppTransportSecurity` → `NSAllowsLocalNetworking` = true
- 横屏锁定（Landscape Left/Right）

### 4.3 图标检查

```bash
file ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
# 预期: 8-bit/color RGBA (真彩色，非 colormap)
```

### 4.4 服务端就绪

```bash
# 确认 Railway 部署的服务端可访问
curl -s https://herofight-production.up.railway.app/health
# 预期: {"status":"ok","rooms":0,"clients":0,"queue":0}
```

---

## 5. 构建与归档

### 5.1 清理构建

```bash
cd /Users/guoyuli/Documents/code_s/hero_fighter

# 清理
flutter clean
flutter pub get

# iOS 依赖
cd ios
pod install --repo-update
cd ..
```

### 5.2 构建 Release 版本

```bash
# 方式一：使用 Flutter 命令
flutter build ios --release

# 方式二：使用 Xcode（推荐）
flutter build ios --release --no-codesign
# 然后打开 Xcode 进行 Archive
```

### 5.3 Xcode Archive 步骤

1. 打开 `ios/Runner.xcworkspace`（**注意：是 .xcworkspace 不是 .xcodeproj**）
2. 选择顶部的 Scheme: **Runner**
3. 选择目标设备: **Any iOS Device (arm64)**
4. 菜单: **Product → Archive**
5. 等待构建完成（约 5-15 分钟）

### 5.4 常见构建问题

| 问题 | 解决方案 |
|------|----------|
| `No such module 'Flutter'` | 确保打开的是 `.xcworkspace` 而非 `.xcodeproj` |
| 签名错误 | Xcode → Signing & Capabilities → 选择正确的 Team |
| `Bitcode` 错误 | 本项目已禁用 Bitcode |
| 架构不匹配 | 确保目标设备选 "Any iOS Device" 而非模拟器 |

---

## 6. TestFlight 内测

### 6.1 上传到 TestFlight

1. Xcode Archive 完成后 → **Distribute App**
2. 选择 **App Store Connect** → **Upload**
3. 勾选所有选项 → **Next** → **Upload**
4. 等待上传完成（约 5-10 分钟）

### 6.2 配置 TestFlight

1. 登录 App Store Connect → 你的 App → TestFlight
2. 等待 Apple 处理（约 30 分钟 - 2 小时）
3. 处理完成后，Build 状态显示 "Ready to Test"

### 6.3 添加测试人员

**内部测试（最多 100 人）：**
1. App Store Connect → Users and Access → 添加用户
2. 赋予 Developer 或 App Manager 角色
3. TestFlight → Internal Testing → 选择 Build → 添加测试人员

**外部测试（最多 10,000 人）：**
1. TestFlight → External Testing → 创建新群组
2. 需要填写 Beta App Review 信息（会被 Apple 审核）
3. 分享公开链接给测试人员

### 6.4 测试重点

- [ ] 所有模式可正常进入（AI/本地/在线/LAN）
- [ ] 12 英雄可正常选择和对战
- [ ] 战斗 HUD 显示正确（血条/冷却/连击/倒计时）
- [ ] 音效可正常播放和关闭
- [ ] 在线匹配正常（需服务端在线）
- [ ] 网络断开后有友好提示
- [ ] App 后台恢复正常
- [ ] 横竖屏锁定正确
- [ ] iPad 适配正常

---

## 7. 提交审核

### 7.1 构建版本选择

1. App Store Connect → 你的 App
2. 左侧选择 **App Store** 标签
3. 在 "iOS App" 部分，找到 "Build" 区域
4. 点击 "+" 选择 TestFlight 中已通过的 Build

### 7.2 提交前最终检查清单

```
[ ] App 描述（中英文）已填写
[ ] 截图已上传（至少 3 套尺寸，各 3 张以上）
[ ] 隐私政策 URL 可访问
[ ] 支持 URL 可访问
[ ] 年龄分级已完成
[ ] 加密出口声明已设置
[ ] 版本号正确（1.0.0）
[ ] 版权信息填写（© 2026 Your Name）
[ ] 演示账号（如需要）已提供
[ ] 审核备注已填写（建议：说明游戏玩法、网络功能、无内购）
```

### 7.3 提交

1. 确保所有带红色感叹号的必填项已填写
2. 点击右上角 **"Submit for Review"**
3. 回答三个问题：
   - Export Compliance: **Yes** (uses standard encryption)
   - Content Rights: **Yes** (you own all content)
   - Advertising Identifier: **No** (IDFA not used)

---

## 8. 审核期间

### 8.1 审核时间

- 通常 **24-48 小时**
- 可能 1-2 周（高峰期或新账号）
- TestFlight Beta Review 通常更快（24 小时内）

### 8.2 确保审核通过的关键事项

| 检查项 | 说明 |
|--------|------|
| 🔴 服务端在线 | 审核人员会实际使用 App。**审核期间务必保持 Railway 服务端运行** |
| 🔴 功能完整 | 不要有 "Coming Soon" 或未完成功能 |
| 🔴 无崩溃 | 所有流程测试通过 |
| 🟡 数据声明 | PrivacyInfo 声明与实际采集一致 |
| 🟡 无隐藏功能 | 不要使用隐藏开关切换环境 |

### 8.3 审核被拒应对

如果收到拒绝邮件：
1. 仔细阅读拒审原因
2. 在 App Store Connect → Resolution Center 回复
3. 修复问题后重新提交（不需要新建版本）

参见 [第 10 节：常见拒审原因](#10-常见拒审原因)

---

## 9. 上线后

### 9.1 发布

审核通过后：
1. App Store Connect → 你的 App
2. 可以选择 **"手动发布"** 或 **"自动发布"**
3. 建议选择手动发布，在确认一切就绪后点击 "Release"

### 9.2 监控

- App Store Connect → App Analytics：查看下载量、崩溃率
- 服务端日志：监控在线人数、匹配队列
- 用户评价：及时回复 App Store 评论

### 9.3 后续版本

```bash
# 修改版本号
# pubspec.yaml: version: 1.1.0+2

# 然后在 App Store Connect 创建新版本
```

---

## 10. 常见拒审原因

### 10.1 本项目已修复

| 问题 | 状态 |
|------|------|
| 缺少 `ITSAppUsesNonExemptEncryption` | ✅ 已修复 |
| PrivacyInfo 数据声明为空 | ✅ 已修复 |
| 缺少隐私政策 URL | ✅ 已创建 `web/privacy.html` |
| 硬编码密钥暴露 | ✅ 已改为 null |
| 图标为 8-bit colormap | ✅ 已生成 32-bit RGBA |
| IPv6 网络崩溃 | ✅ 已添加 IPv6 fallback |
| App 描述为 placeholder | ✅ 已更新 pubspec.yaml |
| 网络断开无提示 | ✅ 已添加友好提示 |

### 10.2 其他可能注意

| 拒审原因 | 说明 | 本项目的应对 |
|----------|------|-------------|
| 2.1 App Completeness | 不能是 demo/beta 质量 | ✅ 全功能完成 |
| 2.3 元数据不准确 | 截图/描述与实际一致 | ⚠️ 截图需真实截取 |
| 3.1.1 内购 | 如有虚拟商品需走 IAP | ✅ 无内购 |
| 4.0 设计 | 最低设计质量标准 | ✅ HUD/UI 完善 |
| 4.2 最低功能 | 不能只是网页套壳 | ✅ 原生 Flutter |
| 5.1.1 数据收集 | 需用户同意 + 隐私政策 | ✅ PrivacyInfo 已声明 |
| 5.6 开发者代码 | 不能使用私有 API | ✅ 无私有 API 调用 |

---

## 附录 A：文件清单

```
hero_fighter/
├── ios/
│   └── Runner/
│       ├── Info.plist                    ✅ 已配置加密+ATS
│       ├── PrivacyInfo.xcprivacy         ✅ 已声明数据采集
│       └── Assets.xcassets/
│           └── AppIcon.appiconset/       ✅ 15个真彩色图标
├── lib/
│   ├── config/app_config.dart            ✅ 生产环境+密钥托管
│   ├── game/                             ✅ 6 Phase优化完成
│   └── network/                          ✅ IPv6+友好提示
├── web/
│   ├── privacy.html                      ✅ 隐私政策页面
│   └── support.html                      ✅ 技术支持页面
├── server/
│   ├── index.js                          ✅ 模块化拆分
│   ├── .env.example                      ✅ 环境变量模板
│   └── Dockerfile                        ✅ Docker部署
├── test/                                 ✅ 233测试全通过
└── pubspec.yaml                          ✅ 描述已更新
```

## 附录 B：快速命令参考

```bash
# 测试
flutter test

# 静态分析
flutter analyze

# iOS 构建
flutter build ios --release

# 打开 Xcode
open ios/Runner.xcworkspace

# 检查服务端
curl https://herofight-production.up.railway.app/health

# 图标验证
file ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
```

---

> 📋 本指南涵盖从构建到上线的完整流程。如遇问题，参考 [Apple 官方文档](https://developer.apple.com/app-store/review/guidelines/)。
