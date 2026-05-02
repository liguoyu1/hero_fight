# Hero Fighter Server — Railway 部署指南

## 1. 前置条件

- [GitHub 账号](https://github.com)
- [Railway 账号](https://railway.app)（可用 GitHub 登录，免费额度 $5/月）
- 代码已推送到 GitHub 仓库

## 2. 项目结构准备

Railway 需要 `server/` 目录作为独立项目。有两种方式：

### 方式 A：Monorepo（推荐）

在 `server/` 目录下创建 `railway.json`：

```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS",
    "buildCommand": "npm install"
  },
  "deploy": {
    "startCommand": "node index.js",
    "healthcheckPath": "/health",
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}
```

### 方式 B：独立仓库

将 `server/` 目录内容复制到独立仓库的根目录。

## 3. Railway 部署步骤

### 3.1 创建项目

1. 登录 [Railway Dashboard](https://railway.app/dashboard)
2. 点击 **"New Project"**
3. 选择 **"Deploy from GitHub repo"**
4. 选择 `liguoyu1/hero_fight` 仓库

### 3.2 配置 Root Directory

在 Railway 项目设置中：

1. 点击 **"Settings"** → **"Root Directory"**
2. 设置为 `server`（重要！让 Railway 从 server 目录构建）

### 3.3 配置环境变量

在 Railway **"Variables"** 标签页添加：

| 变量名 | 值 | 说明 |
|--------|-----|------|
| `NODE_ENV` | `production` | 生产环境 |
| `PORT` | `3000` | WebSocket 端口（Railway 自动映射） |
| `UDP_PORT` | `3001` | LAN 发现端口 |

### 3.4 配置端口

在 Railway **"Settings"** → **"Networking"** 中：

- Railway 会自动检测 `PORT` 环境变量
- 确保 **Public Networking** 已启用
- 获取公网域名：`xxx.up.railway.app`

### 3.5 部署

1. Railway 会自动从 GitHub 拉取代码并部署
2. 首次部署约 1-2 分钟
3. 部署完成后，在 **"Deployments"** 标签页查看日志

## 4. 客户端配置

部署成功后，修改 Flutter 客户端连接地址：

### 4.1 找到服务器 URL

在 Railway Dashboard 中获取域名，格式：
```
https://hero-fighter-server-production.up.railway.app
```

### 4.2 修改客户端代码

在 `lib/network/game_client.dart` 中：

```dart
// 替换 LAN 发现为在线连接
static const String onlineServerUrl = 'wss://hero-fighter-server-production.up.railway.app';
```

或在匹配界面输入服务器地址。

### 4.3 使用 wss:// 协议

Railway 自动提供 HTTPS，WebSocket 使用 `wss://`（安全 WebSocket）。

## 5. 验证部署

### 5.1 健康检查

浏览器访问：
```
https://your-app.up.railway.app/health
```

预期响应：
```json
{"status":"ok","rooms":0,"clients":0,"queue":0}
```

### 5.2 API 测试

```bash
# 查看排行榜
curl https://your-app.up.railway.app/api/leaderboard?limit=10

# 查看玩家统计
curl https://your-app.up.railway.app/api/stats/your-device-id
```

### 5.3 WebSocket 测试

使用 [wscat](https://github.com/websockets/wscat)：
```bash
npm install -g wscat
wscat -c wss://your-app.up.railway.app
```

连接后发送：
```json
{"type": "connected"}
```

## 6. 注意事项

### 6.1 UDP 端口限制

Railway **不支持 UDP 端口**，LAN 发现功能在云端不可用。
- LAN 模式：仅在本地网络有效
- Online 模式：使用 WebSocket 直连，不需要 UDP

### 6.2 免费额度限制

- Railway 免费计划：$5/月 额度
- 此服务器资源消耗极低（Node.js + SQLite），月消耗约 $1-2
- 如需长期运行，建议绑定信用卡

### 6.3 数据库持久化

- SQLite 文件存储在 Railway 临时文件系统
- **容器重启后数据会丢失**
- 生产环境建议迁移到 PostgreSQL：
  1. 在 Railway 添加 PostgreSQL 插件
  2. 使用 `DATABASE_URL` 环境变量
  3. 修改 `db.js` 使用 `pg` 替代 `better-sqlite3`

### 6.4 自动休眠

Railway 免费项目在无流量时可能休眠。首次访问会冷启动（约 10-30 秒）。

## 7. 故障排除

| 问题 | 解决方案 |
|------|----------|
| 部署失败 | 检查 Root Directory 是否设为 `server` |
| WebSocket 连接失败 | 确认使用 `wss://` 而非 `ws://` |
| 数据库丢失 | Railway 文件系统是临时的，考虑迁移到 PostgreSQL |
| 端口错误 | Railway 使用 `$PORT` 环境变量，不要硬编码 3000 |

## 8. 升级到 PostgreSQL（可选）

如需持久化数据：

1. 在 Railway 项目添加 **"Database"** → **"Add PostgreSQL"**
2. Railway 自动注入 `DATABASE_URL` 环境变量
3. 修改 `server/db.js`：

```javascript
// 安装 pg 包
// npm install pg

const { Client } = require('pg');

const client = new Client({
  connectionString: process.env.DATABASE_URL,
});

await client.connect();

// 创建表
await client.query(`
  CREATE TABLE IF NOT EXISTS players (
    device_id TEXT PRIMARY KEY,
    nickname TEXT,
    wins INTEGER DEFAULT 0,
    losses INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
  )
`);
```
