const express = require('express');
const cors = require('cors');
const helmet = require('helmet');

const { errorHandler } = require('./middleware/errorHandler');
const { pool } = require('./db/pool');
const authRoutes = require('./routes/auth');
const learnerRoutes = require('./routes/learner');
const mentorRoutes = require('./routes/mentor');
const adminRoutes = require('./routes/admin');
const notificationRoutes = require('./routes/notifications');

function createApp() {
  const app = express();

  app.use(helmet());
  app.use(cors());
  app.use(express.json({ limit: '1mb' }));

  app.get('/health', (req, res) => res.json({ ok: true }));

  // Helpful for deployments: confirms the API can reach Postgres.
  // Does not expose error details to clients.
  app.get('/health/db', async (req, res) => {
    try {
      await pool.query('SELECT 1 AS ok');
      return res.json({ ok: true, db: true });
    } catch (e) {
      try {
        let host;
        let hostLen;
        let hostLastChar;
        let dns;
        try {
          const { env } = require('./config/env');
          const url = new URL(env.databaseUrl);
          host = url.hostname;
          hostLen = host.length;
          hostLastChar = host.charCodeAt(host.length - 1);

          // Optional: best-effort DNS insight (useful on IPv4-only runtimes)
          // eslint-disable-next-line node/no-unsupported-features/node-builtins
          const dnsPromises = require('node:dns').promises;
          const withTimeout = async (promise, ms) =>
            Promise.race([
              promise,
              new Promise((_, reject) =>
                setTimeout(() => reject(new Error('dns_timeout')), ms)
              ),
            ]);

          const [a, aaaa] = await Promise.all([
            withTimeout(dnsPromises.resolve4(host), 750).catch((err) => ({ error: err?.code || err?.message })),
            withTimeout(dnsPromises.resolve6(host), 750).catch((err) => ({ error: err?.code || err?.message })),
          ]);

          dns = {
            hasA: Array.isArray(a) && a.length > 0,
            hasAAAA: Array.isArray(aaaa) && aaaa.length > 0,
            aError: !Array.isArray(a) ? a?.error : undefined,
            aaaaError: !Array.isArray(aaaa) ? aaaa?.error : undefined,
          };
        } catch (_) {
          // ignore
        }
        // eslint-disable-next-line no-console
        console.error('DB health check failed', {
          requestId: req.headers['x-vercel-id'] || req.headers['x-request-id'] || undefined,
          message: e?.message,
          code: e?.code,
          host,
          hostLen,
          hostLastChar,
          dns,
        });
      } catch (_) {
        // ignore
      }
      return res.status(503).json({ ok: false, db: false });
    }
  });

  app.use('/auth', authRoutes);
  app.use('/learner', learnerRoutes);
  app.use('/mentor', mentorRoutes);
  app.use('/admin', adminRoutes);
  app.use('/notifications', notificationRoutes);

  app.use((req, res) => res.status(404).json({ error: { message: 'Not Found' } }));
  app.use(errorHandler);

  return app;
}

module.exports = { createApp };
