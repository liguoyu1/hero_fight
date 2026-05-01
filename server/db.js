const Database = require('better-sqlite3');
const path = require('path');

const DB_PATH = path.join(__dirname, 'game_stats.db');

let db;

function getDb() {
  if (!db) {
    db = new Database(DB_PATH);
    db.pragma('journal_mode = WAL');
    db.pragma('foreign_keys = ON');
    initTables();
  }
  return db;
}

function initTables() {
  db.exec(`
    CREATE TABLE IF NOT EXISTS players (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL DEFAULT 'Player',
      total_wins INTEGER NOT NULL DEFAULT 0,
      total_losses INTEGER NOT NULL DEFAULT 0,
      total_draws INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      last_played_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS hero_stats (
      player_id TEXT NOT NULL,
      hero_id TEXT NOT NULL,
      wins INTEGER NOT NULL DEFAULT 0,
      losses INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (player_id, hero_id),
      FOREIGN KEY (player_id) REFERENCES players(id)
    );

    CREATE TABLE IF NOT EXISTS game_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      room_id TEXT NOT NULL,
      player1_id TEXT NOT NULL,
      player2_id TEXT NOT NULL,
      player1_hero TEXT NOT NULL,
      player2_hero TEXT NOT NULL,
      winner_id TEXT,
      result TEXT NOT NULL,
      played_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE INDEX IF NOT EXISTS idx_hero_stats_player ON hero_stats(player_id);
    CREATE INDEX IF NOT EXISTS idx_game_history_player1 ON game_history(player1_id);
    CREATE INDEX IF NOT EXISTS idx_game_history_player2 ON game_history(player2_id);
    CREATE INDEX IF NOT EXISTS idx_game_history_played ON game_history(played_at);
  `);
}

// --- Player Operations ---

function getOrCreatePlayer(playerId, name) {
  const d = getDb();
  const existing = d.prepare('SELECT * FROM players WHERE id = ?').get(playerId);
  if (existing) {
    if (name && name !== existing.name) {
      d.prepare('UPDATE players SET name = ? WHERE id = ?').run(name, playerId);
    }
    return existing;
  }
  d.prepare('INSERT INTO players (id, name) VALUES (?, ?)').run(playerId, name || 'Player');
  return d.prepare('SELECT * FROM players WHERE id = ?').get(playerId);
}

// --- Record Game Result ---

const recordGameStmt = {
  updatePlayerWin: null,
  updatePlayerLoss: null,
  updatePlayerDraw: null,
  updateHeroWin: null,
  updateHeroLoss: null,
  insertHistory: null,
};

function prepareStatements() {
  const d = getDb();
  recordGameStmt.updatePlayerWin = d.prepare(
    'UPDATE players SET total_wins = total_wins + 1, last_played_at = datetime(\'now\') WHERE id = ?'
  );
  recordGameStmt.updatePlayerLoss = d.prepare(
    'UPDATE players SET total_losses = total_losses + 1, last_played_at = datetime(\'now\') WHERE id = ?'
  );
  recordGameStmt.updatePlayerDraw = d.prepare(
    'UPDATE players SET total_draws = total_draws + 1, last_played_at = datetime(\'now\') WHERE id = ?'
  );
  recordGameStmt.upsertHeroWin = d.prepare(`
    INSERT INTO hero_stats (player_id, hero_id, wins, losses) VALUES (?, ?, 1, 0)
    ON CONFLICT(player_id, hero_id) DO UPDATE SET wins = wins + 1
  `);
  recordGameStmt.upsertHeroLoss = d.prepare(`
    INSERT INTO hero_stats (player_id, hero_id, wins, losses) VALUES (?, ?, 0, 1)
    ON CONFLICT(player_id, hero_id) DO UPDATE SET losses = losses + 1
  `);
  recordGameStmt.insertHistory = d.prepare(`
    INSERT INTO game_history (room_id, player1_id, player2_id, player1_hero, player2_hero, winner_id, result)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `);
}

/**
 * Record a completed game.
 * @param {object} params
 * @param {string} params.roomId
 * @param {string} params.player1Id
 * @param {string} params.player2Id
 * @param {string} params.player1Hero
 * @param {string} params.player2Hero
 * @param {string|null} params.winnerId - null for draw
 * @param {string} params.player1Name
 * @param {string} params.player2Name
 */
function recordGame({ roomId, player1Id, player2Id, player1Hero, player2Hero, winnerId, player1Name, player2Name }) {
  const d = getDb();
  if (!recordGameStmt.updatePlayerWin) prepareStatements();

  const record = d.transaction(() => {
    // Ensure players exist
    getOrCreatePlayer(player1Id, player1Name);
    getOrCreatePlayer(player2Id, player2Name);

    if (winnerId === null || winnerId === undefined) {
      recordGameStmt.updatePlayerDraw.run(player1Id);
      recordGameStmt.updatePlayerDraw.run(player2Id);
      d.prepare(`INSERT INTO hero_stats (player_id, hero_id, wins, losses) VALUES (?, ?, 0, 0)
        ON CONFLICT(player_id, hero_id) DO UPDATE SET wins = wins`).run(player1Id, player1Hero);
      d.prepare(`INSERT INTO hero_stats (player_id, hero_id, wins, losses) VALUES (?, ?, 0, 0)
        ON CONFLICT(player_id, hero_id) DO UPDATE SET wins = wins`).run(player2Id, player2Hero);
      recordGameStmt.insertHistory.run(roomId, player1Id, player2Id, player1Hero, player2Hero, null, 'draw');
    } else if (winnerId === player1Id) {
      recordGameStmt.updatePlayerWin.run(player1Id);
      recordGameStmt.updatePlayerLoss.run(player2Id);
      recordGameStmt.upsertHeroWin.run(player1Id, player1Hero);
      recordGameStmt.upsertHeroLoss.run(player2Id, player2Hero);
      recordGameStmt.insertHistory.run(roomId, player1Id, player2Id, player1Hero, player2Hero, winnerId, 'p1_win');
    } else {
      recordGameStmt.updatePlayerWin.run(player2Id);
      recordGameStmt.updatePlayerLoss.run(player1Id);
      recordGameStmt.upsertHeroWin.run(player2Id, player2Hero);
      recordGameStmt.upsertHeroLoss.run(player1Id, player1Hero);
      recordGameStmt.insertHistory.run(roomId, player1Id, player2Id, player1Hero, player2Hero, winnerId, 'p2_win');
    }
  });

  record();
}

// --- Query Stats ---

function getPlayerStats(playerId) {
  const d = getDb();
  const player = d.prepare('SELECT * FROM players WHERE id = ?').get(playerId);
  if (!player) return null;

  const heroStats = d.prepare('SELECT * FROM hero_stats WHERE player_id = ? ORDER BY (wins + losses) DESC').all(playerId);
  const totalGames = player.total_wins + player.total_losses + player.total_draws;

  return {
    playerId: player.id,
    name: player.name,
    displayName: `${player.name}#${player.id.slice(-4)}`,
    totalWins: player.total_wins,
    totalLosses: player.total_losses,
    totalDraws: player.total_draws,
    totalGames,
    winRate: (player.total_wins + player.total_losses) > 0
      ? player.total_wins / (player.total_wins + player.total_losses)
      : 0,
    heroStats: heroStats.map(h => ({
      heroId: h.hero_id,
      wins: h.wins,
      losses: h.losses,
      totalGames: h.wins + h.losses,
      winRate: (h.wins + h.losses) > 0 ? h.wins / (h.wins + h.losses) : 0,
    })),
    canShowTopHeroes: totalGames >= 20,
    topHeroes: getTopHeroes(playerId),
    lastPlayedAt: player.last_played_at,
  };
}

function getTopHeroes(playerId, count = 3, minGames = 3) {
  const d = getDb();
  return d.prepare(`
    SELECT hero_id, wins, losses, (wins + losses) as total_games,
           CAST(wins AS REAL) / (wins + losses) as win_rate
    FROM hero_stats
    WHERE player_id = ? AND (wins + losses) >= ?
    ORDER BY win_rate DESC, total_games DESC
    LIMIT ?
  `).all(playerId, minGames, count).map(h => ({
    heroId: h.hero_id,
    wins: h.wins,
    losses: h.losses,
    totalGames: h.total_games,
    winRate: h.win_rate,
  }));
}

function getLeaderboard(limit = 20) {
  const d = getDb();
  return d.prepare(`
    SELECT id, name, total_wins, total_losses, total_draws,
           (total_wins + total_losses + total_draws) as total_games,
           CASE WHEN (total_wins + total_losses) > 0
             THEN CAST(total_wins AS REAL) / (total_wins + total_losses)
             ELSE 0 END as win_rate
    FROM players
    WHERE (total_wins + total_losses + total_draws) >= 5
    ORDER BY win_rate DESC, total_wins DESC
    LIMIT ?
  `).all(limit).map(p => ({
    playerId: p.id,
    name: p.name,
    displayName: `${p.name}#${p.id.slice(-4)}`,
    totalWins: p.total_wins,
    totalLosses: p.total_losses,
    totalDraws: p.total_draws,
    totalGames: p.total_games,
    winRate: p.win_rate,
  }));
}

function getRecentGames(playerId, limit = 10) {
  const d = getDb();
  return d.prepare(`
    SELECT * FROM game_history
    WHERE player1_id = ? OR player2_id = ?
    ORDER BY played_at DESC
    LIMIT ?
  `).all(playerId, playerId, limit);
}

module.exports = {
  getDb,
  getOrCreatePlayer,
  recordGame,
  getPlayerStats,
  getTopHeroes,
  getLeaderboard,
  getRecentGames,
};
