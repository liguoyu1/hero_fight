// Room Manager for Hero Fighter
// Handles room CRUD, state machine, and player lifecycle
module.exports = function({ MAX_PLAYERS, clients, wsById, rooms }) {

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
  if (ws.readyState === 1) ws.send(JSON.stringify({ type, ...data }));
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

// Idle room cleanup
function startCleanup(cleanupIntervalMs = 60000, idleTimeout = 300000) {
  return setInterval(() => {
    const now = Date.now();
    for (const [id, room] of rooms) {
      if (now - room.lastActivity > idleTimeout) {
        broadcast(room, 'room_closed', { reason: 'idle_timeout' });
        rooms.delete(id);
        console.log(`Room ${id} cleaned up (idle)`);
      }
    }
  }, cleanupIntervalMs);
}

return { Room, send, broadcast, getRoomList, removePlayerFromRoom, startCleanup };

};
