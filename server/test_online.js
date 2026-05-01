const WebSocket = require('ws');

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

function waitFor(msgs, type, timeout = 3000) {
  return new Promise((resolve, reject) => {
    const check = () => {
      const idx = msgs.findIndex(m => m.type === type);
      if (idx !== -1) return resolve(msgs.splice(idx, 1)[0]);
    };
    check();
    const interval = setInterval(check, 50);
    setTimeout(() => { clearInterval(interval); reject(new Error(`Timeout waiting for ${type}`)); }, timeout);
  });
}

function sendMsg(ws, type, data = {}) {
  ws.send(JSON.stringify({ type, ...data }));
}

async function run() {
  console.log('\n=== Hero Fighter Online Test ===\n');

  console.log('1. Connection');
  const p1 = await connect();
  const p2 = await connect();
  const c1 = await waitFor(p1.msgs, 'connected');
  const c2 = await waitFor(p2.msgs, 'connected');
  assert(!!c1.clientId, 'Player 1 connected with ID');
  assert(!!c2.clientId, 'Player 2 connected with ID');

  console.log('\n2. Matchmaking');
  sendMsg(p1.ws, 'start_matchmaking', { playerName: 'TestP1' });
  sendMsg(p2.ws, 'start_matchmaking', { playerName: 'TestP2' });
  const m1 = await waitFor(p1.msgs, 'match_found', 5000);
  const m2 = await waitFor(p2.msgs, 'match_found', 5000);
  assert(!!m1.room, 'Player 1 received match_found with room');
  assert(!!m2.room, 'Player 2 received match_found with room');
  assert(m1.room.id === m2.room.id, 'Both in same room');
  const roomId = m1.room.id;

  console.log('\n3. Hero Selection');
  sendMsg(p1.ws, 'select_hero', { roomId, heroId: 'lubu' });
  sendMsg(p2.ws, 'select_hero', { roomId, heroId: 'guanyu' });
  const hs1 = await waitFor(p1.msgs, 'hero_selected', 3000);
  const hs2 = await waitFor(p2.msgs, 'hero_selected', 3000);
  assert(hs1.heroId === 'guanyu' || hs1.heroId === 'lubu', 'P1 sees hero selection');
  assert(hs2.heroId === 'lubu' || hs2.heroId === 'guanyu', 'P2 sees hero selection');

  console.log('\n4. Ready & Game Start');
  sendMsg(p1.ws, 'player_ready', { roomId });
  sendMsg(p2.ws, 'player_ready', { roomId });
  const gs1 = await waitFor(p1.msgs, 'game_start', 5000);
  const gs2 = await waitFor(p2.msgs, 'game_start', 5000);
  assert(!!gs1.seed, 'Game start has seed');
  assert(gs1.seed === gs2.seed, 'Both players get same seed');

  console.log('\n5. Game Input Sync');
  sendMsg(p1.ws, 'game_input', { roomId, frame: 1, inputs: { left: true } });
  const gi2 = await waitFor(p2.msgs, 'game_input', 3000);
  assert(gi2.frame === 1, 'Input frame synced');
  assert(gi2.inputs.left === true, 'Input data synced');

  sendMsg(p2.ws, 'game_input', { roomId, frame: 2, inputs: { attack: true } });
  const gi1 = await waitFor(p1.msgs, 'game_input', 3000);
  assert(gi1.frame === 2, 'Reverse input synced');

  console.log('\n6. Game End');
  sendMsg(p1.ws, 'game_end', { roomId, winnerId: c1.clientId });
  const ge1 = await waitFor(p1.msgs, 'game_end', 3000);
  const ge2 = await waitFor(p2.msgs, 'game_end', 3000);
  assert(ge1.winnerId === c1.clientId, 'P1 sees winner');
  assert(ge2.winnerId === c1.clientId, 'P2 sees winner');

  console.log('\n7. Disconnect Handling');
  const p3 = await connect();
  const p4 = await connect();
  await waitFor(p3.msgs, 'connected');
  await waitFor(p4.msgs, 'connected');
  sendMsg(p3.ws, 'start_matchmaking', { playerName: 'P3' });
  sendMsg(p4.ws, 'start_matchmaking', { playerName: 'P4' });
  const m3 = await waitFor(p3.msgs, 'match_found', 5000);
  await waitFor(p4.msgs, 'match_found', 5000);
  const room2 = m3.room.id;
  sendMsg(p3.ws, 'select_hero', { roomId: room2, heroId: 'lubu' });
  sendMsg(p4.ws, 'select_hero', { roomId: room2, heroId: 'guanyu' });
  sendMsg(p3.ws, 'player_ready', { roomId: room2 });
  sendMsg(p4.ws, 'player_ready', { roomId: room2 });
  await waitFor(p3.msgs, 'game_start', 5000);
  await waitFor(p4.msgs, 'game_start', 5000);
  p4.ws.close();
  const dc = await waitFor(p3.msgs, 'game_end', 5000);
  assert(dc.reason === 'opponent_disconnected', 'Disconnect triggers game_end');

  console.log('\n8. Health Check');
  const http = require('http');
  const health = await new Promise((resolve) => {
    http.get('http://localhost:3000/health', (res) => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => resolve(JSON.parse(d)));
    });
  });
  assert(health.status === 'ok', 'Health endpoint ok');

  p1.ws.close();
  p2.ws.close();
  p3.ws.close();

  console.log(`\n=== Results: ${passed} passed, ${failed} failed ===\n`);
  process.exit(failed > 0 ? 1 : 0);
}

run().catch(e => { console.error('Test error:', e); process.exit(1); });
