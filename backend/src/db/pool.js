const { Pool } = require('pg');
const { env } = require('../config/env');

function shouldUseSsl(connectionString) {
  if (!connectionString) return false;
  if (String(process.env.PGSSLMODE || '').toLowerCase() === 'require') return true;
  if (env.nodeEnv === 'production') return true;
  // Supabase hosted Postgres requires SSL.
  if (connectionString.includes('supabase.co')) return true;
  if (connectionString.toLowerCase().includes('sslmode=require')) return true;
  return false;
}

const pool = new Pool({
  connectionString: env.databaseUrl,
  ssl: shouldUseSsl(env.databaseUrl) ? { rejectUnauthorized: false } : undefined,
  // Sensible defaults (especially important for cloud DBs)
  max: Number(process.env.PG_POOL_MAX || 10),
  idleTimeoutMillis: Number(process.env.PG_IDLE_TIMEOUT_MS || 30_000),
  connectionTimeoutMillis: Number(process.env.PG_CONNECTION_TIMEOUT_MS || 10_000),
});

module.exports = { pool };
