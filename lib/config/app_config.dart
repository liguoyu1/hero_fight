import 'package:flutter/foundation.dart';

/// 应用配置
/// 修改此文件即可切换本地/生产环境
class AppConfig {
  // ==================== 环境切换 ====================
  
  /// 当前环境
  static const Environment environment = Environment.production;
  
  // ==================== 服务器配置 ====================
  
  /// HTTP API 基础地址
  static String get apiBaseUrl {
    switch (environment) {
      case Environment.local:
        return 'http://localhost:3000';
      case Environment.lan:
        // 局域网测试时修改此地址
        return 'http://192.168.1.100:3000';
      case Environment.production:
        return 'https://herofight-production.up.railway.app';
    }
  }
  
  /// WebSocket 地址
  static String get wsUrl {
    switch (environment) {
      case Environment.local:
        return 'ws://localhost:3000';
      case Environment.lan:
        return 'ws://192.168.1.100:3000';
      case Environment.production:
        return 'wss://herofight-production.up.railway.app';
    }
  }
  
  /// 是否启用调试日志
  static bool get enableDebugLog {
    return environment != Environment.production;
  }
  
  /// 连接超时时间
  static const Duration connectionTimeout = Duration(seconds: 10);
  
  /// 心跳间隔
  static const Duration heartbeatInterval = Duration(seconds: 10);
}

/// 环境类型
enum Environment {
  /// 本地开发
  local,
  
  /// 局域网测试
  lan,
  
  /// 生产环境
  production,
}
