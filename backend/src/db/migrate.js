const fs = require('fs');
const path = require('path');

const { pool } = require('./pool');

async function ensureMigrationsTable(client) {
  await client.query(
    `CREATE TABLE IF NOT EXISTS schema_migrations (
       filename text PRIMARY KEY,
       applied_at timestamptz NOT NULL DEFAULT NOW()
     );`
  );
}

async function getApplied(client) {
  const { rows } = await client.query('SELECT filename FROM schema_migrations');
  return new Set(rows.map((r) => r.filename));
}

function listMigrationFiles() {
  const dir = path.join(__dirname, 'migrations');
  const files = fs
    .readdirSync(dir)
    .filter((f) => f.endsWith('.sql'))
    .sort();
  return files.map((f) => ({
    filename: f,
    fullPath: path.join(dir, f),
  }));
}

async function applyMigration(client, migration) {
  const sql = fs.readFileSync(migration.fullPath, 'utf8');
  await client.query('BEGIN');
  try {
    await client.query(sql);
    await client.query('INSERT INTO schema_migrations(filename) VALUES ($1)', [migration.filename]);
    await client.query('COMMIT');
    // eslint-disable-next-line no-console
    console.log(`Applied: ${migration.filename}`);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  }
}

async function migrate() {
  const client = await pool.connect();
  try {
    await ensureMigrationsTable(client);
    const applied = await getApplied(client);
    const migrations = listMigrationFiles().filter((m) => !applied.has(m.filename));

    if (migrations.length === 0) {
      // eslint-disable-next-line no-console
      console.log('No migrations to apply');
      return;
    }

    for (const migration of migrations) {
      // eslint-disable-next-line no-await-in-loop
      await applyMigration(client, migration);
    }
  } finally {
    client.release();
    await pool.end();
  }
}

migrate().catch((err) => {
  // eslint-disable-next-line no-console
  console.error('Migration failed:', err);
  process.exitCode = 1;
});
