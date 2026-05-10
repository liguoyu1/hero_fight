const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const { v4: uuidv4 } = require('uuid');
const dgram = require('dgram');
const path = require('path');
const crypto = require('crypto');
const db = require('./db');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

const PORT = 3000;
const UDP_PORT = 3001;
const HEARTBEAT_INTERVAL = 10000;
const IDLE_ROOM_TIMEOUT = 300000;
const MAX_PLAYERS = 2;

// ======================== HMAC Signature Verification ========================
const APP_SECRET = process.env.APP_SECRET || (console.warn('WARNING: Using default APP_SECRET — set APP_SECRET env var for production'), 'hero-fighter-secret-key-2024-dev-only');

function sortedStringify(obj) {
  if (obj === null || typeof obj !== 'object') return JSON.stringify(obj);
  if (Array.isArray(obj)) return '[' + obj.map(sortedStringify).join(',') + ']';
  const keys = Object.keys(obj).sort();
  const pairs = keys.map(k => JSON.stringify(k) + ':' + sortedStringify(obj[k]));
  return '{' + pairs.join(',') + '}';
}

function computeSignature(payload, secret) {
  return crypto.createHmac('sha256', secret).update(payload).digest('hex');
}

function verifySignature(body) {
  const { signature, ...data } = body;
  if (!signature) return { valid: false, error: 'Missing signature' };
  const payload = sortedStringify(data);
  const expected = computeSignature(payload, APP_SECRET);
  if (!crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) {
    return { valid: false, error: 'Invalid signature' };
  }
  return { valid: true, data };
}

// ======================== Shared State ========================
const rooms = new Map();
const clients = new Map();
const wsById = new Map();
const matchmakingQueue = [];
const disconnectedClients = new Map(); // deviceId -> { client, roomId, timeout }
const DISCONNECT_GRACE_PERIOD = 30000; // 30s grace period for reconnection

// ======================== Module Imports ========================
const roomMgr = require('./room-manager')({ MAX_PLAYERS, clients, wsById, rooms });
const { Room, send, broadcast, getRoomList, removePlayerFromRoom, startCleanup } = roomMgr;
const matchmaker = require('./matchmaker')({ matchmakingQueue, rooms, wsById, Room });
const { removeFromMatchmakingQueue, tryMatchPlayers } = matchmaker;

// ======================== HTTP API ========================
app.use(express.json());

// Static pages: privacy policy + support
app.get('/privacy', (req, res) => res.sendFile(path.join(__dirname, 'public', 'privacy.html')));
app.get('/support', (req, res) => res.sendFile(path.join(__dirname, 'public', 'support.html')));

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

app.post('/api/game_record', async (req, res) => {
  try {
    const verification = verifySignature(req.body);
    if (!verification.valid) {
      return res.status(403).json({ error: verification.error });
    }
    const data = verification.data;
    const { player1Id, player2Id, player1Hero, player2Hero, winnerId, player1Name, player2Name, gameMode } = data;
    if (!player1Id || !player2Id) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    const roomId = `local_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    await db.recordGame({
      roomId, player1Id, player2Id,
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

// ======================== WebSocket Handler ========================
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
      // Save disconnected state for 30s grace period
      if (c.deviceId && c.roomId) {
        const room = rooms.get(c.roomId);
        if (room && room.state === 'playing') {
          disconnectedClients.set(c.deviceId, {
            client: { ...c },
            roomId: c.roomId,
            timeout: setTimeout(() => {
              const dc = disconnectedClients.get(c.deviceId);
              if (dc) {
                removePlayerFromRoom(dc.client.id);
                disconnectedClients.delete(c.deviceId);
                console.log(`Disconnect grace expired for ${c.deviceId}`);
              }
            }, DISCONNECT_GRACE_PERIOD),
          });
          console.log(`Client ${c.deviceId} disconnected (grace period started, room ${c.roomId})`);
        }
      } else {
        removePlayerFromRoom(c.id);
      }
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

        // Check for reconnection — restore previous client state
        const dc = disconnectedClients.get(msg.deviceId);
        if (dc) {
          clearTimeout(dc.timeout);
          disconnectedClients.delete(msg.deviceId);
          // Restore room membership
          const room = rooms.get(dc.roomId);
          if (room) {
            client.roomId = dc.roomId;
            const player = room.players.get(dc.client.id);
            if (player) {
              // Update clientId mapping to new connection
              room.players.delete(dc.client.id);
              player.clientId = client.id;
              room.players.set(client.id, player);
              send(ws, 'resync_state', {
                roomId: dc.roomId,
                state: room.state,
                slot: player.slot,
                heroId: player.heroId,
              });
              broadcast(room, 'player_reconnected', { clientId: client.id, slot: player.slot });
              console.log(`Client ${msg.deviceId} reconnected to room ${dc.roomId}`);
            }
          }
        }
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
    case 'start_matchmaking': {
      if (client.roomId) removePlayerFromRoom(client.id);
      client.roomId = null;
      removeFromMatchmakingQueue(ws);
      matchmakingQueue.push({ ws, client, playerName: msg.playerName || 'Player' });
      send(ws, 'matchmaking_status', { status: 'queued', position: matchmakingQueue.length });
      console.log(`Matchmaking queue: ${matchmakingQueue.length} player(s) waiting`);
      tryMatchPlayers();
      break;
    }
    case 'cancel_matchmaking': {
      removeFromMatchmakingQueue(ws);
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
      if (typeof msg.frame !== 'number' || !msg.inputs) return;
      if (client.lastFrame && msg.frame <= client.lastFrame) return;
      const validInputs = ['left', 'right', 'up', 'down', 'jump', 'attack', 'skill'];
      for (const key of validInputs) {
        if (msg.inputs[key] !== undefined && typeof msg.inputs[key] !== 'boolean') return;
      }
      client.lastFrame = msg.frame;
      room.lastActivity = Date.now();
      broadcast(room, 'game_input', { clientId: client.id, frame: msg.frame, inputs: msg.inputs }, ws);
      break;
    }
    case 'game_end': {
      const room = rooms.get(client.roomId);
      if (!room) return;
      if (room.state === 'finished') {
        console.log(`Game end already processed for room ${room.id}`);
        return;
      }
      room.state = 'finished';
      room.lastActivity = Date.now();
      broadcast(room, 'game_end', { reason: msg.reason || 'game_over', winnerId: msg.winnerId });
      const playerArr = [...room.players.values()];
      if (playerArr.length === 2) {
        const p1 = playerArr[0], p2 = playerArr[1];
        const ws1 = wsById.get(p1.clientId), ws2 = wsById.get(p2.clientId);
        const c1 = ws1 ? clients.get(ws1) : null, c2 = ws2 ? clients.get(ws2) : null;
        const d1 = c1?.deviceId || p1.clientId, d2 = c2?.deviceId || p2.clientId;
        let winnerDeviceId = null;
        if (msg.winnerId !== null && msg.winnerId !== undefined) {
          const wid = String(msg.winnerId);
          if (wid === '0' || wid === p1.clientId) winnerDeviceId = d1;
          else if (wid === '1' || wid === p2.clientId) winnerDeviceId = d2;
        }
        db.recordGame({
          roomId: room.id, player1Id: d1, player2Id: d2,
          player1Hero: p1.heroId || 'unknown', player2Hero: p2.heroId || 'unknown',
          winnerId: winnerDeviceId,
          player1Name: p1.name || 'Player 1', player2Name: p2.name || 'Player 2',
          gameMode: msg.gameMode || 'online',
        }).then(() => console.log(`Game recorded (${msg.gameMode || 'online'}): ${d1} vs ${d2}`))
          .catch(e => console.error('Failed to record game:', e.message));
      }
      setTimeout(() => {
        if (rooms.has(room.id)) {
          room.state = 'waiting';
          for (const [, p] of room.players) p.ready = false;
        }
      }, 3000);
      break;
    }
    case 'request_resync': {
      // Client requests state resync after reconnection
      const dc = msg.deviceId ? disconnectedClients.get(msg.deviceId) : null;
      if (dc) {
        const room = rooms.get(dc.roomId);
        if (room) {
          const player = room.players.get(dc.client.id);
          send(ws, 'resync_state', {
            roomId: dc.roomId,
            state: room ? room.state : 'unknown',
            slot: player ? player.slot : null,
            heroId: player ? player.heroId : null,
          });
          return;
        }
      }
      send(ws, 'resync_state', { state: 'not_found' });
      break;
    }

    case 'ping':
      // Echo back as pong for RTT measurement
      send(ws, 'pong', { 'timestamp': msg.timestamp });
      break;

    default:
      send(ws, 'error', { message: `Unknown type: ${msg.type}` });
  }
}

// ======================== Heartbeat ========================
const heartbeat = setInterval(() => {
  const now = Date.now();
  const toRemove = [];
  for (const [ws, info] of clients) {
    if (ws.readyState !== WebSocket.OPEN) { toRemove.push({ ws, info }); continue; }
    try { ws.ping(); } catch (e) {}
    if (now - (info.lastPong || 0) > HEARTBEAT_INTERVAL * 2) {
      console.log(`Client ${info.id} timed out`);
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

// ======================== Idle Room Cleanup ========================
startCleanup(60000, IDLE_ROOM_TIMEOUT);

// ======================== UDP LAN Discovery ========================
const udpServer = dgram.createSocket({ type: 'udp4', reuseAddr: true });
udpServer.on('listening', () => {
  const addr = udpServer.address();
  console.log(`UDP LAN discovery listening on ${addr.address}:${addr.port}`);
});
udpServer.on('message', (raw, rinfo) => {
  try {
    const msg = JSON.parse(raw);
    if (msg.type === 'lan_discover') {
      const resp = JSON.stringify({
        type: 'lan_server_info',
        port: PORT,
        name: 'Hero Fighter Server',
        rooms: rooms.size,
        queue: matchmakingQueue.length,
      });
      udpServer.send(resp, 0, resp.length, rinfo.port, rinfo.address, (err) => {
        if (err) console.error('UDP send error:', err.message);
      });
    }
  } catch {
    // Ignore malformed UDP packets
  }
});
udpServer.bind(UDP_PORT);

// ======================== Graceful Shutdown ========================
function shutdown() {
  console.log('Shutting down...');
  clearInterval(heartbeat);
  for (const [ws] of clients) {
    send(ws, 'server_shutdown', { message: 'Server is shutting down' });
    try { ws.close(); } catch (e) {}
  }
  try { udpServer.close(); } catch (e) {}
  wss.close(() => server.close(() => process.exit(0)));
  setTimeout(() => process.exit(1), 5000);
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

server.listen(PORT, () => {
  console.log(`Hero Fighter Server running on port ${PORT}`);
});
