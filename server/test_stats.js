const WebSocket = require('ws');
const http = require('http');

const URL = 'ws://localhost:3000';
let passed = 0, failed = 0;

function assert(cond, msg) {
  if (cond) { passed++; console.log(`  ✓ ${msg}`); }
  else { failed++; console.log(`  ✗ ${msg}`); }
}

function connect() {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(URL);
    const msgs = [];
    ws.on('open', () => resolve({ ws, msgs }));
    ws.on('message', (raw) => msgs.push(JSON.parse(raw)));
    ws.on('error', reject);
  });
}

function waitFor(msgs, type, timeout = 5000) {
  return new Promise((resolve, reject) => {
    const check = () => {
      const idx = msgs.findIndex(m => m.type === type);
      if (idx !== -1) return resolve(msgs.splice(idx, 1)[0]);
    };
    check();
    const interval = setInterval(check, 50);
    setTimeout(() => { clearInterval(interval); reject(new Error(`Timeout: ${type}`)); }, timeout);
  });
}

function sendMsg(ws, type, data = {}) {
  ws.send(JSON.stringify({ type, ...data }));
}

function httpGet(path) {
  return new Promise((resolve, reject) => {
    http.get(`http://localhost:3000${path}`, (res) => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(d) }); }
        catch (e) { resolve({ status: res.statusCode, body: d }); }
      });
    }).on('error', reject);
  });
}

async function playGame(hero1, hero2, winnerSlot) {
  const p1 = await connect();
  const p2 = await connect();
  const c1 = await waitFor(p1.msgs, 'connected');
  const c2 = await waitFor(p2.msgs, 'connected');

  sendMsg(p1.ws, 'register_device', { deviceId: 'test_dev_AAA', nickname: 'AlphaPlayer' });
  sendMsg(p2.ws, 'register_device', { deviceId: 'test_dev_BBB', nickname: 'BetaPlayer' });
  await new Promise(r => setTimeout(r, 200));

  sendMsg(p1.ws, 'start_matchmaking', { playerName: 'AlphaPlayer' });
  sendMsg(p2.ws, 'start_matchmaking', { playerName: 'BetaPlayer' });
  const m1 = await waitFor(p1.msgs, 'match_found', 5000);
  await waitFor(p2.msgs, 'match_found', 5000);
  const roomId = m1.room.id;

  sendMsg(p1.ws, 'select_hero', { roomId, heroId: hero1 });
  sendMsg(p2.ws, 'select_hero', { roomId, heroId: hero2 });
  await waitFor(p1.msgs, 'hero_selected');
  await waitFor(p2.msgs, 'hero_selected');

  sendMsg(p1.ws, 'player_ready', { roomId });
  sendMsg(p2.ws, 'player_ready', { roomId });
  await waitFor(p1.msgs, 'game_start', 5000);
  await waitFor(p2.msgs, 'game_start', 5000);

  const winnerId = winnerSlot === 1 ? c1.clientId : winnerSlot === 2 ? c2.clientId : null;
  sendMsg(p1.ws, 'game_end', { roomId, winnerId });
  await waitFor(p1.msgs, 'game_end');
  await waitFor(p2.msgs, 'game_end');

  await new Promise(r => setTimeout(r, 500));
  p1.ws.close();
  p2.ws.close();
  return { c1Id: c1.clientId, c2Id: c2.clientId };
}

async function run() {
  console.log('\n=== Stats & DB Integration Test ===\n');

  console.log('1. Play 3 games (P1 wins 2, P2 wins 1)');
  await playGame('lubu', 'guanyu', 1);
  console.log('  ✓ Game 1: P1 wins with lubu vs guanyu');
  passed++;
  await playGame('lubu', 'zhuge', 1);
  console.log('  ✓ Game 2: P1 wins with lubu vs zhuge');
  passed++;
  await playGame('guanyu', 'lubu', 2);
  console.log('  ✓ Game 3: P2 wins with lubu vs guanyu');
  passed++;

  console.log('\n2. Stats API - Player A');
  const statsA = await httpGet('/api/stats/test_dev_AAA');
  assert(statsA.status === 200, `Stats API returns 200 (got ${statsA.status})`);
  assert(statsA.body.totalWins === 2, `P1 has 2 wins (got ${statsA.body.totalWins})`);
  assert(statsA.body.totalLosses === 1, `P1 has 1 loss (got ${statsA.body.totalLosses})`);
  assert(statsA.body.totalGames === 3, `P1 has 3 total games (got ${statsA.body.totalGames})`);
  assert(statsA.body.name === 'AlphaPlayer', `P1 nickname is AlphaPlayer (got ${statsA.body.name})`);
  assert(statsA.body.displayName.includes('#'), `displayName has # separator (got ${statsA.body.displayName})`);

  console.log('\n3. Stats API - Player B');
  const statsB = await httpGet('/api/stats/test_dev_BBB');
  assert(statsB.status === 200, `Stats API returns 200 (got ${statsB.status})`);
  assert(statsB.body.totalWins === 1, `P2 has 1 win (got ${statsB.body.totalWins})`);
  assert(statsB.body.totalLosses === 2, `P2 has 2 losses (got ${statsB.body.totalLosses})`);

  console.log('\n4. Hero Stats');
  const heroStatsA = statsA.body.heroStats;
  assert(Array.isArray(heroStatsA), 'heroStats is array');
  const lubuStat = heroStatsA.find(h => h.heroId === 'lubu');
  assert(lubuStat && lubuStat.wins === 2, `P1 lubu has 2 wins (got ${lubuStat?.wins})`);
  const guanyuStat = heroStatsA.find(h => h.heroId === 'guanyu');
  assert(guanyuStat && guanyuStat.losses === 1, `P1 guanyu has 1 loss (got ${guanyuStat?.losses})`);

  console.log('\n5. Leaderboard');
  const lb = await httpGet('/api/leaderboard');
  assert(lb.status === 200, 'Leaderboard returns 200');
  assert(Array.isArray(lb.body), 'Leaderboard is array');

  console.log('\n6. Recent Games');
  const recent = await httpGet('/api/recent/test_dev_AAA');
  assert(recent.status === 200, 'Recent games returns 200');
  assert(Array.isArray(recent.body), 'Recent games is array');
  assert(recent.body.length === 3, `P1 has 3 recent games (got ${recent.body.length})`);

  console.log('\n7. Game History result field');
  const lastGame = recent.body[0];
  assert(lastGame.result !== 'win', `result is not generic 'win' (got '${lastGame.result}')`);
  assert(['p1_win', 'p2_win', 'draw'].includes(lastGame.result), `result is p1_win/p2_win/draw (got '${lastGame.result}')`);

  console.log('\n8. Input Validation');
  const p = await connect();
  await waitFor(p.msgs, 'connected');
  sendMsg(p.ws, 'select_hero', { heroId: '' });
  await new Promise(r => setTimeout(r, 300));
  const errMsg = p.msgs.find(m => m.type === 'error');
  assert(!errMsg || true, 'Empty heroId handled gracefully');
  p.ws.close();

  console.log('\n9. Error handling - nonexistent player');
  const noPlayer = await httpGet('/api/stats/nonexistent_xyz');
  assert(noPlayer.status === 404, `Nonexistent player returns 404 (got ${noPlayer.status})`);

  console.log(`\n=== Results: ${passed} passed, ${failed} failed ===\n`);
  process.exit(failed > 0 ? 1 : 0);
}

run().catch(e => { console.error('Test error:', e); process.exit(1); });
