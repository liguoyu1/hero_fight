const WebSocket = require('ws');
const https = require('https');

const SERVER_URL = 'wss://herofight-production.up.railway.app';
const API_URL = 'https://herofight-production.up.railway.app';

let passed = 0;
let failed = 0;

function assert(condition, msg) {
  if (condition) { console.log(`  ✓ ${msg}`); passed++; }
  else { console.error(`  ✗ ${msg}`); failed++; }
}

function createClient(name) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(SERVER_URL);
    const received = [];
    ws.on('message', (raw) => {
      const msg = JSON.parse(raw);
      received.push(msg);
    });
    ws.on('open', () => resolve({ ws, received, name }));
    ws.on('error', (e) => reject(new Error(`${name} connection error: ${e.message}`)));
    ws.on('close', (code, reason) => {
      console.log(`${name} disconnected: ${code} - ${reason}`);
    });
  });
}

function send(client, type, data = {}) {
  if (client.ws.readyState === WebSocket.OPEN) {
    client.ws.send(JSON.stringify({ type, ...data }));
  }
}

function waitFor(client, type, timeout = 10000) {
  return new Promise((resolve, reject) => {
    const deadline = Date.now() + timeout;
    const check = setInterval(() => {
      const idx = client.received.findIndex(m => m.type === type);
      if (idx !== -1) {
        clearInterval(check);
        resolve(client.received.splice(idx, 1)[0]);
      } else if (Date.now() > deadline) {
        clearInterval(check);
        reject(new Error(`Timeout waiting for '${type}' on ${client.name} (waited ${timeout}ms)`));
      }
    }, 50);
  });
}

function sleep(ms) { 
  return new Promise(r => setTimeout(r, ms)); 
}

async function testApiHealth() {
  console.log('\n【测试1】服务器健康检查');
  return new Promise((resolve) => {
    https.get(`${API_URL}/health`, (res) => {
      let data = '';
      res.on('data', d => data += d);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          assert(json.status === 'ok', '健康检查返回 status: ok');
          assert(typeof json.rooms === 'number', '返回房间数');
          assert(typeof json.clients === 'number', '返回客户端数');
          assert(typeof json.queue === 'number', '返回匹配队列数');
          console.log(`  → 当前状态: 房间=${json.rooms}, 客户端=${json.clients}, 队列=${json.queue}`);
        } catch (e) {
          console.error(`  ✗ 解析响应失败: ${e.message}`);
          failed++;
        }
        resolve();
      });
    }).on('error', (e) => {
      console.error(`  ✗ HTTP请求失败: ${e.message}`);
      failed++;
      resolve();
    });
  });
}

async function testLeaderboard() {
  console.log('\n【测试2】排行榜API');
  return new Promise((resolve) => {
    https.get(`${API_URL}/api/leaderboard?limit=5`, (res) => {
      let data = '';
      res.on('data', d => data += d);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          assert(Array.isArray(json), '返回数组格式');
          console.log(`  → 排行榜玩家数: ${json.length}`);
          if (json.length > 0) {
            assert(json[0].playerId, '玩家ID存在');
            assert(json[0].name, '玩家名称存在');
            assert(typeof json[0].totalWins === 'number', '胜利数为数字');
          }
        } catch (e) {
          console.error(`  ✗ 解析响应失败: ${e.message}`);
          failed++;
        }
        resolve();
      });
    }).on('error', (e) => {
      console.error(`  ✗ HTTP请求失败: ${e.message}`);
      failed++;
      resolve();
    });
  });
}

async function testOnlineMatchmaking() {
  console.log('\n【测试3】在线匹配');
  
  let c1, c2;
  
  try {
    console.log('  - 创建客户端连接...');
    [c1, c2] = await Promise.all([
      createClient('Player1'),
      createClient('Player2')
    ]);
    assert(c1.ws.readyState === WebSocket.OPEN, 'Player1 连接成功');
    assert(c2.ws.readyState === WebSocket.OPEN, 'Player2 连接成功');

    console.log('  - 等待连接确认...');
    const [conn1, conn2] = await Promise.all([
      waitFor(c1, 'connected', 5000),
      waitFor(c2, 'connected', 5000)
    ]);
    assert(!!conn1.clientId, 'Player1 获取到 clientId');
    assert(!!conn2.clientId, 'Player2 获取到 clientId');

    console.log('  - 注册设备...');
    send(c1, 'register_device', { deviceId: 'test_device_1', nickname: 'TestP1' });
    send(c2, 'register_device', { deviceId: 'test_device_2', nickname: 'TestP2' });
    await sleep(200);

    console.log('  - 开始匹配...');
    send(c1, 'start_matchmaking', { playerName: 'TestP1' });
    send(c2, 'start_matchmaking', { playerName: 'TestP2' });

    console.log('  - 等待匹配结果...');
    const [match1, match2] = await Promise.all([
      waitFor(c1, 'match_found', 15000),
      waitFor(c2, 'match_found', 15000)
    ]);
    assert(match1.type === 'match_found', 'Player1 收到匹配成功');
    assert(match2.type === 'match_found', 'Player2 收到匹配成功');
    assert(match1.room.id === match2.room.id, '双方进入同一房间');
    assert(match1.slot === 0, 'Player1 获得 slot 0');
    assert(match2.slot === 1, 'Player2 获得 slot 1');
    assert(match1.opponentName === 'TestP2', 'Player1 看到正确对手名');
    assert(match2.opponentName === 'TestP1', 'Player2 看到正确对手名');
    
    const roomId = match1.room.id;
    console.log(`  → 房间ID: ${roomId}`);

    console.log('  - 选择英雄...');
    send(c1, 'select_hero', { heroId: 'lubu' });
    send(c2, 'select_hero', { heroId: 'zhuge' });
    
    await Promise.all([
      waitFor(c1, 'hero_selected', 5000),
      waitFor(c2, 'hero_selected', 5000)
    ]);

    console.log('  - 准备就绪...');
    send(c1, 'player_ready', { ready: true });
    send(c2, 'player_ready', { ready: true });

    console.log('  - 等待游戏开始...');
    const [start1, start2] = await Promise.all([
      waitFor(c1, 'game_start', 5000),
      waitFor(c2, 'game_start', 5000)
    ]);
    assert(start1.type === 'game_start', 'Player1 收到游戏开始');
    assert(start2.type === 'game_start', 'Player2 收到游戏开始');
    assert(start1.seed === start2.seed, '双方随机种子一致');
    assert(start1.players.length === 2, '包含2名玩家');

    console.log('  - 输入同步测试...');
    send(c1, 'game_input', { frame: 1, inputs: { right: true, attack: true } });
    const input2 = await waitFor(c2, 'game_input', 5000);
    assert(input2.frame === 1, '输入帧号正确');
    assert(input2.inputs.right === true, '方向输入同步');
    assert(input2.inputs.attack === true, '攻击输入同步');

    console.log('  - 游戏结束...');
    send(c1, 'game_end', { reason: 'game_over', winnerId: conn1.clientId });
    await Promise.all([
      waitFor(c1, 'game_end', 5000),
      waitFor(c2, 'game_end', 5000)
    ]);

    console.log('  ✓ 在线匹配测试通过');
    
  } finally {
    if (c1) try { c1.ws.close(); } catch(_) {}
    if (c2) try { c2.ws.close(); } catch(_) {}
  }
}

async function testDisconnectHandling() {
  console.log('\n【测试4】断线处理');
  
  let c1, c2;
  
  try {
    [c1, c2] = await Promise.all([
      createClient('PlayerA'),
      createClient('PlayerB')
    ]);
    
    await Promise.all([
      waitFor(c1, 'connected', 5000),
      waitFor(c2, 'connected', 5000)
    ]);

    send(c1, 'register_device', { deviceId: 'disconnect_test_1', nickname: 'DisconnectTest1' });
    send(c2, 'register_device', { deviceId: 'disconnect_test_2', nickname: 'DisconnectTest2' });
    
    send(c1, 'start_matchmaking', { playerName: 'DisconnectTest1' });
    send(c2, 'start_matchmaking', { playerName: 'DisconnectTest2' });
    
    await Promise.all([
      waitFor(c1, 'match_found', 15000),
      waitFor(c2, 'match_found', 15000)
    ]);

    send(c1, 'select_hero', { heroId: 'lubu' });
    send(c2, 'select_hero', { heroId: 'guanyu' });
    await Promise.all([
      waitFor(c1, 'hero_selected', 5000),
      waitFor(c2, 'hero_selected', 5000)
    ]);

    send(c1, 'player_ready', { ready: true });
    send(c2, 'player_ready', { ready: true });
    
    await Promise.all([
      waitFor(c1, 'game_start', 5000),
      waitFor(c2, 'game_start', 5000)
    ]);

    c1.ws.close();
    
    const disconnectMsg = await waitFor(c2, 'game_end', 10000);
    assert(disconnectMsg.reason === 'opponent_disconnected', '正确检测到对手断线');
    
    console.log('  ✓ 断线处理测试通过');
    
  } finally {
    if (c1) try { c1.ws.close(); } catch(_) {}
    if (c2) try { c2.ws.close(); } catch(_) {}
  }
}

async function runTests() {
  console.log('\n' + '='.repeat(50));
  console.log('=== Hero Fighter 生产环境在线对战测试 ===');
  console.log('='.repeat(50));
  console.log(`服务器地址: ${SERVER_URL}`);
  console.log(`测试时间: ${new Date().toLocaleString('zh-CN')}`);

  try {
    await testApiHealth();
    await testLeaderboard();
    await testOnlineMatchmaking();
    await testDisconnectHandling();
  } catch (e) {
    console.error(`\n❌ 测试异常: ${e.message}`);
    failed++;
  }

  console.log('\n' + '='.repeat(50));
  console.log(`测试结果: ${passed} 通过, ${failed} 失败`);
  if (failed === 0) {
    console.log('✅ 所有测试通过！生产环境在线对战功能正常。');
  } else {
    console.log('❌ 有测试失败，请检查服务器状态。');
  }
  
  process.exit(failed > 0 ? 1 : 0);
}

runTests();