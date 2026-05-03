import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../data/player_stats.dart';
import '../game/heroes/hero_data.dart';
import '../game/heroes/hero_registry.dart';
import '../i18n/app_localizations.dart';

/// Statistics display screen showing player performance data.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  PlayerStats? _stats;
  bool _loading = true;
  List<Map<String, dynamic>> _leaderboard = const [];

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadLeaderboard();
  }

  Future<void> _loadStats() async {
    final stats = await PlayerStats.loadFromServer();
    if (mounted) {
      setState(() {
        _stats = stats;
        _loading = false;
      });
    }
  }

  Future<void> _loadLeaderboard() async {
    try {
      final base = _buildBaseUrl();
      final resp = await http.get(Uri.parse('$base/api/leaderboard'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        if (mounted) {
          setState(() {
            _leaderboard = data.cast<Map<String, dynamic>>();
          });
        }
      }
    } catch (_) {}
  }

  String _buildBaseUrl() {
    if (kIsWeb) {
      final uri = Uri.base;
      return '${uri.scheme}://${uri.host}:${uri.port}';
    }
    return AppConfig.apiBaseUrl;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.fromSystemLocale();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_stats?.displayName != null ? '${_stats!.displayName}\'s Stats' : l10n.stats),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.myStats),
              Tab(text: l10n.globalLeaderboard),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.resetData,
              onPressed: _confirmReset,
            ),
          ],
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              // Tab 1: My stats
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _stats == null || _stats!.totalGames == 0
                      ? _buildEmptyState()
                      : _buildStatsContent(),
              // Tab 2: Leaderboard
              _buildLeaderboardTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.fromSystemLocale();
    final isCompact = MediaQuery.of(context).size.width < 450;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart, size: isCompact ? 48 : 64, color: Colors.white24),
          SizedBox(height: isCompact ? 12 : 16),
          Text(
            l10n.noStatsYet,
            style: TextStyle(fontSize: isCompact ? 16 : 18, color: Colors.white54),
          ),
          SizedBox(height: isCompact ? 4 : 8),
          Text(
            l10n.completeMatchToRecord,
            style: TextStyle(fontSize: isCompact ? 12 : 14, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsContent() {
    final stats = _stats!;
    final l10n = AppLocalizations.fromSystemLocale();
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 450;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isCompact ? 8 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall stats card
          _buildOverallCard(stats, isCompact),
          SizedBox(height: isCompact ? 12 : 24),

          // Top heroes section (only show after 20 games)
          if (stats.canShowTopHeroes) ...[
            _buildSectionTitle(l10n.topHeroes),
            SizedBox(height: isCompact ? 8 : 12),
            _buildTopHeroes(stats, isCompact),
            SizedBox(height: isCompact ? 12 : 24),
          ] else ...[
            _buildUnlockHint(stats, isCompact),
            SizedBox(height: isCompact ? 12 : 24),
          ],

          // All heroes detail
          _buildSectionTitle(l10n.heroStats),
          SizedBox(height: isCompact ? 8 : 12),
          _buildHeroDetailList(stats, isCompact),
        ],
      ),
    );
  }

  Widget _buildOverallCard(PlayerStats stats, bool isCompact) {
    final l10n = AppLocalizations.fromSystemLocale();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 12 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A3E), Color(0xFF2A1A2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(
            l10n.overall,
            style: TextStyle(
              fontSize: isCompact ? 16 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: isCompact ? 8 : 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(l10n.totalGames, '${stats.totalGames}', Colors.white, isCompact),
              _buildStatItem(l10n.winsLabel, '${stats.totalWins}', Colors.greenAccent, isCompact),
              _buildStatItem(l10n.losses, '${stats.totalLosses}', Colors.redAccent, isCompact),
              _buildStatItem(l10n.draws, '${stats.totalDraws}', Colors.grey, isCompact),
            ],
          ),
          SizedBox(height: isCompact ? 8 : 16),
          // Win rate bar
          _buildWinRateBar(stats.overallWinRate, isCompact),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, bool isCompact) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: isCompact ? 20 : 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: isCompact ? 11 : 12, color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildWinRateBar(double rate, bool isCompact) {
    final l10n = AppLocalizations.fromSystemLocale();
    final percent = (rate * 100).toStringAsFixed(1);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.winRate, style: TextStyle(color: Colors.white54, fontSize: isCompact ? 12 : 13)),
            Text(
              '$percent%',
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 12 : 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 4 : 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: rate,
            minHeight: isCompact ? 6 : 8,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(
              rate >= 0.6 ? Colors.greenAccent : rate >= 0.4 ? Colors.amber : Colors.redAccent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
    );
  }

  Widget _buildTopHeroes(PlayerStats stats, bool isCompact) {
    final l10n = AppLocalizations.fromSystemLocale();
    final topHeroes = stats.topHeroes.isNotEmpty
        ? stats.topHeroes
        : stats.getTopHeroes(count: 3, minGames: 3);
    if (topHeroes.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(isCompact ? 8 : 12),
        child: Text(l10n.needMoreGames, style: const TextStyle(color: Colors.white38)),
      );
    }

    return Row(
      children: List.generate(topHeroes.length, (i) {
        final hero = topHeroes[i];
        final heroData = HeroRegistryHelper.getById(hero.heroId);
        final medals = ['🥇', '🥈', '🥉'];
        final medalSize = isCompact ? 20.0 : 24.0;
        final dotSize = isCompact ? 26.0 : 32.0;
        final padH = isCompact ? 8.0 : 12.0;
        final padV = isCompact ? 8.0 : 12.0;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(left: i > 0 ? (isCompact ? 4 : 8) : 0),
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: i == 0
                    ? const Color(0xFFFFD700)
                    : i == 1
                        ? const Color(0xFFC0C0C0)
                        : const Color(0xFFCD7F32),
                width: i == 0 ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(medals[i], style: TextStyle(fontSize: medalSize)),
                SizedBox(height: isCompact ? 4 : 8),
                // Hero color dot
                Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: heroData?.color ?? Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                ),
                SizedBox(height: isCompact ? 4 : 8),
                Text(
                  heroData?.name ?? hero.heroId,
                  style: TextStyle(
                    fontSize: isCompact ? 11 : 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isCompact ? 2 : 4),
                Text(
                  '${(hero.winRate * 100).toStringAsFixed(0)}% ${l10n.winRate}',
                  style: TextStyle(
                    fontSize: isCompact ? 10 : 12,
                    color: hero.winRate >= 0.6 ? Colors.greenAccent : Colors.white54,
                  ),
                ),
                Text(
                  '${hero.totalGames} ${l10n.gamesPlayed}',
                  style: TextStyle(fontSize: isCompact ? 10 : 11, color: Colors.white38),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildUnlockHint(PlayerStats stats, bool isCompact) {
    final l10n = AppLocalizations.fromSystemLocale();
    final remaining = 20 - stats.totalGames;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: Colors.white38, size: isCompact ? 20 : 24),
          SizedBox(width: isCompact ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.topHeroes,
                  style: TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: isCompact ? 13 : 14,
                  ),
                ),
                SizedBox(height: isCompact ? 2 : 4),
                Text(
                  'Play $remaining more games to unlock',
                  style: TextStyle(color: Colors.white38, fontSize: isCompact ? 11 : 12),
                ),
              ],
            ),
          ),
          // Progress ring
          SizedBox(
            width: isCompact ? 32 : 40,
            height: isCompact ? 32 : 40,
            child: CircularProgressIndicator(
              value: stats.totalGames / 20,
              strokeWidth: isCompact ? 2.5 : 3,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroDetailList(PlayerStats stats, bool isCompact) {
    final l10n = AppLocalizations.fromSystemLocale();
    final entries = stats.heroStats.values.toList()
      ..sort((a, b) => b.totalGames.compareTo(a.totalGames));

    if (entries.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(isCompact ? 8 : 12),
        child: Text(l10n.noHeroStats, style: const TextStyle(color: Colors.white38)),
      );
    }

    final textSize = isCompact ? 12.0 : 14.0;
    final textSizeSmall = isCompact ? 11.0 : 13.0;

    return Column(
      children: entries.map((hero) {
        final heroData = HeroRegistryHelper.getById(hero.heroId);
        return Container(
          margin: EdgeInsets.only(bottom: isCompact ? 4 : 8),
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12, vertical: isCompact ? 6 : 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Hero color indicator
              Container(
                width: isCompact ? 6 : 8,
                height: isCompact ? 28 : 36,
                decoration: BoxDecoration(
                  color: heroData?.color ?? Colors.grey,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SizedBox(width: isCompact ? 8 : 12),
              // Hero name
              Expanded(
                flex: 3,
                child: Text(
                  heroData?.name ?? hero.heroId,
                  style: TextStyle(
                    fontSize: textSize,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Games played
              Expanded(
                flex: 2,
                child: Text(
                  '${hero.totalGames} ${l10n.gamesSuffix}',
                  style: TextStyle(fontSize: textSizeSmall, color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
              ),
              // Win/Loss
              Expanded(
                flex: 2,
                child: Text(
                  '${hero.wins}${l10n.winsSuffix} ${hero.losses}${l10n.lossesSuffix}',
                  style: TextStyle(fontSize: textSizeSmall, color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
              ),
              // Win rate
              Text(
                '${(hero.winRate * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: textSize,
                  fontWeight: FontWeight.bold,
                  color: hero.winRate >= 0.6
                      ? Colors.greenAccent
                      : hero.winRate >= 0.4
                          ? Colors.white
                          : Colors.redAccent,
                ),
                textAlign: TextAlign.right,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLeaderboardTab() {
    final l10n = AppLocalizations.fromSystemLocale();
    final isCompact = MediaQuery.of(context).size.width < 450;

    if (_leaderboard.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.leaderboard, size: isCompact ? 48 : 64, color: Colors.white24),
            SizedBox(height: isCompact ? 12 : 16),
            Text('No leaderboard data', style: TextStyle(fontSize: isCompact ? 16 : 18, color: Colors.white54)),
            SizedBox(height: isCompact ? 4 : 8),
            Text('Need at least 5 games to appear', style: TextStyle(fontSize: isCompact ? 12 : 14, color: Colors.white38)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isCompact ? 8 : 16),
      itemCount: _leaderboard.length,
      itemBuilder: (context, index) {
        final entry = _leaderboard[index];
        final displayName = entry['displayName'] as String? ?? entry['name'] as String? ?? '???';
        final totalGames = entry['totalGames'] as int? ?? 0;
        final totalWins = entry['totalWins'] as int? ?? 0;
        final winRate = (entry['winRate'] as num?)?.toDouble() ?? 0.0;
        final isMe = _stats?.playerId != null && entry['playerId'] == _stats!.playerId;

        Color rankColor;
        String rankIcon;
        if (index == 0) {
          rankColor = const Color(0xFFFFD700);
          rankIcon = '🥇';
        } else if (index == 1) {
          rankColor = const Color(0xFFC0C0C0);
          rankIcon = '🥈';
        } else if (index == 2) {
          rankColor = const Color(0xFFCD7F32);
          rankIcon = '🥉';
        } else {
          rankColor = Colors.white38;
          rankIcon = '${index + 1}';
        }

        return Container(
          margin: EdgeInsets.only(bottom: isCompact ? 4 : 8),
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12, vertical: isCompact ? 6 : 10),
          decoration: BoxDecoration(
            color: isMe ? Colors.amber.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8),
            border: isMe ? Border.all(color: Colors.amber.withValues(alpha: 0.3)) : null,
          ),
          child: Row(
            children: [
              // Rank
              SizedBox(
                width: isCompact ? 28 : 36,
                child: index < 3
                    ? Text(rankIcon, style: TextStyle(fontSize: isCompact ? 18 : 20), textAlign: TextAlign.center)
                    : Text(rankIcon, style: TextStyle(fontSize: isCompact ? 14 : 16, color: rankColor, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ),
              SizedBox(width: isCompact ? 4 : 8),
              // Name
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: isCompact ? 13 : 14,
                        fontWeight: FontWeight.w600,
                        color: isMe ? Colors.amber : Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$totalGames $l10n.gamesSuffix $totalWins $l10n.winsSuffix',
                      style: TextStyle(fontSize: isCompact ? 10 : 11, color: Colors.white38),
                    ),
                  ],
                ),
              ),
              // Win rate
              Text(
                '${(winRate * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: isCompact ? 14 : 15,
                  fontWeight: FontWeight.bold,
                  color: winRate >= 0.6 ? Colors.greenAccent : winRate >= 0.4 ? Colors.white : Colors.redAccent,
                ),
                textAlign: TextAlign.right,
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmReset() {
    final l10n = AppLocalizations.fromSystemLocale();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(l10n.resetData, style: const TextStyle(color: Colors.white)),
        content: Text(l10n.confirmReset, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _stats?.reset();
              _loadStats();
            },
            child: Text(l10n.confirm, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

/// Hero registry helper to look up hero data by ID.
class HeroRegistryHelper {
  static HeroData? getById(String id) {
    return HeroRegistry.instance.get(id);
  }
}
