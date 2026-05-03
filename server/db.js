const mysql = require('mysql2/promise');

// 数据库配置：优先使用 Railway MySQL 环境变量
const isRailway = !!(process.env.MYSQLHOST || process.env.MYSQLHOST);
const dbConfig = {
  host: process.env.MYSQLHOST || process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.MYSQLPORT || process.env.DB_PORT || '3306'),
  user: process.env.MYSQLUSER || process.env.DB_USER || 'root',
  password: process.env.MYSQLPASSWORD || process.env.DB_PASSWORD || '',
  database: process.env.MYSQLDATABASE || process.env.DB_NAME || (isRailway ? 'railway' : 'hero_fighter'),
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
};

let pool;

async function getDb() {
  if (!pool) {
    pool = mysql.createPool(dbConfig);
    await initTables();
  }
  return pool;
}

async function initTables() {
  const conn = await pool.getConnection();
  try {
    // 玩家表
    await conn.execute(`
      CREATE TABLE IF NOT EXISTS players (
        id VARCHAR(255) PRIMARY KEY,
        name VARCHAR(255) NOT NULL DEFAULT 'Player',
        total_wins INT NOT NULL DEFAULT 0,
        total_losses INT NOT NULL DEFAULT 0,
        total_draws INT NOT NULL DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        last_played_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    `);

    // 英雄统计表
    await conn.execute(`
      CREATE TABLE IF NOT EXISTS hero_stats (
        player_id VARCHAR(255) NOT NULL,
        hero_id VARCHAR(255) NOT NULL,
        wins INT NOT NULL DEFAULT 0,
        losses INT NOT NULL DEFAULT 0,
        PRIMARY KEY (player_id, hero_id),
        FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
      )
    `);

    // 游戏历史表
    await conn.execute(`
      CREATE TABLE IF NOT EXISTS game_history (
        id INT AUTO_INCREMENT PRIMARY KEY,
        room_id VARCHAR(255) NOT NULL,
        player1_id VARCHAR(255) NOT NULL,
        player2_id VARCHAR(255) NOT NULL,
        player1_hero VARCHAR(255) NOT NULL,
        player2_hero VARCHAR(255) NOT NULL,
        winner_id VARCHAR(255),
        result VARCHAR(50) NOT NULL,
        game_mode VARCHAR(50) DEFAULT 'online',
        played_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // 创建索引（MySQL 语法）
    try { await conn.execute(`ALTER TABLE hero_stats ADD INDEX idx_hero_stats_player (player_id)`); } catch(e) {}
    try { await conn.execute(`ALTER TABLE game_history ADD INDEX idx_game_history_player1 (player1_id)`); } catch(e) {}
    try { await conn.execute(`ALTER TABLE game_history ADD INDEX idx_game_history_player2 (player2_id)`); } catch(e) {}
    try { await conn.execute(`ALTER TABLE game_history ADD INDEX idx_game_history_played (played_at)`); } catch(e) {}
  } finally {
    conn.release();
  }
}

// --- Player Operations ---

async function getOrCreatePlayer(playerId, name) {
  const db = await getDb();
  const [rows] = await db.execute('SELECT * FROM players WHERE id = ?', [playerId]);
  
  if (rows.length > 0) {
    const player = rows[0];
    if (name && name !== player.name) {
      await db.execute('UPDATE players SET name = ? WHERE id = ?', [name, playerId]);
      player.name = name;
    }
    return player;
  }
  
  await db.execute('INSERT INTO players (id, name) VALUES (?, ?)', [playerId, name || 'Player']);
  const [newRows] = await db.execute('SELECT * FROM players WHERE id = ?', [playerId]);
  return newRows[0];
}

// --- Record Game Result ---

async function recordGame({ roomId, player1Id, player2Id, player1Hero, player2Hero, winnerId, player1Name, player2Name, gameMode = 'online' }) {
  const db = await getDb();
  const conn = await db.getConnection();
  
  try {
    await conn.beginTransaction();
    
    // 确保玩家存在
    await getOrCreatePlayer(player1Id, player1Name);
    await getOrCreatePlayer(player2Id, player2Name);
    
    // 只有在线对战才更新统计数据
    if (gameMode === 'online') {
      if (winnerId === null || winnerId === undefined) {
        // 平局
        await conn.execute('UPDATE players SET total_draws = total_draws + 1 WHERE id IN (?, ?)', [player1Id, player2Id]);
      } else if (winnerId === player1Id) {
        // 玩家1获胜
        await conn.execute('UPDATE players SET total_wins = total_wins + 1 WHERE id = ?', [player1Id]);
        await conn.execute('UPDATE players SET total_losses = total_losses + 1 WHERE id = ?', [player2Id]);
      } else {
        // 玩家2获胜
        await conn.execute('UPDATE players SET total_wins = total_wins + 1 WHERE id = ?', [player2Id]);
        await conn.execute('UPDATE players SET total_losses = total_losses + 1 WHERE id = ?', [player1Id]);
      }
      
      // 更新英雄统计数据（仅在线模式）
      if (winnerId === null || winnerId === undefined) {
        await conn.execute(`
          INSERT INTO hero_stats (player_id, hero_id, wins, losses) VALUES (?, ?, 0, 0)
          ON DUPLICATE KEY UPDATE wins = wins
        `, [player1Id, player1Hero]);
        await conn.execute(`
          INSERT INTO hero_stats (player_id, hero_id, wins, losses) VALUES (?, ?, 0, 0)
          ON DUPLICATE KEY UPDATE wins = wins
        `, [player2Id, player2Hero]);
      } else if (winnerId === player1Id) {
        await conn.execute(`
          INSERT INTO hero_stats (player_id, hero_id, wins, losses) VALUES (?, ?, 1, 0)
          ON DUPLICATE KEY UPDATE wins = wins + 1
        `, [player1Id, player1Hero]);
        await conn.execute(`
          INSERT INTO hero_stats (player_id, hero_id, wins, losses) VALUES (?, ?, 0, 1)
          ON DUPLICATE KEY UPDATE losses = losses + 1
        `, [player2Id, player2Hero]);
      } else {
        await conn.execute(`
          INSERT INTO hero_stats (player_id, hero_id, wins, losses) VALUES (?, ?, 1, 0)
          ON DUPLICATE KEY UPDATE wins = wins + 1
        `, [player2Id, player2Hero]);
        await conn.execute(`
          INSERT INTO hero_stats (player_id, hero_id, wins, losses) VALUES (?, ?, 0, 1)
          ON DUPLICATE KEY UPDATE losses = losses + 1
        `, [player1Id, player1Hero]);
      }
    }
    
    // 记录游戏历史（所有模式都记录）
    const result = winnerId === null || winnerId === undefined 
      ? 'draw' 
      : winnerId === player1Id 
        ? 'p1_win' 
        : 'p2_win';
    
    await conn.execute(`
      INSERT INTO game_history (room_id, player1_id, player2_id, player1_hero, player2_hero, winner_id, result, game_mode)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `, [roomId, player1Id, player2Id, player1Hero, player2Hero, winnerId, result, gameMode]);
    
    await conn.commit();
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
}

// --- Query Stats ---

async function getPlayerStats(playerId) {
  const db = await getDb();
  const [players] = await db.execute('SELECT * FROM players WHERE id = ?', [playerId]);
  
  if (players.length === 0) return null;
  const player = players[0];
  
  const [heroStats] = await db.execute(
    'SELECT * FROM hero_stats WHERE player_id = ? ORDER BY (wins + losses) DESC',
    [playerId]
  );
  
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
    topHeroes: await getTopHeroes(playerId),
    lastPlayedAt: player.last_played_at,
  };
}

async function getTopHeroes(playerId, count = 3, minGames = 3) {
  const db = await getDb();
  const safeCount = parseInt(count) || 3;
  const safeMinGames = parseInt(minGames) || 3;
  const [rows] = await db.execute(`
    SELECT hero_id, wins, losses, (wins + losses) as total_games,
           CAST(wins AS DECIMAL) / (wins + losses) as win_rate
    FROM hero_stats
    WHERE player_id = ? AND (wins + losses) >= ?
    ORDER BY win_rate DESC, total_games DESC
    LIMIT ${safeCount}
  `, [playerId, safeMinGames]);
  
  return rows.map(h => ({
    heroId: h.hero_id,
    wins: h.wins,
    losses: h.losses,
    totalGames: h.total_games,
    winRate: h.win_rate,
  }));
}

async function getLeaderboard(limit = 20) {
  const db = await getDb();
  const safeLimit = parseInt(limit) || 20;
  const [rows] = await db.execute(`
    SELECT id, name, total_wins, total_losses, total_draws,
           (total_wins + total_losses + total_draws) as total_games
    FROM players
    WHERE (total_wins + total_losses + total_draws) >= 5
    ORDER BY total_wins DESC, total_losses ASC
    LIMIT ${safeLimit}
  `);
  
  return rows.map(p => ({
    playerId: p.id,
    name: p.name,
    displayName: `${p.name}#${p.id.slice(-4)}`,
    totalWins: p.total_wins,
    totalLosses: p.total_losses,
    totalDraws: p.total_draws,
    totalGames: p.total_games,
    winRate: (p.total_wins + p.total_losses) > 0 
      ? p.total_wins / (p.total_wins + p.total_losses) 
      : 0,
  }));
  
  return rows.map(p => ({
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

async function getRecentGames(playerId, limit = 10) {
  const db = await getDb();
  const safeLimit = parseInt(limit) || 10;
  const [rows] = await db.execute(`
    SELECT * FROM game_history
    WHERE player1_id = ? OR player2_id = ?
    ORDER BY played_at DESC
    LIMIT ${safeLimit}
  `, [playerId, playerId]);
  return rows;
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
