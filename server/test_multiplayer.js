const WebSocket = require('ws');
const http = require('http');

const SERVER = 'ws://localhost:3000';
let passed = 0;
let failed = 0;

function assert(condition, msg) {
  if (condition) { console.log(`  ✓ ${msg}`); passed++; }
  else { console.error(`  ✗ ${msg}`); failed++; }
}

function createClient(name) {
  return new Promise((resolve) => {
    const ws = new WebSocket(SERVER);
    const received = [];
    ws.on('message', (raw) => received.push(JSON.parse(raw)));
    ws.on('open', () => resolve({ ws, received, name }));
    ws.on('error', (e) => console.error(`${name} error:`, e.message));
  });
}

function send(client, type, data = {}) {
  client.ws.send(JSON.stringify({ type, ...data }));
}

function waitFor(client, type, timeout = 4000) {
  return new Promise((resolve, reject) => {
    const deadline = Date.now() + timeout;
    const check = setInterval(() => {
      const msg = client.received.find(m => m.type === type);
      if (msg) { clearInterval(check); resolve(msg); }
      else if (Date.now() > deadline) { clearInterval(check); reject(new Error(`Timeout waiting for '${type}' on ${client.name}`)); }
    }, 50);
  });
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function runTests() {
  console.log('\n=== Hero Fighter 多人联机集成测试 ===\n');

  console.log('【测试1】双客户端连接');
  const [c1, c2] = await Promise.all([createClient('Player1'), createClient('Player2')]);
  assert(c1.ws.readyState === WebSocket.OPEN, 'Player1 连接成功');
  assert(c2.ws.readyState === WebSocket.OPEN, 'Player2 连接成功');

  console.log('\n【测试2】匹配队列');
  send(c1, 'start_matchmaking', { playerName: 'Player1' });
  const status1 = await waitFor(c1, 'matchmaking_status');
  assert(status1.status === 'queued', 'Player1 进入匹配队列');
  assert(status1.position === 1, '队列位置为1');

  console.log('\n【测试3】匹配成功');
  send(c2, 'start_matchmaking', { playerName: 'Player2' });
  const [match1, match2] = await Promise.all([waitFor(c1, 'match_found'), waitFor(c2, 'match_found')]);
  assert(match1.type === 'match_found', 'Player1 收到 match_found');
  assert(match2.type === 'match_found', 'Player2 收到 match_found');
  assert(match1.slot === 0, 'Player1 slot=0');
  assert(match2.slot === 1, 'Player2 slot=1');
  assert(!!match1.room?.id, 'match_found 包含 room.id');
  assert(match1.opponentName === 'Player2', 'Player1 对手名正确');
  assert(match2.opponentName === 'Player1', 'Player2 对手名正确');
  const roomId = match1.room.id;
  console.log(`  → 房间ID: ${roomId}`);

  console.log('\n【测试4】选英雄');
  send(c1, 'select_hero', { heroId: 'lubu' });
  send(c2, 'select_hero', { heroId: 'guanyu' });
  const [sel1, sel2] = await Promise.all([waitFor(c1, 'hero_selected'), waitFor(c2, 'hero_selected')]);
  assert(sel1.type === 'hero_selected', 'Player1 收到 hero_selected 广播');
  assert(sel2.type === 'hero_selected', 'Player2 收到 hero_selected 广播');

  console.log('\n【测试5】游戏开始');
  send(c1, 'player_ready', { ready: true });
  send(c2, 'player_ready', { ready: true });
  const [start1, start2] = await Promise.all([waitFor(c1, 'game_start'), waitFor(c2, 'game_start')]);
  assert(start1.type === 'game_start', 'Player1 收到 game_start');
  assert(start2.type === 'game_start', 'Player2 收到 game_start');
  assert(Array.isArray(start1.players) && start1.players.length === 2, 'game_start 包含2个玩家');
  assert(typeof start1.seed === 'number', 'game_start 包含随机种子');
  assert(start1.seed === start2.seed, '双方种子一致（确定性同步）');

  console.log('\n【测试6】输入同步');
  c2.received.splice(0);
  send(c1, 'game_input', { frame: 1, inputs: { left: false, right: true, jump: false, attack: true, skill: false } });
  await sleep(200);
  const inputMsg = c2.received.find(m => m.type === 'game_input');
  assert(!!inputMsg, 'Player2 收到 Player1 的输入');
  assert(inputMsg?.frame === 1, '输入帧号正确');
  assert(inputMsg?.inputs?.attack === true, '输入内容正确');
  assert(inputMsg?.inputs?.right === true, '方向输入正确');

  console.log('\n【测试7】游戏结束');
  c1.received.splice(0); c2.received.splice(0);
  send(c1, 'game_end', { reason: 'game_over', winnerId: 'player1' });
  await sleep(200);
  const end2 = c2.received.find(m => m.type === 'game_end');
  assert(!!end2, 'Player2 收到 game_end');
  assert(end2?.reason === 'game_over', 'game_end reason 正确');

  console.log('\n【测试8】断线处理');
  const [c3, c4] = await Promise.all([createClient('Player3'), createClient('Player4')]);
  send(c3, 'start_matchmaking', { playerName: 'Player3' });
  send(c4, 'start_matchmaking', { playerName: 'Player4' });
  await Promise.all([waitFor(c3, 'match_found'), waitFor(c4, 'match_found')]);
  send(c3, 'select_hero', { heroId: 'lubu' });
  send(c4, 'select_hero', { heroId: 'zhuge' });
  await Promise.all([waitFor(c3, 'hero_selected'), waitFor(c4, 'hero_selected')]);
  send(c3, 'player_ready', { ready: true });
  send(c4, 'player_ready', { ready: true });
  await Promise.all([waitFor(c3, 'game_start'), waitFor(c4, 'game_start')]);
  c4.received.splice(0);
  c3.ws.close();
  await sleep(500);
  const disconnectMsg = c4.received.find(m => m.type === 'game_end');
  assert(!!disconnectMsg, 'Player4 收到对手断线通知');
  assert(disconnectMsg?.reason === 'opponent_disconnected', '断线原因正确');

  console.log('\n【测试9】服务器健康检查');
  await new Promise((resolve) => {
    http.get('http://localhost:3000/health', (res) => {
      let data = '';
      res.on('data', d => data += d);
      res.on('end', () => {
        const json = JSON.parse(data);
        assert(json.status === 'ok', '服务器健康检查通过');
        resolve();
      });
    });
  });

  [c1, c2, c4].forEach(c => { try { c.ws.close(); } catch(_) {} });

  console.log('\n' + '='.repeat(40));
  console.log(`测试结果: ${passed} 通过, ${failed} 失败`);
  if (failed === 0) console.log('✅ 所有测试通过！多人联机功能正常。');
  else console.log('❌ 有测试失败，请检查上方错误。');
  process.exit(failed > 0 ? 1 : 0);
}

runTests().catch(e => { console.error('\n测试异常:', e.message); process.exit(1); });
