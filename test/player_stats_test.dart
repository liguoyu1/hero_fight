import 'package:flutter_test/flutter_test.dart';
import 'package:hero_fighter/data/player_stats.dart';

void main() {
  // ─── HeroStats ───
  group('HeroStats', () {
    test('default values', () {
      final hs = HeroStats(heroId: 'lubu');
      expect(hs.heroId, 'lubu');
      expect(hs.wins, 0);
      expect(hs.losses, 0);
      expect(hs.totalGames, 0);
      expect(hs.winRate, 0.0);
    });

    test('totalGames sums wins and losses', () {
      final hs = HeroStats(heroId: 'lubu', wins: 5, losses: 3);
      expect(hs.totalGames, 8);
    });

    test('winRate calculation', () {
      final hs = HeroStats(heroId: 'lubu', wins: 3, losses: 1);
      expect(hs.winRate, closeTo(0.75, 0.001));
    });

    test('winRate is 0 when no games', () {
      final hs = HeroStats(heroId: 'lubu');
      expect(hs.winRate, 0.0);
    });

    test('toJson produces correct map', () {
      final hs = HeroStats(heroId: 'lubu', wins: 10, losses: 5);
      final json = hs.toJson();
      expect(json['heroId'], 'lubu');
      expect(json['wins'], 10);
      expect(json['losses'], 5);
    });

    test('fromJson restores correctly', () {
      final json = {'heroId': 'zhuge', 'wins': 7, 'losses': 2};
      final hs = HeroStats.fromJson(json);
      expect(hs.heroId, 'zhuge');
      expect(hs.wins, 7);
      expect(hs.losses, 2);
    });

    test('fromJson handles missing fields', () {
      final json = {'heroId': 'lubu'};
      final hs = HeroStats.fromJson(json);
      expect(hs.wins, 0);
      expect(hs.losses, 0);
    });
  });

  // ─── PlayerStats - Core Logic ───
  group('PlayerStats - Core', () {
    test('default values', () {
      final ps = PlayerStats();
      expect(ps.totalWins, 0);
      expect(ps.totalLosses, 0);
      expect(ps.totalDraws, 0);
      expect(ps.totalGames, 0);
      expect(ps.overallWinRate, 0.0);
      expect(ps.heroStats, isEmpty);
    });

    test('totalGames includes draws', () {
      final ps = PlayerStats(totalWins: 5, totalLosses: 3, totalDraws: 2);
      expect(ps.totalGames, 10);
    });

    test('overallWinRate excludes draws from denominator', () {
      final ps = PlayerStats(totalWins: 6, totalLosses: 4, totalDraws: 10);
      // winRate = 6 / (6+4) = 0.6
      expect(ps.overallWinRate, closeTo(0.6, 0.001));
    });
  });

  // ─── PlayerStats - recordGame ───
  group('PlayerStats - recordGame', () {
    test('records a win', () {
      final ps = PlayerStats();
      ps.recordGame(heroId: 'lubu', result: 'win');
      expect(ps.totalWins, 1);
      expect(ps.heroStats['lubu']!.wins, 1);
      expect(ps.heroStats['lubu']!.losses, 0);
    });

    test('records a loss', () {
      final ps = PlayerStats();
      ps.recordGame(heroId: 'lubu', result: 'loss');
      expect(ps.totalLosses, 1);
      expect(ps.heroStats['lubu']!.losses, 1);
    });

    test('records a draw', () {
      final ps = PlayerStats();
      ps.recordGame(heroId: 'lubu', result: 'draw');
      expect(ps.totalDraws, 1);
      // Draw does not create hero stats entry
      expect(ps.heroStats.containsKey('lubu'), isFalse);
    });

    test('accumulates multiple games for same hero', () {
      final ps = PlayerStats();
      ps.recordGame(heroId: 'lubu', result: 'win');
      ps.recordGame(heroId: 'lubu', result: 'win');
      ps.recordGame(heroId: 'lubu', result: 'loss');
      expect(ps.totalWins, 2);
      expect(ps.totalLosses, 1);
      expect(ps.heroStats['lubu']!.wins, 2);
      expect(ps.heroStats['lubu']!.losses, 1);
      expect(ps.heroStats['lubu']!.totalGames, 3);
    });

    test('tracks multiple heroes independently', () {
      final ps = PlayerStats();
      ps.recordGame(heroId: 'lubu', result: 'win');
      ps.recordGame(heroId: 'zhuge', result: 'loss');
      expect(ps.heroStats.length, 2);
      expect(ps.heroStats['lubu']!.wins, 1);
      expect(ps.heroStats['zhuge']!.losses, 1);
    });

    test('ignores unknown result strings', () {
      final ps = PlayerStats();
      ps.recordGame(heroId: 'lubu', result: 'unknown');
      expect(ps.totalWins, 0);
      expect(ps.totalLosses, 0);
      expect(ps.totalDraws, 0);
    });
  });

  // ─── PlayerStats - getTopHeroes ───
  group('PlayerStats - getTopHeroes', () {
    test('returns empty when no heroes meet minGames', () {
      final ps = PlayerStats();
      ps.recordGame(heroId: 'lubu', result: 'win');
      ps.recordGame(heroId: 'lubu', result: 'win');
      // Only 2 games, minGames default is 3
      expect(ps.getTopHeroes(), isEmpty);
    });

    test('returns heroes meeting minGames threshold', () {
      final ps = PlayerStats();
      for (int i = 0; i < 3; i++) {
        ps.recordGame(heroId: 'lubu', result: 'win');
      }
      final top = ps.getTopHeroes();
      expect(top.length, 1);
      expect(top.first.heroId, 'lubu');
    });

    test('sorts by winRate descending', () {
      final ps = PlayerStats();
      // lubu: 3W 0L = 100%
      for (int i = 0; i < 3; i++) {
        ps.recordGame(heroId: 'lubu', result: 'win');
      }
      // zhuge: 2W 1L = 66%
      for (int i = 0; i < 2; i++) {
        ps.recordGame(heroId: 'zhuge', result: 'win');
      }
      ps.recordGame(heroId: 'zhuge', result: 'loss');

      final top = ps.getTopHeroes(count: 3, minGames: 3);
      expect(top.length, 2);
      expect(top[0].heroId, 'lubu');
      expect(top[1].heroId, 'zhuge');
    });

    test('breaks ties by totalGames', () {
      final ps = PlayerStats();
      // lubu: 3W 3L = 50%, 6 games
      for (int i = 0; i < 3; i++) {
        ps.recordGame(heroId: 'lubu', result: 'win');
        ps.recordGame(heroId: 'lubu', result: 'loss');
      }
      // zhuge: 2W 2L = 50%, 4 games
      for (int i = 0; i < 2; i++) {
        ps.recordGame(heroId: 'zhuge', result: 'win');
        ps.recordGame(heroId: 'zhuge', result: 'loss');
      }

      final top = ps.getTopHeroes(count: 3, minGames: 3);
      expect(top.length, 2);
      expect(top[0].heroId, 'lubu'); // More games wins tie
    });

    test('respects count limit', () {
      final ps = PlayerStats();
      for (final id in ['lubu', 'zhuge', 'guanyu', 'diaochan']) {
        for (int i = 0; i < 5; i++) {
          ps.recordGame(heroId: id, result: 'win');
        }
      }
      final top = ps.getTopHeroes(count: 2);
      expect(top.length, 2);
    });

    test('custom minGames works', () {
      final ps = PlayerStats();
      ps.recordGame(heroId: 'lubu', result: 'win');
      final top = ps.getTopHeroes(minGames: 1);
      expect(top.length, 1);
    });
  });

  // ─── PlayerStats - Serialization ───
  group('PlayerStats - toJson/fromJson', () {
    test('round-trip serialization', () {
      final ps = PlayerStats();
      ps.recordGame(heroId: 'lubu', result: 'win');
      ps.recordGame(heroId: 'lubu', result: 'win');
      ps.recordGame(heroId: 'zhuge', result: 'loss');
      ps.recordGame(heroId: 'guanyu', result: 'draw');

      final json = ps.toJson();
      final restored = PlayerStats.fromJson(json);

      expect(restored.totalWins, 2);
      expect(restored.totalLosses, 1);
      expect(restored.totalDraws, 1);
      expect(restored.heroStats.length, 2);
      expect(restored.heroStats['lubu']!.wins, 2);
      expect(restored.heroStats['zhuge']!.losses, 1);
    });

    test('fromJson handles Map heroStats format', () {
      final json = {
        'totalWins': 5,
        'totalLosses': 3,
        'totalDraws': 1,
        'heroStats': {
          'lubu': {'heroId': 'lubu', 'wins': 3, 'losses': 1},
          'zhuge': {'heroId': 'zhuge', 'wins': 2, 'losses': 2},
        },
      };
      final ps = PlayerStats.fromJson(json);
      expect(ps.heroStats.length, 2);
      expect(ps.heroStats['lubu']!.wins, 3);
    });

    test('fromJson handles List heroStats format', () {
      final json = {
        'totalWins': 5,
        'totalLosses': 3,
        'heroStats': [
          {'heroId': 'lubu', 'wins': 3, 'losses': 1},
          {'heroId': 'zhuge', 'wins': 2, 'losses': 2},
        ],
      };
      final ps = PlayerStats.fromJson(json);
      expect(ps.heroStats.length, 2);
      expect(ps.heroStats['lubu']!.wins, 3);
    });

    test('fromJson handles missing fields gracefully', () {
      final ps = PlayerStats.fromJson(<String, dynamic>{});
      expect(ps.totalWins, 0);
      expect(ps.totalLosses, 0);
      expect(ps.totalDraws, 0);
      expect(ps.heroStats, isEmpty);
    });

    test('fromJson restores topHeroes list', () {
      final json = {
        'totalWins': 0,
        'topHeroes': [
          {'heroId': 'lubu', 'wins': 10, 'losses': 2},
        ],
      };
      final ps = PlayerStats.fromJson(json);
      expect(ps.topHeroes.length, 1);
      expect(ps.topHeroes.first.heroId, 'lubu');
    });

    test('fromJson restores optional fields', () {
      final json = {
        'playerId': 'p123',
        'name': 'TestPlayer',
        'displayName': 'TestPlayer#abcd',
        'canShowTopHeroes': true,
      };
      final ps = PlayerStats.fromJson(json);
      expect(ps.playerId, 'p123');
      expect(ps.nickname, 'TestPlayer');
      expect(ps.displayName, 'TestPlayer#abcd');
      expect(ps.canShowTopHeroes, isTrue);
    });
  });
}
