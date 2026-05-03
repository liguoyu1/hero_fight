import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'device_id.dart';

class HeroStats {
  final String heroId;
  int wins;
  int losses;

  HeroStats({required this.heroId, this.wins = 0, this.losses = 0});

  int get totalGames => wins + losses;
  double get winRate => totalGames == 0 ? 0.0 : wins / totalGames;

  Map<String, dynamic> toJson() => {
    'heroId': heroId,
    'wins': wins,
    'losses': losses,
  };

  factory HeroStats.fromJson(Map<String, dynamic> json) => HeroStats(
    heroId: json['heroId'] as String,
    wins: json['wins'] as int? ?? 0,
    losses: json['losses'] as int? ?? 0,
  );
}

class PlayerStats {
  static const _localKey = 'player_stats_v1';

  int totalWins;
  int totalLosses;
  int totalDraws;
  Map<String, HeroStats> heroStats;
  List<HeroStats> topHeroes;
  bool canShowTopHeroes;
  String? playerId;
  String? nickname;
  String? displayName;

  PlayerStats({
    this.totalWins = 0,
    this.totalLosses = 0,
    this.totalDraws = 0,
    Map<String, HeroStats>? heroStats,
    List<HeroStats>? topHeroes,
    this.canShowTopHeroes = false,
    this.playerId,
    this.nickname,
    this.displayName,
  })  : heroStats = heroStats ?? {},
        topHeroes = topHeroes ?? [];

  int get totalGames => totalWins + totalLosses + totalDraws;
  double get overallWinRate =>
      (totalWins + totalLosses) == 0 ? 0.0 : totalWins / (totalWins + totalLosses);

  void recordGame({required String heroId, required String result}) {
    switch (result) {
      case 'win':
        totalWins++;
        _getOrCreate(heroId).wins++;
        break;
      case 'loss':
        totalLosses++;
        _getOrCreate(heroId).losses++;
        break;
      case 'draw':
        totalDraws++;
        break;
    }
  }

  HeroStats _getOrCreate(String heroId) {
    return heroStats.putIfAbsent(heroId, () => HeroStats(heroId: heroId));
  }

  List<HeroStats> getTopHeroes({int count = 3, int minGames = 3}) {
    final eligible = heroStats.values
        .where((h) => h.totalGames >= minGames)
        .toList()
      ..sort((a, b) {
        final rateCompare = b.winRate.compareTo(a.winRate);
        if (rateCompare != 0) return rateCompare;
        return b.totalGames.compareTo(a.totalGames);
      });
    return eligible.take(count).toList();
  }

  Map<String, dynamic> toJson() => {
    'totalWins': totalWins,
    'totalLosses': totalLosses,
    'totalDraws': totalDraws,
    'heroStats': heroStats.map((k, v) => MapEntry(k, v.toJson())),
  };

  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    final stats = PlayerStats()
      ..totalWins = json['totalWins'] as int? ?? 0
      ..totalLosses = json['totalLosses'] as int? ?? 0
      ..totalDraws = json['totalDraws'] as int? ?? 0
      ..canShowTopHeroes = json['canShowTopHeroes'] as bool? ?? false
      ..playerId = json['playerId'] as String?
      ..nickname = json['name'] as String?
      ..displayName = json['displayName'] as String?;

    final heroMap = json['heroStats'];
    if (heroMap is Map<String, dynamic>) {
      for (final entry in heroMap.entries) {
        stats.heroStats[entry.key] =
            HeroStats.fromJson(entry.value as Map<String, dynamic>);
      }
    } else if (heroMap is List) {
      for (final h in heroMap) {
        final hs = HeroStats.fromJson(h as Map<String, dynamic>);
        stats.heroStats[hs.heroId] = hs;
      }
    }

    final topList = json['topHeroes'];
    if (topList is List) {
      stats.topHeroes = topList
          .map((h) => HeroStats.fromJson(h as Map<String, dynamic>))
          .toList();
    }

    return stats;
  }

  static String _buildBaseUrl() {
    if (kIsWeb) {
      final uri = Uri.base;
      return '${uri.scheme}://${uri.host}:${uri.port}';
    }
    return AppConfig.apiBaseUrl;
  }

  static Future<PlayerStats> loadFromServer({String? serverUrl}) async {
    try {
      final deviceId = await getDeviceId();
      final base = serverUrl ?? _buildBaseUrl();
      final resp = await http.get(Uri.parse('$base/api/stats/$deviceId'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        return PlayerStats.fromJson(json);
      }
    } catch (_) {}
    return _loadLocal();
  }

  static Future<PlayerStats> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localKey);
    if (raw == null) return PlayerStats();
    try {
      return PlayerStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return PlayerStats();
    }
  }

  Future<void> saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localKey, jsonEncode(toJson()));
  }

  Future<void> reset() async {
    totalWins = 0;
    totalLosses = 0;
    totalDraws = 0;
    heroStats.clear();
    topHeroes.clear();
    canShowTopHeroes = false;
    await saveLocal();
  }
}
