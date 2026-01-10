const { pool } = require('../db/pool');

async function writeAudit({ actorUserId, action, entityType, entityId, meta }) {
  await pool.query(
    `INSERT INTO audit_logs(actor_user_id, action, entity_type, entity_id, meta)
     VALUES ($1, $2, $3, $4, $5)`,
    [actorUserId ?? null, action, entityType ?? null, entityId ?? null, meta ?? {}]
  );
}

module.exports = { writeAudit };
