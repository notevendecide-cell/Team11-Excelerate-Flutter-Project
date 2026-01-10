const express = require('express');
const { z } = require('zod');

const { pool } = require('../db/pool');
const { requireAuth, requireRole } = require('../middleware/auth');
const { HttpError } = require('../utils/httpErrors');
const { writeAudit } = require('../utils/audit');

const router = express.Router();

router.use(requireAuth);
router.use(requireRole('learner'));

router.get('/dashboard', async (req, res, next) => {
  try {
    const learnerId = req.user.sub;

    const activePrograms = await pool.query(
      `SELECT p.id, p.title, p.description
       FROM programs p
       JOIN program_learners pl ON pl.program_id = p.id
       WHERE pl.learner_id = $1
       ORDER BY p.created_at DESC`,
      [learnerId]
    );

    const taskStats = await pool.query(
      `SELECT
         COUNT(*) FILTER (WHERE s.status = 'submitted') AS pending_tasks,
         COUNT(*) FILTER (WHERE s.status = 'approved') AS approved_tasks,
         COUNT(*) AS total_tasks
       FROM tasks t
       JOIN programs p ON p.id = t.program_id
       JOIN program_learners pl ON pl.program_id = p.id AND pl.learner_id = $1
       LEFT JOIN submissions s ON s.task_id = t.id AND s.learner_id = $1`,
      [learnerId]
    );

    const row = taskStats.rows[0] || { pending_tasks: 0, approved_tasks: 0, total_tasks: 0 };
    const total = Number(row.total_tasks || 0);
    const approved = Number(row.approved_tasks || 0);
    const completionPercentage = total === 0 ? 0 : Math.round((approved / total) * 100);

    res.json({
      activePrograms: activePrograms.rows,
      pendingTasks: Number(row.pending_tasks || 0),
      approvedTasks: approved,
      completionPercentage,
    });
  } catch (err) {
    next(err);
  }
});

router.get('/programs', async (req, res, next) => {
  try {
    const learnerId = req.user.sub;
    const limit = Math.min(Number(req.query.limit || 20), 50);
    const offset = Math.max(Number(req.query.offset || 0), 0);

    const { rows } = await pool.query(
      `SELECT p.id, p.title, p.description, p.mentor_id
       FROM programs p
       JOIN program_learners pl ON pl.program_id = p.id
       WHERE pl.learner_id = $1
       ORDER BY p.created_at DESC
       LIMIT $2 OFFSET $3`,
      [learnerId, limit, offset]
    );

    res.json({ items: rows, limit, offset });
  } catch (err) {
    next(err);
  }
});

router.get('/programs/:programId/milestones', async (req, res, next) => {
  try {
    const learnerId = req.user.sub;
    const programId = req.params.programId;

    const access = await pool.query(
      'SELECT 1 FROM program_learners WHERE program_id = $1 AND learner_id = $2',
      [programId, learnerId]
    );
    if (access.rowCount === 0) throw new HttpError(403, 'Forbidden');

    const { rows } = await pool.query(
      `SELECT id, title, sort_order
       FROM milestones
       WHERE program_id = $1
       ORDER BY sort_order ASC, created_at ASC`,
      [programId]
    );

    res.json({ items: rows });
  } catch (err) {
    next(err);
  }
});

router.get('/programs/:programId/tasks', async (req, res, next) => {
  try {
    const learnerId = req.user.sub;
    const programId = req.params.programId;
    const milestoneId = req.query.milestoneId;
    const limit = Math.min(Number(req.query.limit || 20), 50);
    const offset = Math.max(Number(req.query.offset || 0), 0);

    const access = await pool.query(
      'SELECT 1 FROM program_learners WHERE program_id = $1 AND learner_id = $2',
      [programId, learnerId]
    );
    if (access.rowCount === 0) throw new HttpError(403, 'Forbidden');

    const params = [programId, learnerId, limit, offset];
    let milestoneClause = '';
    if (milestoneId) {
      params.push(milestoneId);
      milestoneClause = ' AND t.milestone_id = $5';
    }

    const { rows } = await pool.query(
      `SELECT t.id, t.milestone_id, t.title, t.deadline_at,
              COALESCE(s.status, 'not_submitted') AS submission_status,
              s.score
       FROM tasks t
       LEFT JOIN submissions s ON s.task_id = t.id AND s.learner_id = $2
       WHERE t.program_id = $1${milestoneClause}
       ORDER BY t.deadline_at ASC
       LIMIT $3 OFFSET $4`,
      params
    );

    res.json({ items: rows, limit, offset });
  } catch (err) {
    next(err);
  }
});

router.get('/programs/:programId/progress', async (req, res, next) => {
  try {
    const learnerId = req.user.sub;
    const programId = req.params.programId;

    const access = await pool.query(
      'SELECT 1 FROM program_learners WHERE program_id = $1 AND learner_id = $2',
      [programId, learnerId]
    );
    if (access.rowCount === 0) throw new HttpError(403, 'Forbidden');

    const { rows } = await pool.query(
      `SELECT
         COUNT(*)::int AS total_tasks,
         COUNT(*) FILTER (WHERE s.status = 'submitted')::int AS pending,
         COUNT(*) FILTER (WHERE s.status = 'approved')::int AS approved,
         COUNT(*) FILTER (WHERE s.status = 'rejected')::int AS rejected
       FROM tasks t
       LEFT JOIN submissions s ON s.task_id = t.id AND s.learner_id = $2
       WHERE t.program_id = $1`,
      [programId, learnerId]
    );

    const stats = rows[0] || { total_tasks: 0, pending: 0, approved: 0, rejected: 0 };
    const completionPercentage = stats.total_tasks === 0 ? 0 : Math.round((stats.approved / stats.total_tasks) * 100);

    res.json({
      programId,
      ...stats,
      completionPercentage,
    });
  } catch (err) {
    next(err);
  }
});

router.get('/tasks/:taskId', async (req, res, next) => {
  try {
    const learnerId = req.user.sub;
    const taskId = req.params.taskId;

    const { rows } = await pool.query(
      `SELECT t.id, t.program_id, t.milestone_id, t.title, t.description, t.deadline_at, t.resource_links,
              s.id AS submission_id, s.link AS submission_link, s.notes AS submission_notes, s.status AS submission_status,
              s.feedback_text, s.score
       FROM tasks t
       JOIN programs p ON p.id = t.program_id
       JOIN program_learners pl ON pl.program_id = p.id AND pl.learner_id = $1
       LEFT JOIN submissions s ON s.task_id = t.id AND s.learner_id = $1
       WHERE t.id = $2`,
      [learnerId, taskId]
    );

    const task = rows[0];
    if (!task) throw new HttpError(404, 'Task not found');

    res.json({ task });
  } catch (err) {
    next(err);
  }
});

const submitSchema = z.object({
  link: z.string().url(),
  notes: z.string().max(2000).optional().default(''),
});

router.post('/tasks/:taskId/submit', async (req, res, next) => {
  try {
    const learnerId = req.user.sub;
    const taskId = req.params.taskId;
    const body = submitSchema.parse(req.body);

    const access = await pool.query(
      `SELECT 1
       FROM tasks t
       JOIN programs p ON p.id = t.program_id
       JOIN program_learners pl ON pl.program_id = p.id
       WHERE t.id = $1 AND pl.learner_id = $2`,
      [taskId, learnerId]
    );
    if (access.rowCount === 0) throw new HttpError(403, 'Forbidden');

    const existing = await pool.query(
      `SELECT id
       FROM submissions
       WHERE task_id = $1 AND learner_id = $2
       LIMIT 1`,
      [taskId, learnerId]
    );
    if (existing.rowCount > 0) throw new HttpError(409, 'Already submitted');

    const { rows } = await pool.query(
      `INSERT INTO submissions(task_id, learner_id, link, notes, status)
       VALUES ($1, $2, $3, $4, 'submitted')
       RETURNING id, status`,
      [taskId, learnerId, body.link, body.notes]
    );

    await writeAudit({
      actorUserId: learnerId,
      action: 'learner.submit_task',
      entityType: 'submission',
      entityId: rows[0].id,
      meta: { taskId },
    });

    await pool.query(
      `INSERT INTO notifications(user_id, type, title, body, meta)
       SELECT p.mentor_id, 'submission_submitted', 'New submission', 'A learner submitted a task.', jsonb_build_object('taskId', t.id::text, 'learnerId', $2::text)
       FROM tasks t
       JOIN programs p ON p.id = t.program_id
       WHERE t.id = $1`,
      [taskId, learnerId]
    );

    res.json({ submission: rows[0] });
  } catch (err) {
    next(err);
  }
});

router.get('/performance-report', async (req, res, next) => {
  try {
    const learnerId = req.user.sub;

    const { rows } = await pool.query(
      `SELECT
         COUNT(*) FILTER (WHERE status = 'approved') AS approved,
         COUNT(*) FILTER (WHERE status = 'rejected') AS rejected,
         COUNT(*) FILTER (WHERE status = 'submitted') AS pending,
         COALESCE(AVG(score)::numeric(10,2), 0) AS average_score
       FROM submissions
       WHERE learner_id = $1`,
      [learnerId]
    );

    res.json({ report: rows[0] });
  } catch (err) {
    next(err);
  }
});

module.exports = router;

