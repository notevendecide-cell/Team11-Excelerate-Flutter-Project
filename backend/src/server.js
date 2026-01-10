const { env } = require('./config/env');
const { createApp } = require('./app');
const { pool } = require('./db/pool');

async function generateDeadlineNotifications() {
  const hours = Math.max(env.deadlineAlertHours, 1);

  await pool.query(
    `INSERT INTO notifications(user_id, type, title, body, meta)
     SELECT
       pl.learner_id,
       'task_deadline',
       'Task deadline soon',
       'A task deadline is approaching.',
       jsonb_build_object(
         'taskId', t.id,
         'programId', t.program_id,
         'deadlineAt', t.deadline_at,
         'title', t.title
       )
     FROM tasks t
     JOIN program_learners pl ON pl.program_id = t.program_id
     LEFT JOIN submissions s ON s.task_id = t.id AND s.learner_id = pl.learner_id
     WHERE t.deadline_at BETWEEN NOW() AND (NOW() + ($1 || ' hours')::interval)
       AND (s.id IS NULL OR s.status <> 'approved')
       AND NOT EXISTS (
         SELECT 1
         FROM notifications n
         WHERE n.user_id = pl.learner_id
           AND n.type = 'task_deadline'
           AND n.meta->>'taskId' = t.id::text
           AND n.created_at > NOW() - interval '12 hours'
       )`,
    [String(hours)]
  );
}

function start() {
  const app = createApp();
  app.listen(env.port, () => {
    // eslint-disable-next-line no-console
    console.log(`SkillTrack Pro API listening on :${env.port}`);
  });

  if (env.deadlineAlertsEnabled) {
    const intervalMs = Math.max(env.deadlineAlertIntervalMinutes, 1) * 60 * 1000;

    const tick = async () => {
      try {
        await generateDeadlineNotifications();
      } catch (e) {
        if (env.nodeEnv !== 'production') {
          // eslint-disable-next-line no-console
          console.error('Deadline notification tick failed:', e);
        }
      }
    };

    // Fire once shortly after startup, then periodically.
    setTimeout(tick, 3_000);
    setInterval(tick, intervalMs);
  }
}

module.exports = { start };
