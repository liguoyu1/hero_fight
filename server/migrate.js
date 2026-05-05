// 数据库迁移脚本 - 修复 game_mode 列缺失问题
const mysql = require('mysql2/promise');

async function migrate() {
  // 使用与 db.js 相同的配置逻辑
  const isRailway = !!(process.env.MYSQLHOST || process.env.MYSQLHOST);
  const dbConfig = {
    host: process.env.MYSQLHOST || process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.MYSQLPORT || process.env.DB_PORT || '3306'),
    user: process.env.MYSQLUSER || process.env.DB_USER || 'root',
    password: process.env.MYSQLPASSWORD || process.env.DB_PASSWORD || '',
    database: process.env.MYSQLDATABASE || process.env.DB_NAME || (isRailway ? 'railway' : 'hero_fighter'),
  };

  console.log('Connecting to database:', dbConfig.host, dbConfig.database);

  const conn = await mysql.createConnection(dbConfig);
  
  try {
    // 检查 game_mode 列是否存在
    const [columns] = await conn.execute(`SHOW COLUMNS FROM game_history LIKE 'game_mode'`);
    
    if (columns.length === 0) {
      console.log('game_mode column not found, adding...');
      await conn.execute(`ALTER TABLE game_history ADD COLUMN game_mode VARCHAR(50) DEFAULT 'online'`);
      console.log('✓ Successfully added game_mode column');
    } else {
      console.log('✓ game_mode column already exists');
    }

    // 验证
    const [verifyColumns] = await conn.execute(`SHOW COLUMNS FROM game_history LIKE 'game_mode'`);
    if (verifyColumns.length > 0) {
      console.log('✓ Migration verified successfully');
    }
  } catch (err) {
    console.error('✗ Migration failed:', err.message);
    process.exit(1);
  } finally {
    await conn.end();
  }
}

migrate().then(() => {
  console.log('Migration complete');
  process.exit(0);
}).catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
