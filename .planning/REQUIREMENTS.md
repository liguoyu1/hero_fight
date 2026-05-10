# 需求文档

> 基于 2026-05-07 多维度审查报告生成

## 审查维度

| 维度 | 专家 | 发现问题数 |
|------|------|-----------|
| 架构与代码质量 | 软件架构师 | 10 |
| 游戏设计与平衡 | 游戏设计师 | 10 |
| 网络与多人对战 | 网络工程师 | 12 |
| UI/UX 与完善度 | UX 设计师 | 8 |
| 性能与资源管理 | 性能工程师 | 10 |

## REQ-01: 修复致命缺陷 (P0)

### REQ-01.1: HUD 渲染恢复
血条（含伤害拖尾）、英雄名称/称号、技能冷却弧+倒计时、连击计数器、倒计时器均未渲染，需恢复 `_renderHUD()` 调用。

### REQ-01.2: 防御公式改造
当前防御力为固定减伤（max(1, damage - defense)），高防英雄（盾卫 38防）对低攻英雄（貂蝉 38攻）造成「无敌状态」。改为百分比减伤或上限机制。

### REQ-01.3: 移动端音频实现
`flame_audio_impl.dart` 仅是 debugPrint 占位，iOS/Android 完全无声。需使用 `flame_audio` 真实播放。

### REQ-01.4: Paint 对象缓存
render() 循环中每帧创建 Paint 对象（粒子系统 ~20 个、弹体 MaskFilter.blur），造成显著 GC 压力。需缓存 Paint 对象为类字段。

### REQ-01.5: 屏幕自适应修复
当前 `onGameResize` 将屏幕像素尺寸直接设为游戏世界尺寸（iPhone SE 375px vs iPad 1024px），导致不同设备上移动速度/攻击范围/出生点/战斗节奏完全不同。弹体墙壁常量硬编码 1280×600。需改为固定游戏世界尺寸（1280×600）+ Flame Viewport 自动缩放填满屏幕。

## REQ-02: 核心架构重构 (P1)

### REQ-02.1: FighterGame 拆分
1167 行单文件违反 SRP，提取 InputSystem / CameraController / VFXSystem 独立模块。

### REQ-02.2: Fighter 拆分
875 行混合渲染+逻辑+序列化，提取 FighterRenderer（300 行渲染代码移出）。

### REQ-02.3: 服务端模块化
525 行 index.js 拆分：ws-handler.js / room-manager.js / matchmaker.js。

### REQ-02.4: 英雄属性同步
`executeSkill()` 硬编码伤害与 `skillDamage` 属性不一致（吕布 +10、关羽 +20、蚩尤 +30），统一读取属性字段。

### REQ-02.5: 跳跃系统实现
当前「跳跃」只是向上移动（moveY -= 1.5），无重力/跳跃力。实现真正的跳跃物理系统。

### REQ-02.6: 安全加固
硬编码密钥 `hero-fighter-secret-key-2024` 抽取为环境变量；添加 game_input 合法性校验。

### REQ-02.7: ParticleSystem 性能优化
O(n) 线性扫描改为 free-list O(1)；activeCount 增量维护；pool 上限控制。

### REQ-02.8: canvas.saveLayer 替代
死亡淡出效果改用简单 alpha 混合，避免每帧分配离屏缓冲区。

### REQ-02.9: 死代码清理
HeroLoader 加载 JSON 但从未使用；7 个 WAV 文件 (~130KB) 未使用。

### REQ-02.10: 重连状态恢复
重连后仅恢复 WebSocket 连接，游戏状态（rollback engine）丢失。

### REQ-02.11: 匹配 MMR
匹配队列纯 FIFO，无技能匹配。引入基础 MMR/ELO 匹配。

## REQ-03: 体验提升 (P2)

### REQ-03.1: i18n 全覆盖
英雄选择页（Ready/PICKED/阵营名）、主菜单设置、教程覆盖层接入 i18n。

### REQ-03.2: AI 强化
AI 增加方向攻击能力、弹体躲避逻辑。

### REQ-03.3: 网络自适应
添加 RTT 测量；delayFrames 自适应调整。

### REQ-03.4: 英雄命名统一
消除拼音(Lubu) vs 英文(ShieldGeneral) vs LOL遗留(lee_sin→少林武僧) 不一致。

### REQ-03.5: GameClient 事件系统重构
17 个独立 StreamController 合并为统一事件类型枚举 + 单个 onEvent 流。

### REQ-03.6: HeroLoader OCP 修复
硬编码 switch-case 改为反射/注册模式。

### REQ-03.7: 后羿技能平衡
2 秒冻结从「命中即必杀」改为 0.8 秒 + 递减。

### REQ-03.8: 输入缓冲
连击系统增加 3-5 帧输入缓冲窗口。

## REQ-04: 完善打磨 (P3)

### REQ-04.1: 代码规范统一
中文/英文注释混用 → 统一英文；catch(_){} 吞异常 → 添加错误日志。

### REQ-04.2: 渲染裁剪
离屏对象（fighter/projectile/particle）跳过渲染。

### REQ-04.3: 地面阴影
英雄脚下添加地面阴影投影。

### REQ-04.4: 单眼渲染修复
左右翻转导致只画一只眼的 bug。

### REQ-04.5: 触觉反馈
移动端攻击/受击添加 haptic feedback。

### REQ-04.6: 排行榜 UX
添加 loading 状态；4 名以后使用序数格式。

### REQ-04.7: 弹体墙壁自适应
硬编码 1280×600 改为动态读取舞台尺寸。

## REQ-05: iOS 上线合规 + 终审修复 (P0-P1)

> 基于 2026-05-07 最终验收审查

### REQ-05.1: ITSAppUsesNonExemptEncryption
App 使用 WSS (TLS) + HMAC-SHA256，需在 Info.plist 声明加密豁免。

### REQ-05.2: 隐私政策
创建隐私政策页面，填入 App Store Connect。

### REQ-05.3: PrivacyInfo 数据采集声明
device_info_plus 采集 IDFV，PrivacyInfo.xcprivacy 需声明 DeviceID 用途。

### REQ-05.4: 移动端音频实现
flame_audio_impl.dart 是 debugPrint stub。需用 flame_audio 加载 assets/sounds/*.wav 真实播放。

### REQ-05.5: 英雄数值微调
荆轲 52攻过高（同速度貂蝉仅 38攻）。3 英雄技能伤害硬编码未读 skillDamage。

### REQ-05.6: 测试更新
9 个测试因英雄数值重平衡失败，更新期望值。

### REQ-05.7: AI 跳跃 + 音效开关
AI 增加跳跃能力。设置音效开关连接 SoundManager。

## REQ-06: App Store 最终审核 (P0)

> 基于 2026-05-07 App Store 审核模拟

### REQ-06.1: 隐私政策页面
创建 HTML 隐私政策页面（含数据采集说明、联系方式），部署到 GitHub Pages 或项目内 web/ 目录。

### REQ-06.2: 支持 URL
提供技术支持联系方式（GitHub Issues / 邮箱），填入 App Store Connect。

### REQ-06.3: appSecret 安全
移除二进制中硬编码的默认密钥，改为运行时从安全存储读取或至少添加 TODO 标记。

### REQ-06.4: 服务端部署确认
Railway 部署确认可用；App 内网络断开时有友好提示而非崩溃。

### REQ-06.5: App 图标质量
替换 8-bit colormap 图标为真彩色高质量版本。

### REQ-06.6: IPv6 兼容
LAN 发现 UDPSocket 确保在 IPv6-only 网络（App Store 审核网络）不崩溃。

### REQ-04.8: UDP LAN 增强
IPv6 支持；广播回复替代单播。

### REQ-04.9: 教程可重播
暴露 `resetTutorial()` 到设置菜单。

### REQ-04.10: 音效机制修复
跳跃音效每帧触发 → 改为按下时单次触发；playProjectile/playLand 接入实际调用。
