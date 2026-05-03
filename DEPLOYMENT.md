# Hero Fighter 部署方案 & iOS 海外上架指南

---

## 一、项目架构总览

```
┌─────────────────────────────────────────────────┐
│                   客户端 (Flutter)                │
│  Web / iOS / Android / macOS / Windows / Linux   │
│  WebSocket 连接到游戏服务器                        │
└──────────────────┬──────────────────────────────┘
                   │ ws://your-domain:3000
┌──────────────────▼──────────────────────────────┐
│              游戏服务器 (Node.js)                  │
│  Express + WebSocket + UDP LAN Discovery         │
│  端口: 3000 (HTTP+WS), 3001 (UDP)               │
└─────────────────────────────────────────────────┘
```

---

## 二、服务器部署方案

### 方案 A：云服务器直接部署（推荐入门）

适合：个人开发者、小规模测试

**1. 购买云服务器**
- 推荐：AWS Lightsail / DigitalOcean / Vultr / 阿里云国际版
- 配置：1 核 1G 内存即可（单服务器支撑 ~500 并发连接）
- 系统：Ubuntu 22.04 LTS
- 地区：选择目标用户所在区域（美西/东京/新加坡）

**2. 服务器环境配置**

```bash
# 安装 Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# 上传项目
scp -r server/ user@your-server:/opt/hero-fighter/

# 安装依赖
cd /opt/hero-fighter && npm install --production

# 使用 PM2 管理进程
sudo npm install -g pm2
pm2 start index.js --name hero-fighter
pm2 save
pm2 startup
```

**3. Nginx 反向代理 + SSL**

```nginx
server {
    listen 443 ssl;
    server_name game.yourdomain.com;

    ssl_certificate     /etc/letsencrypt/live/game.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/game.yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 86400;
    }
}
```

```bash
# 安装 Nginx + Let's Encrypt
sudo apt install nginx certbot python3-certbot-nginx
sudo certbot --nginx -d game.yourdomain.com
```

**4. 防火墙**

```bash
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 3001/udp
sudo ufw enable
```

---

### 方案 B：Docker 部署（推荐生产环境）

项目已有 `docker-compose.yml`，需补充 Dockerfile：

**server/Dockerfile**

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY index.js .
EXPOSE 3000 3001/udp
CMD ["node", "index.js"]
```

**部署步骤**

```bash
# 构建并启动
docker compose up -d --build

# 查看日志
docker compose logs -f game-server

# 健康检查
curl http://localhost:3000/health
```

---

### 方案 C：平台托管（零运维）

| 平台 | WebSocket 支持 | 免费额度 | 适合场景 |
|------|---------------|---------|---------|
| Railway | ✅ | $5/月 | 快速上线 |
| Render | ✅ | 免费层有限 | 小规模 |
| Fly.io | ✅ | 免费 3 个小实例 | 全球边缘部署 |
| AWS ECS | ✅ | 按量付费 | 大规模 |

**Fly.io 示例（全球边缘节点）**

```bash
# 安装 flyctl
curl -L https://fly.io/install.sh | sh

cd server
fly launch --name hero-fighter-server
fly deploy
fly status
```

---

### 客户端连接配置

当前客户端 Web 端自动使用 `Uri.base` 连接同源服务器。
iOS/Android 原生端需要配置服务器地址：

```
matching_screen.dart 行 191-192:
  非 Web 端通过 widget.serverAddress 或 LAN 发现连接
```

**生产环境建议**：在 `matching_screen.dart` 中添加生产服务器地址常量：

```dart
const kProductionServer = 'game.yourdomain.com';
```

iOS 端需要使用 `wss://`（加密 WebSocket），因为 App Store 要求 ATS 合规。

---

## 三、各平台构建命令

| 平台 | 构建命令 | 产物位置 |
|------|---------|---------|
| Web | `flutter build web --release` | `build/web/` |
| iOS | `flutter build ipa --release` | `build/ios/ipa/` |
| Android | `flutter build appbundle --release` | `build/app/outputs/bundle/release/` |
| macOS | `flutter build macos --release` | `build/macos/Build/Products/Release/` |

---

## 四、iOS 海外上架完整流程

### 第一阶段：准备工作

#### 1. Apple Developer 账号

- 访问 https://developer.apple.com/programs/
- 注册 Apple Developer Program（$99/年）
- 个人账号或公司账号均可（公司账号需要 D-U-N-S 编号）
- 注册后等待审核通过（通常 24-48 小时）

#### 2. 证书和描述文件

**在 Mac 上操作：**

```bash
# 方式一：Xcode 自动管理（推荐）
# 打开 Xcode → Runner.xcworkspace
# Signing & Capabilities → 勾选 "Automatically manage signing"
# 选择你的 Team

# 方式二：手动创建
# 1. Keychain Access → Certificate Assistant → Request a Certificate
# 2. developer.apple.com → Certificates → 创建 Distribution Certificate
# 3. 创建 App ID: com.herofighter.heroFighter
# 4. 创建 Provisioning Profile (App Store Distribution)
```

#### 3. App Store Connect 创建 App

1. 登录 https://appstoreconnect.apple.com
2. 「我的 App」→ 「+」→ 「新建 App」
3. 填写信息：
   - 平台：iOS
   - 名称：Hero Fighter（英文名，海外上架）
   - 主要语言：English (U.S.)
   - Bundle ID：com.herofighter.heroFighter
   - SKU：hero-fighter-001

---

### 第二阶段：项目配置

#### 1. 修改 Bundle ID 和版本号

```bash
# pubspec.yaml
version: 1.0.0+1   # 格式: 版本号+构建号
```

#### 2. Xcode 项目配置

```bash
cd /Users/guoyuli/Documents/code_s/hero_fighter
open ios/Runner.xcworkspace
```

在 Xcode 中检查：
- **General → Identity**
  - Display Name: Hero Fighter
  - Bundle Identifier: com.herofighter.heroFighter
  - Version: 1.0.0
  - Build: 1
- **General → Deployment Info**
  - iOS 15.0+（推荐最低版本）
  - Device: iPhone + iPad
- **Signing & Capabilities**
  - Team: 选择你的开发者账号
  - Automatically manage signing: ✅

#### 3. App Icons

需要准备 1024×1024 的 App 图标，放入：
```
ios/Runner/Assets.xcassets/AppIcon.appiconset/
```

可以用 https://appicon.co 一键生成所有尺寸。

#### 4. 启动画面

```
ios/Runner/Assets.xcassets/LaunchImage.imageset/
```

或使用 Storyboard 自定义启动画面（`ios/Runner/LaunchScreen.storyboard`）。

#### 5. Info.plist 权限声明

本项目使用网络功能，需确认 `ios/Runner/Info.plist`：

```xml
<!-- 网络访问（iOS 默认允许，无需额外声明） -->
<!-- 如果使用 LAN 发现功能，需要添加： -->
<key>NSLocalNetworkUsageDescription</key>
<string>Used to discover game servers on your local network</string>
<key>NSBonjourServices</key>
<array>
    <string>_herofighter._udp</string>
</array>
```

#### 6. App Transport Security（重要）

iOS 要求所有网络连接使用 HTTPS/WSS。确保：
- 生产服务器配置了 SSL 证书
- WebSocket 使用 `wss://` 而非 `ws://`

如果暂时需要允许 HTTP（仅开发阶段）：
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```
⚠️ 上架时 Apple 审核可能拒绝 `NSAllowsArbitraryLoads`，生产环境必须用 HTTPS。

---

### 第三阶段：构建和上传

#### 1. Flutter 构建 IPA

```bash
cd /Users/guoyuli/Documents/code_s/hero_fighter

# 清理旧构建
flutter clean
flutter pub get

# 构建 Release IPA
flutter build ipa --release

# 产物位置
# build/ios/ipa/hero_fighter.ipa
```

#### 2. 上传到 App Store Connect

**方式一：Xcode（推荐）**

```bash
open ios/Runner.xcworkspace
# Xcode → Product → Archive
# Archive 完成后 → Distribute App → App Store Connect → Upload
```

**方式二：命令行**

```bash
# 安装 Transporter（Mac App Store 免费下载）
# 或使用 xcrun：
xcrun altool --upload-app \
  --type ios \
  --file build/ios/ipa/hero_fighter.ipa \
  --apiKey YOUR_API_KEY \
  --apiIssuer YOUR_ISSUER_ID
```

**方式三：Transporter App**

从 Mac App Store 下载 Transporter，拖入 .ipa 文件即可上传。

---

### 第四阶段：App Store Connect 填写信息

#### 1. App 信息页

| 字段 | 填写内容 |
|------|---------|
| 名称 | Hero Fighter |
| 副标题 | Online Multiplayer Fighting Game |
| 类别 | Games → Action |
| 次要类别 | Games → Fighting |
| 内容权限 | 无第三方内容 |

#### 2. 版本信息

| 字段 | 填写内容 |
|------|---------|
| 宣传文本 | Epic 2D fighting game with 11 unique heroes! |
| 描述 | （见下方模板） |
| 关键词 | fighting,multiplayer,action,hero,battle,2d,pvp,online |
| 支持 URL | 你的网站或 GitHub Pages |
| 营销 URL | 可选 |

**描述模板（英文）：**

```
Hero Fighter is an action-packed 2D multiplayer fighting game 
featuring 11 unique heroes from Chinese mythology and history.

FEATURES:
• 11 Heroes with unique abilities, combos, and fighting styles
• Online PvP multiplayer with real-time matchmaking
• Directional attacks - combine movement with attacks for special moves
• Combo system with multi-hit chains
• Beautiful hand-crafted character animations
• Cross-platform play

HEROES:
Warriors from the Three Kingdoms, mythological figures, 
and legendary strategists - each with distinct skills and playstyles.

Challenge players worldwide in fast-paced 1v1 battles!
```

#### 3. 截图要求

| 设备 | 尺寸 | 数量 |
|------|------|------|
| iPhone 6.7" (必须) | 1290 × 2796 | 3-10 张 |
| iPhone 6.5" (必须) | 1284 × 2778 或 1242 × 2688 | 3-10 张 |
| iPad 12.9" (如支持) | 2048 × 2732 | 3-10 张 |

截图建议内容：
1. 主菜单界面
2. 英雄选择界面
3. 战斗画面（展示攻击特效）
4. 在线匹配界面
5. 连击/技能释放瞬间

可以用模拟器截图：
```bash
# 启动 iOS 模拟器
flutter run -d "iPhone 15 Pro Max"
# 模拟器菜单 → File → Save Screen (Cmd+S)
```

#### 4. 年龄分级

在 App Store Connect 填写年龄分级问卷：
- 暴力卡通或幻想暴力：**偶尔/轻微**（格斗游戏）
- 真实暴力：无
- 赌博：无
- 在线多人：**是**（需要标注）

预计分级：**9+** 或 **12+**

#### 5. 审核信息

- 联系人信息：你的邮箱和电话
- 备注（给审核员）：
```
This is a 2D fighting game with online multiplayer.
To test multiplayer: open two instances and use "Online Match".
Single player mode is also available from the main menu.
Server: wss://game.yourdomain.com
```
- 如果需要登录：本游戏无需登录

---

### 第五阶段：提交审核

1. 在 App Store Connect 选择已上传的构建版本
2. 确认所有必填信息已完成（截图、描述、分级等）
3. 点击「提交审核」

**审核时间线：**
- 首次提交：通常 24-48 小时
- 更新版本：通常 24 小时内
- 被拒后重新提交：24-48 小时

---

### 第六阶段：常见审核被拒原因及应对

| 被拒原因 | 解决方案 |
|---------|---------|
| **4.0 Design - Minimum Functionality** | 确保游戏有足够内容，11 个英雄 + 在线对战应该足够 |
| **2.1 Performance - App Completeness** | 确保服务器在审核期间正常运行 |
| **2.3.1 Performance - Accurate Metadata** | 截图必须是真实游戏画面 |
| **5.1.1 Legal - Data Collection** | 添加隐私政策页面（即使不收集数据也需要） |
| **NSAllowsArbitraryLoads** | 必须使用 HTTPS/WSS |
| **IPv6 兼容性** | Flutter 默认支持，一般不会有问题 |

**隐私政策**：即使不收集任何用户数据，也必须提供隐私政策 URL。
可以用 https://app-privacy-policy-generator.firebaseapp.com 免费生成。

---

### 上架后运营

#### 版本更新流程

```bash
# 1. 修改版本号
# pubspec.yaml: version: 1.1.0+2

# 2. 构建
flutter build ipa --release

# 3. 上传 + 提交审核（同上）
```

#### 监控

- App Store Connect → Analytics 查看下载量
- 服务器 `/health` 端点监控
- PM2 / Docker 日志监控

---

## 五、快速上线检查清单

### 服务器端
- [ ] 云服务器已购买并配置
- [ ] Node.js + PM2 已安装
- [ ] Nginx + SSL 证书已配置
- [ ] 防火墙已开放 443/3001 端口
- [ ] `curl https://game.yourdomain.com/health` 返回 ok
- [ ] WebSocket `wss://` 连接测试通过

### iOS 客户端
- [ ] Apple Developer 账号已注册
- [ ] Bundle ID 已确认
- [ ] App Icons 1024×1024 已准备
- [ ] 客户端 WebSocket 地址改为 `wss://game.yourdomain.com`
- [ ] `flutter build ipa --release` 构建成功
- [ ] Xcode Archive + Upload 成功
- [ ] App Store Connect 信息已填写完整
- [ ] 截图已上传（6.7" + 6.5" 必须）
- [ ] 隐私政策 URL 已配置
- [ ] 年龄分级已填写
- [ ] 提交审核
