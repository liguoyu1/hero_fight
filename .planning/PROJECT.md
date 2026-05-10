# Hero Fighter

> Flutter + Flame Engine 2D 格斗游戏优化项目

## 概述

Hero Fighter 是一款基于 Flutter 3.x + Flame 1.37.0 的 2D 格斗游戏，支持多人在线对战、局域网匹配和 AI 对战。项目已完成核心功能开发，当前目标是通过系统性审查发现的问题进行全面优化。

## 技术栈

| 层 | 技术 |
|------|------|
| 客户端 | Flutter 3.11+ / Dart / Flame 1.37.0 |
| 服务端 | Node.js + Express + WebSocket (ws) |
| 数据库 | SQLite (better-sqlite3) |
| 网络 | WebSocket 实时通信 + UDP LAN 发现 + Rollback Netcode |
| 部署 | Docker + docker-compose |
| 平台 | iOS / Android / Web / macOS / Windows |

## 核心特性

- 12 个英雄角色（三国/神话/战国三阵营）
- 实时多人对战（Rollback Netcode + WebSocket）
- LAN 局域网自动发现与匹配
- AI 对战（3 种难度）
- 粒子特效系统（对象池设计）
- 国际化支持（中/英）

## 版本

- 当前版本: 1.0.0+1
- 优化目标: 1.1.0
