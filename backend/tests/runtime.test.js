'use strict';

/**
 * The Pterodactyl panel starts the app with its own start command and only
 * guarantees SERVER_PORT, not PORT. If the API ignores SERVER_PORT it binds
 * 5000 while the panel routes traffic to 3186, and the deployment looks "up"
 * in the console but every request times out. These tests pin that contract.
 */
const net = require('net');
const path = require('path');

/** Perform a real HTTP Upgrade handshake and resolve with the status code. */
function rawWebSocketUpgrade(port) {
  return new Promise((resolve, reject) => {
    const socket = net.connect(port, '127.0.0.1', () => {
      socket.write(
        'GET /socket.io/?EIO=4&transport=websocket HTTP/1.1\r\n' +
          `Host: 127.0.0.1:${port}\r\n` +
          'Upgrade: websocket\r\n' +
          'Connection: Upgrade\r\n' +
          'Sec-WebSocket-Version: 13\r\n' +
          'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n'
      );
    });
    let buffer = '';
    socket.setTimeout(5000, () => {
      socket.destroy();
      reject(new Error('WebSocket upgrade timed out'));
    });
    socket.on('data', (chunk) => {
      buffer += chunk.toString('latin1');
      const match = /^HTTP\/1\.1 (\d{3})/.exec(buffer);
      if (match) {
        socket.destroy();
        resolve(Number(match[1]));
      }
    });
    socket.on('error', reject);
    socket.on('close', () => {
      if (!buffer) reject(new Error('socket closed before the handshake'));
    });
  });
}

/**
 * Load config/env.js in a fresh registry with a given process.env.
 * jest.resetModules() is required: Jest keeps its own module registry, so
 * deleting require.cache would hand back the already-evaluated config.
 */
function envWith(vars) {
  const saved = {};
  for (const key of Object.keys(vars)) {
    saved[key] = process.env[key];
    if (vars[key] === undefined) delete process.env[key];
    else process.env[key] = vars[key];
  }
  jest.resetModules();
  jest.isolateModules(() => {});
  let env;
  jest.isolateModules(() => {
    ({ env } = require('../src/config/env'));
  });
  for (const key of Object.keys(vars)) {
    if (saved[key] === undefined) delete process.env[key];
    else process.env[key] = saved[key];
  }
  jest.resetModules();
  return env;
}

describe('runtime port resolution', () => {
  it('honours PORT when the host sets it (Render/Railway/Fly/Docker)', () => {
    expect(envWith({ PORT: '5000', SERVER_PORT: undefined }).port).toBe(5000);
  });

  it('falls back to SERVER_PORT on Pterodactyl, which sets no PORT', () => {
    expect(envWith({ PORT: undefined, SERVER_PORT: '3186' }).port).toBe(3186);
  });

  it('prefers PORT when both are present', () => {
    expect(envWith({ PORT: '4000', SERVER_PORT: '3186' }).port).toBe(4000);
  });

  it('falls back to 5000 when the host sets neither', () => {
    expect(envWith({ PORT: undefined, SERVER_PORT: undefined }).port).toBe(5000);
  });
});

describe('Pterodactyl entry point', () => {
  it('exposes a start function from the file the panel runs', () => {
    // The generic Node.js egg runs `node index.js`, ignoring the "main" field.
    // A syntax or resolution error here would crash the server on boot.
    const entry = require('../index');
    expect(typeof entry.start).toBe('function');
    expect(require.resolve('../index')).toBe(path.join(__dirname, '..', 'index.js'));
  });
});

describe('production wiring on a bare host', () => {
  it('serves /api/health and upgrades a raw WebSocket without a reverse proxy', async () => {
    // Pterodactyl exposes the container port directly: there is no nginx in
    // front to add Upgrade headers. If Socket.IO needs one, realtime is dead.
    process.env.NODE_ENV = 'production';
    const http = require('http');
    const { createApp } = require('../src/app');
    const { initSocket } = require('../src/sockets');

    const app = createApp();
    const server = http.createServer(app);
    initSocket(server);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    const { port } = server.address();

    try {
      const health = await fetch(`http://127.0.0.1:${port}/api/health`);
      expect(health.status).toBe(200);
      const body = await health.json();
      expect(body.data.status).toBe('ok');

      // fetch() refuses to set Connection itself (it is a forbidden header),
      // so the upgrade is performed on a raw socket. 101 proves Socket.IO does
      // not need an nginx/Caddy layer to accept WebSockets.
      const status = await rawWebSocketUpgrade(port);
      expect(status).toBe(101);
    } finally {
      await new Promise((resolve) => server.close(resolve));
    }
  });
});
