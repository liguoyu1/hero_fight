// Matchmaker for Hero Fighter
// Handles matchmaking queue logic
module.exports = function({ matchmakingQueue, rooms, wsById, Room }) {

function removeFromMatchmakingQueue(ws) {
  const idx = matchmakingQueue.findIndex(e => e.ws === ws);
  if (idx !== -1) {
    matchmakingQueue.splice(idx, 1);
    console.log(`Removed from matchmaking queue. Queue size: ${matchmakingQueue.length}`);
    return true;
  }
  return false;
}

function send(ws, type, data = {}) {
  if (ws.readyState === 1) ws.send(JSON.stringify({ type, ...data }));
}

function tryMatchPlayers() {
  while (matchmakingQueue.length >= 2) {
    // Find best MMR match rather than just FIFO
    let bestPair = null;
    let bestDiff = Infinity;
    for (let i = 0; i < matchmakingQueue.length - 1; i++) {
      for (let j = i + 1; j < matchmakingQueue.length; j++) {
        const mmr1 = matchmakingQueue[i].mmr || 1000;
        const mmr2 = matchmakingQueue[j].mmr || 1000;
        const diff = Math.abs(mmr1 - mmr2);
        if (diff < bestDiff) {
          bestDiff = diff;
          bestPair = [i, j];
        }
      }
    }
    // Fallback to first two if no MMR data
    if (!bestPair) bestPair = [0, 1];

    const p1 = matchmakingQueue.splice(bestPair[0], 1)[0];
    const p2 = matchmakingQueue.splice(bestPair[1] > bestPair[0] ? bestPair[1] - 1 : bestPair[1], 1)[0];
    if (!p1 || !p2) break;

    const { v4: uuidv4 } = require('uuid');
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

return { removeFromMatchmakingQueue, tryMatchPlayers };

};
