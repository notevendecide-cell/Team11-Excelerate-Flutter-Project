const express = require('express');
const { z } = require('zod');

const { pool } = require('../db/pool');
const { requireAuth, requireRole } = require('../middleware/auth');
const { HttpError } = require('../utils/httpErrors');
const { writeAudit } = require('../utils/audit');

const router = express.Router();

router.use(requireAuth);
router.use(requireRole('mentor'));

router.get('/programs', async (req, res, next) => {
  try {
    const mentorId = req.user.sub;
    const limit = Math.min(Number(req.query.limit || 20), 50);
    const offset = Math.max(Number(req.query.offset || 0), 0);

    const { rows } = await pool.query(
      `SELECT p.id, p.title, p.description, p.created_at,
              COUNT(DISTINCT pl.learner_id)::int AS learner_count,
              COUNT(DISTINCT t.id)::int AS task_count
       FROM programs p
       LEFT JOIN program_learners pl ON pl.program_id = p.id
       LEFT JOIN tasks t ON t.program_id = p.id
       WHERE p.mentor_id = $1
       GROUP BY p.id
       ORDER BY p.created_at DESC
       LIMIT $2 OFFSET $3`,
      [mentorId, limit, offset]
    );

    res.json({ items: rows, limit, offset });
  } catch (err) {
    next(err);
  }
});

router.get('/programs/:programId/overview', async (req, res, next) => {
  try {
    const mentorId = req.user.sub;
    const programId = req.params.programId;

    const access = await pool.query('SELECT 1 FROM programs WHERE id = $1 AND mentor_id = $2', [programId, mentorId]);
    if (access.rowCount === 0) throw new HttpError(404, 'Program not found');

    const learners = await pool.query(
      `SELECT u.id, u.full_name, u.email
       FROM program_learners pl
       JOIN users u ON u.id = pl.learner_id
       WHERE pl.program_id = $1
       ORDER BY u.full_name ASC`,
      [programId]
    );

    const tasks = await pool.query(
      `SELECT t.id, t.title, t.deadline_at,
              COUNT(s.id)::int AS submissions,
              COUNT(s.id) FILTER (WHERE s.status = 'submitted')::int AS pending,
              COUNT(s.id) FILTER (WHERE s.status = 'approved')::int AS approved,
              COUNT(s.id) FILTER (WHERE s.status = 'rejected')::int AS rejected
       FROM tasks t
       LEFT JOIN submissions s ON s.task_id = t.id
       WHERE t.program_id = $1
       GROUP BY t.id
       ORDER BY t.deadline_at ASC`,
      [programId]
    );

    res.json({ programId, learners: learners.rows, tasks: tasks.rows });
  } catch (err) {
    next(err);
  }
});

router.get('/dashboard', async (req, res, next) => {
  try {
    const mentorId = req.user.sub;

    const assignedLearners = await pool.query(
      `SELECT DISTINCT u.id, u.full_name, u.email
       FROM users u
       JOIN program_learners pl ON pl.learner_id = u.id
       JOIN programs p ON p.id = pl.program_id
       WHERE p.mentor_id = $1
       ORDER BY u.full_name ASC`,
      [mentorId]
    );

    const pendingReviews = await pool.query(
      `SELECT COUNT(*)::int AS count
       FROM submissions s
       JOIN tasks t ON t.id = s.task_id
       JOIN programs p ON p.id = t.program_id
       WHERE p.mentor_id = $1 AND s.status = 'submitted'`,
      [mentorId]
    );

    const programOverview = await pool.query(
      `SELECT p.id, p.title,
              COUNT(pl.learner_id)::int AS learner_count,
              COUNT(t.id)::int AS task_count
       FROM programs p
       LEFT JOIN program_learners pl ON pl.program_id = p.id
       LEFT JOIN tasks t ON t.program_id = p.id
       WHERE p.mentor_id = $1
       GROUP BY p.id
       ORDER BY p.created_at DESC`,
      [mentorId]
    );

    res.json({
      assignedLearners: assignedLearners.rows,
      pendingReviews: pendingReviews.rows[0]?.count || 0,
      programs: programOverview.rows,
    });
  } catch (err) {
    next(err);
  }
});

router.get('/submissions', async (req, res, next) => {
  try {
    const mentorId = req.user.sub;
    const limit = Math.min(Number(req.query.limit || 20), 50);
    const offset = Math.max(Number(req.query.offset || 0), 0);
    const status = req.query.status;

    const params = [mentorId, limit, offset];
    let statusClause = '';
    if (status) {
      params.push(status);
      statusClause = ` AND s.status = $4`;
    }

    const { rows } = await pool.query(
      `SELECT s.id, s.status, s.link, s.notes, s.score, s.feedback_text, s.created_at,
              u.id AS learner_id, u.full_name AS learner_name,
              t.id AS task_id, t.title AS task_title
       FROM submissions s
       JOIN users u ON u.id = s.learner_id
       JOIN tasks t ON t.id = s.task_id
       JOIN programs p ON p.id = t.program_id
       WHERE p.mentor_id = $1${statusClause}
       ORDER BY s.created_at DESC
       LIMIT $2 OFFSET $3`,
      params
    );

    res.json({ items: rows, limit, offset });
  } catch (err) {
    next(err);
  }
});

router.get('/submissions/:submissionId', async (req, res, next) => {
  try {
    const mentorId = req.user.sub;
    const submissionId = req.params.submissionId;

    const { rows } = await pool.query(
      `SELECT s.id, s.status, s.link, s.notes, s.score, s.feedback_text, s.created_at, s.reviewed_at,
              u.id AS learner_id, u.full_name AS learner_name, u.email AS learner_email,
              t.id AS task_id, t.title AS task_title, t.deadline_at,
              p.id AS program_id, p.title AS program_title
       FROM submissions s
       JOIN users u ON u.id = s.learner_id
       JOIN tasks t ON t.id = s.task_id
       JOIN programs p ON p.id = t.program_id
       WHERE s.id = $1 AND p.mentor_id = $2
       LIMIT 1`,
      [submissionId, mentorId]
    );

    const submission = rows[0];
    if (!submission) throw new HttpError(404, 'Submission not found');

    res.json({ submission });
  } catch (err) {
    next(err);
  }
});

const reviewSchema = z.object({
  decision: z.enum(['approved', 'rejected']),
  feedbackText: z.string().max(2000).optional().default(''),
  score: z.number().int().min(0).max(100).optional(),
});

router.post('/submissions/:submissionId/review', async (req, res, next) => {
  try {
    const mentorId = req.user.sub;
    const submissionId = req.params.submissionId;
    const body = reviewSchema.parse(req.body);

    const { rows } = await pool.query(
      `UPDATE submissions s
       SET status = $1,
           feedback_text = $2,
           score = $3,
           reviewed_by = $4,
           reviewed_at = NOW(),
           updated_at = NOW()
       FROM tasks t
       JOIN programs p ON p.id = t.program_id
       WHERE s.id = $5 AND s.task_id = t.id AND p.mentor_id = $4
       RETURNING s.id, s.status, s.learner_id, s.task_id`,
      [body.decision, body.feedbackText, body.score ?? null, mentorId, submissionId]
    );

    const updated = rows[0];
    if (!updated) throw new HttpError(404, 'Submission not found');

    await writeAudit({
      actorUserId: mentorId,
      action: 'mentor.review_submission',
      entityType: 'submission',
      entityId: updated.id,
      meta: { decision: updated.status, taskId: updated.task_id, learnerId: updated.learner_id },
    });

    await pool.query(
      `INSERT INTO notifications(user_id, type, title, body, meta)
       VALUES ($1, 'submission_reviewed', 'Submission reviewed', 'Your submission was reviewed.', jsonb_build_object('submissionId', $2::text, 'taskId', $3::text, 'status', $4::text))`,
      [updated.learner_id, updated.id, updated.task_id, updated.status]
    );

    res.json({ submission: updated });
  } catch (err) {
    next(err);
  }
});

router.get('/learners/:learnerId/timeline', async (req, res, next) => {
  try {
    const mentorId = req.user.sub;
    const learnerId = req.params.learnerId;

    const access = await pool.query(
      `SELECT 1
       FROM programs p
       JOIN program_learners pl ON pl.program_id = p.id
       WHERE p.mentor_id = $1 AND pl.learner_id = $2
       LIMIT 1`,
      [mentorId, learnerId]
    );
    if (access.rowCount === 0) throw new HttpError(403, 'Forbidden');

    const { rows } = await pool.query(
      `SELECT s.id, s.status, s.score, s.feedback_text, s.created_at, s.reviewed_at,
              t.id AS task_id, t.title AS task_title, t.deadline_at
       FROM submissions s
       JOIN tasks t ON t.id = s.task_id
       WHERE s.learner_id = $1
       ORDER BY COALESCE(s.reviewed_at, s.created_at) DESC
       LIMIT 100`,
      [learnerId]
    );

    res.json({ items: rows });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
