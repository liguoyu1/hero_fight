const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const { v4: uuidv4 } = require('uuid');
const dgram = require('dgram');
const path = require('path');
const db = require('./db');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

const PORT = 3000;
const UDP_PORT = 3001;
const HEARTBEAT_INTERVAL = 10000;
const IDLE_ROOM_TIMEOUT = 300000;
const MAX_PLAYERS = 2;

// 静态文件服务（如果需要）
// app.use(express.static(path.join(__dirname, '..', 'build', 'web')));
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'ok', rooms: rooms.size, clients: clients.size, queue: matchmakingQueue.length });
});

app.get('/api/stats/:playerId', async (req, res) => {
  try {
    const stats = await db.getPlayerStats(req.params.playerId);
    if (!stats) return res.status(404).json({ error: 'Player not found' });
    res.json(stats);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/api/leaderboard', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 20;
    res.json(await db.getLeaderboard(limit));
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/api/recent/:playerId', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    res.json(await db.getRecentGames(req.params.playerId, limit));
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// 接收客户端发送的游戏记录（AI/本地模式）
app.post('/api/game_record', async (req, res) => {
  try {
    const { player1Id, player2Id, player1Hero, player2Hero, winnerId, player1Name, player2Name, gameMode } = req.body;
    
    if (!player1Id || !player2Id) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    
    const roomId = `local_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    await db.recordGame({
      roomId,
      player1Id,
      player2Id,
      player1Hero: player1Hero || 'unknown',
      player2Hero: player2Hero || 'unknown',
      winnerId,
      player1Name: player1Name || 'Player 1',
      player2Name: player2Name || 'Player 2',
      gameMode: gameMode || 'local',
    });
    
    res.json({ success: true });
  } catch (e) {
    console.error('Failed to save game record:', e.message);
    res.status(500).json({ error: e.message });
  }
});

const rooms = new Map();
const clients = new Map();
const wsById = new Map(); // clientId -> ws (reverse lookup)
const matchmakingQueue = []; // Array of { ws, client }

class Room {
  constructor(id, name, hostId) {
    this.id = id;
    this.name = name;
    this.hostId = hostId;
    this.players = new Map();
    this.state = 'waiting';
    this.createdAt = Date.now();
    this.lastActivity = Date.now();
  }
  isFull() { return this.players.size >= MAX_PLAYERS; }
  toJSON() {
    const players = [];
    for (const [cid, p] of this.players) {
      players.push({ clientId: cid, name: p.name, heroId: p.heroId, ready: p.ready, slot: p.slot });
    }
    return { id: this.id, name: this.name, hostId: this.hostId, playerCount: this.players.size, maxPlayers: MAX_PLAYERS, state: this.state, players };
  }
}

function send(ws, type, data = {}) {
  if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify({ type, ...data }));
}

function broadcast(room, type, data = {}, excludeWs = null) {
  for (const [cid] of room.players) {
    const ws = wsById.get(cid);
    if (ws && ws !== excludeWs) send(ws, type, data);
  }
}

function getRoomList() {
  const list = [];
  for (const [, room] of rooms) list.push(room.toJSON());
  return list;
}

function removePlayerFromRoom(clientId) {
  for (const [roomId, room] of rooms) {
    if (!room.players.has(clientId)) continue;
    room.players.delete(clientId);
    room.lastActivity = Date.now();
    if (room.players.size === 0) {
      rooms.delete(roomId);
      console.log(`Room ${roomId} deleted (empty)`);
    } else {
      if (room.hostId === clientId) {
        room.hostId = room.players.keys().next().value;
        broadcast(room, 'host_changed', { hostId: room.hostId });
      }
      broadcast(room, 'player_left', { clientId, playerCount: room.players.size });
      if (room.state === 'playing') {
        room.state = 'finished';
        broadcast(room, 'game_end', { reason: 'opponent_disconnected' });
      }
    }
    return roomId;
  }
  return null;
}

function removeFromMatchmakingQueue(ws) {
  const idx = matchmakingQueue.findIndex(e => e.ws === ws);
  if (idx !== -1) {
    matchmakingQueue.splice(idx, 1);
    console.log(`Removed from matchmaking queue. Queue size: ${matchmakingQueue.length}`);
    return true;
  }
  return false;
}

function tryMatchPlayers() {
  while (matchmakingQueue.length >= 2) {
    const p1 = matchmakingQueue.shift();
    const p2 = matchmakingQueue.shift();
    if (!p1 || !p2) break;

    const roomId = uuidv4().substring(0, 8);
    const room = new Room(roomId, `Match ${roomId}`, p1.client.id);

    const p1Info = { clientId: p1.client.id, name: p1.playerName || 'Player 1', heroId: null, ready: false, slot: 0 };
    const p2Info = { clientId: p2.client.id, name: p2.playerName || 'Player 2', heroId: null, ready: false, slot: 1 };

    room.players.set(p1.client.id, p1Info);
    room.players.set(p2.client.id, p2Info);
    rooms.set(roomId, room);

    p1.client.roomId = roomId;
    p2.client.roomId = roomId;

    console.log(`Match found! Room ${roomId}: ${p1.client.id} vs ${p2.client.id}`);

    send(p1.ws, 'match_found', { room: room.toJSON(), slot: 0, opponentName: p2.playerName || 'Player 2' });
    send(p2.ws, 'match_found', { room: room.toJSON(), slot: 1, opponentName: p1.playerName || 'Player 1' });
  }
}

// --- WebSocket Connection Handler ---
wss.on('connection', (ws, req) => {
  const clientId = uuidv4();
  const clientData = { id: clientId, deviceId: null, roomId: null, alive: true, lastPong: Date.now() };
  clients.set(ws, clientData);
  wsById.set(clientId, ws);
  console.log(`Client connected: ${clientId}`);
  send(ws, 'connected', { clientId });

  ws.on('pong', () => { const c = clients.get(ws); if (c) { c.alive = true; c.lastPong = Date.now(); } });
  ws.on('message', (raw) => {
    let msg;
    try { msg = JSON.parse(raw); } catch { return send(ws, 'error', { message: 'Invalid JSON' }); }
    const client = clients.get(ws);
    if (client) handleMessage(ws, client, msg);
  });
  ws.on('close', () => {
    const c = clients.get(ws);
    if (c) {
      removeFromMatchmakingQueue(ws);
      removePlayerFromRoom(c.id);
      wsById.delete(c.id);
      clients.delete(ws);
      console.log(`Disconnected: ${c.id}`);
    }
  });
  ws.on('error', (e) => {
    console.error('WS error:', e.message);
    const c = clients.get(ws);
    if (c) {
      removeFromMatchmakingQueue(ws);
      removePlayerFromRoom(c.id);
      wsById.delete(c.id);
      clients.delete(ws);
    }
  });
});

function handleMessage(ws, client, msg) {
  switch (msg.type) {
    case 'register_device': {
      if (msg.deviceId) {
        client.deviceId = msg.deviceId;
        client.nickname = msg.nickname || 'Player';
        db.getOrCreatePlayer(msg.deviceId, msg.nickname || 'Player')
          .then(() => console.log(`Player registered: ${msg.deviceId}`))
          .catch(err => console.error(`Failed to create player ${msg.deviceId}:`, err.message));
      } else {
        console.warn('register_device: no deviceId provided');
      }
      break;
    }

    case 'room_list':
      send(ws, 'room_list', { rooms: getRoomList() });
      break;

    case 'create_room': {
      removePlayerFromRoom(client.id);
      const roomId = uuidv4().substring(0, 8);
      const room = new Room(roomId, msg.name || `Room ${roomId}`, client.id);
      const p = { clientId: client.id, name: msg.playerName || 'Player 1', heroId: null, ready: false, slot: 0 };
      room.players.set(client.id, p);
      rooms.set(roomId, room);
      client.roomId = roomId;
      send(ws, 'room_created', { room: room.toJSON(), slot: 0 });
      console.log(`Room created: ${roomId}`);
      break;
    }

    case 'join_room': {
      const room = rooms.get(msg.roomId);
      if (!room) return send(ws, 'error', { message: 'Room not found' });
      if (room.isFull()) return send(ws, 'error', { message: 'Room is full' });
      if (room.state !== 'waiting') return send(ws, 'error', { message: 'Game in progress' });
      removePlayerFromRoom(client.id);
      const p = { clientId: client.id, name: msg.playerName || 'Player 2', heroId: null, ready: false, slot: 1 };
      room.players.set(client.id, p);
      room.lastActivity = Date.now();
      client.roomId = msg.roomId;
      send(ws, 'room_joined', { room: room.toJSON(), slot: 1 });
      broadcast(room, 'player_joined', { clientId: client.id, playerName: p.name, slot: 1, room: room.toJSON() }, ws);
      console.log(`Player joined room ${msg.roomId}`);
      break;
    }

    case 'leave_room': {
      const rid = removePlayerFromRoom(client.id);
      client.roomId = null;
      send(ws, 'room_left', { roomId: rid });
      break;
    }

    // --- Matchmaking ---
    case 'start_matchmaking': {
      // Remove from any existing room first
      if (client.roomId) removePlayerFromRoom(client.id);
      client.roomId = null;
      // Remove any existing queue entry
      removeFromMatchmakingQueue(ws);
      // Add to queue
      matchmakingQueue.push({ ws, client, playerName: msg.playerName || 'Player' });
      send(ws, 'matchmaking_status', { status: 'queued', position: matchmakingQueue.length });
      console.log(`Matchmaking queue: ${matchmakingQueue.length} player(s) waiting`);
      tryMatchPlayers();
      break;
    }

    case 'cancel_matchmaking': {
      const removed = removeFromMatchmakingQueue(ws);
      send(ws, 'matchmaking_status', { status: 'cancelled' });
      break;
    }

    case 'select_hero': {
      const room = rooms.get(client.roomId);
      if (!room || !room.players.has(client.id)) return;
      if (!msg.heroId || typeof msg.heroId !== 'string') return send(ws, 'error', { message: 'Invalid heroId' });
      const p = room.players.get(client.id);
      p.heroId = msg.heroId;
      p.ready = false;
      room.lastActivity = Date.now();
      broadcast(room, 'hero_selected', { clientId: client.id, heroId: msg.heroId, slot: p.slot });
      break;
    }

    case 'player_ready': {
      const room = rooms.get(client.roomId);
      if (!room || !room.players.has(client.id)) return;
      const p = room.players.get(client.id);
      if (!p.heroId) return send(ws, 'error', { message: 'Select a hero first' });
      p.ready = msg.ready !== false;
      room.lastActivity = Date.now();
      broadcast(room, 'player_ready', { clientId: client.id, ready: p.ready, slot: p.slot });
      if (room.isFull() && [...room.players.values()].every(x => x.ready)) {
        room.state = 'playing';
        const pd = [...room.players.values()].map(x => ({ clientId: x.clientId, heroId: x.heroId, slot: x.slot, name: x.name }));
        broadcast(room, 'game_start', { players: pd, seed: Math.floor(Math.random() * 999999) });
        console.log(`Game started in room ${room.id}`);
      }
      break;
    }

    case 'game_input': {
      const room = rooms.get(client.roomId);
      if (!room || room.state !== 'playing') return;
      if (msg.frame === undefined || !msg.inputs) return;
      room.lastActivity = Date.now();
      broadcast(room, 'game_input', { clientId: client.id, frame: msg.frame, inputs: msg.inputs }, ws);
      break;
    }

    case 'game_end': {
      const room = rooms.get(client.roomId);
      if (!room) return;
      room.state = 'finished';
      room.lastActivity = Date.now();
      broadcast(room, 'game_end', { reason: msg.reason || 'game_over', winnerId: msg.winnerId });

      const playerArr = [...room.players.values()];
      if (playerArr.length === 2) {
        const p1 = playerArr[0];
        const p2 = playerArr[1];
        const ws1 = wsById.get(p1.clientId);
        const ws2 = wsById.get(p2.clientId);
        const c1 = ws1 ? clients.get(ws1) : null;
        const c2 = ws2 ? clients.get(ws2) : null;
        const d1 = c1?.deviceId || p1.clientId;
        const d2 = c2?.deviceId || p2.clientId;
        
        // 获取游戏模式（从消息中获取，默认为 online）
        const gameMode = msg.gameMode || 'online';
        
        db.recordGame({
          roomId: room.id,
          player1Id: d1,
          player2Id: d2,
          player1Hero: p1.heroId || 'unknown',
          player2Hero: p2.heroId || 'unknown',
          winnerId: msg.winnerId === p1.clientId ? d1 : msg.winnerId === p2.clientId ? d2 : null,
          player1Name: p1.name || 'Player 1',
          player2Name: p2.name || 'Player 2',
          gameMode: gameMode,
        }).then(() => {
          console.log(`Game recorded (${gameMode}): ${d1} vs ${d2}`);
        }).catch((e) => {
          console.error('Failed to record game:', e.message);
        });
      }

      setTimeout(() => {
        if (rooms.has(room.id)) {
          room.state = 'waiting';
          for (const [, p] of room.players) p.ready = false;
        }
      }, 3000);
      break;
    }

    default:
      send(ws, 'error', { message: `Unknown type: ${msg.type}` });
  }
}

// --- Heartbeat ---
const heartbeat = setInterval(() => {
  const now = Date.now();
  const toRemove = [];
  for (const [ws, info] of clients) {
    if (ws.readyState !== WebSocket.OPEN) {
      toRemove.push({ ws, info });
      continue;
    }
    try { ws.ping(); } catch (e) {}
    const lastPong = info.lastPong || 0;
    if (now - lastPong > HEARTBEAT_INTERVAL * 2) {
      console.log(`Client ${info.id} timed out (no pong)`);
      try { ws.terminate(); } catch (e) {}
      toRemove.push({ ws, info });
    }
  }
  for (const { ws, info } of toRemove) {
    removePlayerFromRoom(info.id);
    wsById.delete(info.id);
    clients.delete(ws);
  }
}, HEARTBEAT_INTERVAL);

// --- Idle Room Cleanup ---
const cleanup = setInterval(() => {
  const now = Date.now();
  for (const [id, room] of rooms) {
    if (now - room.lastActivity > IDLE_ROOM_TIMEOUT) {
      broadcast(room, 'room_closed', { reason: 'idle_timeout' });
      rooms.delete(id);
      console.log(`Room ${id} cleaned up (idle)`);
    }
  }
}, 60000);

// --- UDP LAN Discovery ---
const udpServer = dgram.createSocket({ type: 'udp4', reuseAddr: true });
udpServer.on('message', (msg, rinfo) => {
  try {
    const data = JSON.parse(msg.toString());
    if (data.type === 'lan_discover') {
      const response = JSON.stringify({ type: 'lan_discover_response', port: PORT, name: 'Hero Fighter Server', rooms: rooms.size, queue: matchmakingQueue.length });
      udpServer.send(response, rinfo.port, rinfo.address);
    }
  } catch {}
});
udpServer.on('error', (err) => console.error('UDP error:', err.message));
udpServer.bind(UDP_PORT, () => {
  udpServer.setBroadcast(true);
  console.log(`UDP discovery listening on port ${UDP_PORT}`);
});

// --- Graceful Shutdown ---
function shutdown() {
  console.log('Shutting down...');
  clearInterval(heartbeat);
  clearInterval(cleanup);
  for (const [ws] of clients) {
    send(ws, 'server_shutdown', {});
    ws.close();
  }
  udpServer.close();
  wss.close(() => server.close(() => { console.log('Server stopped.'); process.exit(0); }));
  setTimeout(() => process.exit(1), 5000);
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

// --- Start ---
const HOST = process.env.HOST || '0.0.0.0';
server.listen(PORT, HOST, () => console.log(`Hero Fighter server on port ${PORT}`));
