const express = require('express');
const bcrypt = require('bcryptjs');
const { z } = require('zod');

const { pool } = require('../db/pool');
const { requireAuth, requireRole } = require('../middleware/auth');
const { HttpError } = require('../utils/httpErrors');
const { writeAudit } = require('../utils/audit');

const router = express.Router();

router.use(requireAuth);
router.use(requireRole('admin'));

router.get('/audit-logs', async (req, res, next) => {
  try {
    const limit = Math.min(Number(req.query.limit || 20), 50);
    const offset = Math.max(Number(req.query.offset || 0), 0);
    const actorUserId = req.query.actorUserId;

    const params = [limit, offset];
    let actorClause = '';
    if (actorUserId) {
      params.push(actorUserId);
      actorClause = ` WHERE al.actor_user_id = $3`;
    }

    const { rows } = await pool.query(
      `SELECT al.id, al.actor_user_id, u.full_name AS actor_name, al.action, al.entity_type, al.entity_id, al.meta, al.created_at
       FROM audit_logs al
       LEFT JOIN users u ON u.id = al.actor_user_id
       ${actorClause}
       ORDER BY al.created_at DESC
       LIMIT $1 OFFSET $2`,
      params
    );

    res.json({ items: rows, limit, offset });
  } catch (err) {
    next(err);
  }
});

router.get('/programs', async (req, res, next) => {
  try {
    const limit = Math.min(Number(req.query.limit || 20), 50);
    const offset = Math.max(Number(req.query.offset || 0), 0);

    const { rows } = await pool.query(
      `SELECT p.id, p.title, p.description, p.mentor_id, u.full_name AS mentor_name, p.created_at
       FROM programs p
       JOIN users u ON u.id = p.mentor_id
       ORDER BY p.created_at DESC
       LIMIT $1 OFFSET $2`,
      [limit, offset]
    );

    res.json({ items: rows, limit, offset });
  } catch (err) {
    next(err);
  }
});

router.get('/programs/:programId', async (req, res, next) => {
  try {
    const programId = req.params.programId;

    const program = await pool.query(
      `SELECT p.id, p.title, p.description, p.mentor_id, u.full_name AS mentor_name, p.created_at
       FROM programs p
       JOIN users u ON u.id = p.mentor_id
       WHERE p.id = $1`,
      [programId]
    );
    if (program.rowCount === 0) throw new HttpError(404, 'Program not found');

    const learners = await pool.query(
      `SELECT u.id, u.full_name, u.email
       FROM program_learners pl
       JOIN users u ON u.id = pl.learner_id
       WHERE pl.program_id = $1
       ORDER BY u.full_name ASC`,
      [programId]
    );

    const milestones = await pool.query(
      `SELECT id, title, sort_order
       FROM milestones
       WHERE program_id = $1
       ORDER BY sort_order ASC, created_at ASC`,
      [programId]
    );

    res.json({
      program: program.rows[0],
      learners: learners.rows,
      milestones: milestones.rows,
    });
  } catch (err) {
    next(err);
  }
});

router.get('/programs/:programId/reviews', async (req, res, next) => {
  try {
    const programId = req.params.programId;
    const limit = Math.min(Number(req.query.limit || 20), 50);
    const offset = Math.max(Number(req.query.offset || 0), 0);

    const program = await pool.query('SELECT 1 FROM programs WHERE id = $1', [programId]);
    if (program.rowCount === 0) throw new HttpError(404, 'Program not found');

    const summaryRes = await pool.query(
      `SELECT
         COUNT(*)::int AS total_reviews,
         COALESCE(AVG(rating), 0)::numeric(10,2) AS average_rating
       FROM program_reviews
       WHERE program_id = $1`,
      [programId]
    );
    const summary = summaryRes.rows[0] || { total_reviews: 0, average_rating: '0.00' };

    const { rows } = await pool.query(
      `SELECT pr.id, pr.rating, pr.feedback, pr.created_at,
              u.id AS learner_id, u.full_name AS learner_name, u.email AS learner_email
       FROM program_reviews pr
       JOIN users u ON u.id = pr.learner_id
       WHERE pr.program_id = $1
       ORDER BY pr.created_at DESC
       LIMIT $2 OFFSET $3`,
      [programId, limit, offset]
    );

    res.json({
      summary: { totalReviews: summary.total_reviews, averageRating: summary.average_rating },
      items: rows,
      limit,
      offset,
    });
  } catch (err) {
    next(err);
  }
});

router.get('/users', async (req, res, next) => {
  try {
    const limit = Math.min(Number(req.query.limit || 20), 50);
    const offset = Math.max(Number(req.query.offset || 0), 0);
    const role = req.query.role;

    const params = [limit, offset];
    let roleClause = '';
    if (role) {
      params.push(role);
      roleClause = ` WHERE role = $3`;
    }

    const { rows } = await pool.query(
      `SELECT id, email, role, full_name, created_at
       FROM users${roleClause}
       ORDER BY created_at DESC
       LIMIT $1 OFFSET $2`,
      params
    );

    res.json({ items: rows, limit, offset });
  } catch (err) {
    next(err);
  }
});

const createUserSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
  role: z.enum(['learner', 'mentor', 'admin']),
  fullName: z.string().min(2).max(200),
});

router.post('/users', async (req, res, next) => {
  try {
    const body = createUserSchema.parse(req.body);
    const passwordHash = await bcrypt.hash(body.password, 10);

    const { rows } = await pool.query(
      `INSERT INTO users(email, password_hash, role, full_name)
       VALUES ($1, $2, $3, $4)
       RETURNING id, email, role, full_name`,
      [body.email.toLowerCase(), passwordHash, body.role, body.fullName]
    );

    await writeAudit({
      actorUserId: req.user.sub,
      action: 'admin.create_user',
      entityType: 'user',
      entityId: rows[0].id,
      meta: { role: rows[0].role },
    });

    res.status(201).json({ user: rows[0] });
  } catch (err) {
    if (String(err.message || '').includes('users_email_key')) {
      return next(new HttpError(409, 'Email already exists'));
    }
    next(err);
  }
});

const createProgramSchema = z.object({
  title: z.string().min(2).max(200),
  description: z.string().max(2000).optional().default(''),
  mentorId: z.string().uuid(),
});

const createProgramWithStructureSchema = z.object({
  title: z.string().min(2).max(200),
  description: z.string().max(2000).optional().default(''),
  mentorId: z.string().uuid(),
  modules: z
    .array(
      z.object({
        title: z.string().min(2).max(200),
        sortOrder: z.number().int().min(0).max(10000).optional().default(0),
        chapters: z
          .array(
            z.object({
              title: z.string().min(2).max(200),
              sortOrder: z.number().int().min(0).max(10000).optional().default(0),
              bodyMd: z.string().max(50000).optional().default(''),
            })
          )
          .optional()
          .default([]),
        items: z
          .array(
            z.object({
              title: z.string().min(2).max(200),
              description: z.string().max(5000).optional().default(''),
              deadlineAt: z.coerce.date(),
              resourceLinks: z.array(z.string().url()).optional().default([]),
            })
          )
          .optional()
          .default([]),
      })
    )
    .optional()
    .default([]),
});

router.post('/programs', async (req, res, next) => {
  try {
    const body = createProgramSchema.parse(req.body);

    const mentor = await pool.query('SELECT 1 FROM users WHERE id = $1 AND role = $2', [body.mentorId, 'mentor']);
    if (mentor.rowCount === 0) throw new HttpError(400, 'Invalid mentorId');

    const { rows } = await pool.query(
      `INSERT INTO programs(title, description, mentor_id)
       VALUES ($1, $2, $3)
       RETURNING id, title, description, mentor_id`,
      [body.title, body.description, body.mentorId]
    );

    await writeAudit({
      actorUserId: req.user.sub,
      action: 'admin.create_program',
      entityType: 'program',
      entityId: rows[0].id,
      meta: { mentorId: rows[0].mentor_id },
    });

    res.status(201).json({ program: rows[0] });
  } catch (err) {
    next(err);
  }
});

router.post('/programs/with-structure', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const body = createProgramWithStructureSchema.parse(req.body);

    const mentor = await client.query('SELECT 1 FROM users WHERE id = $1 AND role = $2', [body.mentorId, 'mentor']);
    if (mentor.rowCount === 0) throw new HttpError(400, 'Invalid mentorId');

    await client.query('BEGIN');

    const programRes = await client.query(
      `INSERT INTO programs(title, description, mentor_id)
       VALUES ($1, $2, $3)
       RETURNING id, title, description, mentor_id`,
      [body.title, body.description, body.mentorId]
    );
    const program = programRes.rows[0];

    await client.query(
      `INSERT INTO audit_logs(actor_user_id, action, entity_type, entity_id, meta)
       VALUES ($1, 'admin.create_program', 'program', $2, jsonb_build_object('mentorId', $3::text))`,
      [req.user.sub, program.id, body.mentorId]
    );

    for (const mod of body.modules) {
      // eslint-disable-next-line no-await-in-loop
      const msRes = await client.query(
        `INSERT INTO milestones(program_id, title, sort_order)
         VALUES ($1, $2, $3)
         RETURNING id`,
        [program.id, mod.title, mod.sortOrder]
      );
      const milestoneId = msRes.rows[0].id;

      // eslint-disable-next-line no-await-in-loop
      await client.query(
        `INSERT INTO audit_logs(actor_user_id, action, entity_type, entity_id, meta)
         VALUES ($1, 'admin.create_module', 'milestone', $2, jsonb_build_object('programId', $3::text))`,
        [req.user.sub, milestoneId, program.id]
      );

      for (const chapter of mod.chapters) {
        // eslint-disable-next-line no-await-in-loop
        const chRes = await client.query(
          `INSERT INTO module_chapters(milestone_id, title, sort_order, body_md)
           VALUES ($1, $2, $3, $4)
           RETURNING id`,
          [milestoneId, chapter.title, chapter.sortOrder, chapter.bodyMd]
        );

        // eslint-disable-next-line no-await-in-loop
        await client.query(
          `INSERT INTO audit_logs(actor_user_id, action, entity_type, entity_id, meta)
           VALUES ($1, 'admin.create_module_chapter', 'module_chapter', $2, jsonb_build_object('programId', $3::text, 'moduleId', $4::text))`,
          [req.user.sub, chRes.rows[0].id, program.id, milestoneId]
        );
      }

      for (const item of mod.items) {
        // eslint-disable-next-line no-await-in-loop
        const taskRes = await client.query(
          `INSERT INTO tasks(program_id, milestone_id, title, description, deadline_at, resource_links)
           VALUES ($1, $2, $3, $4, $5, $6::jsonb)
           RETURNING id`,
          [
            program.id,
            milestoneId,
            item.title,
            item.description,
            item.deadlineAt.toISOString(),
            JSON.stringify(item.resourceLinks),
          ]
        );

        // eslint-disable-next-line no-await-in-loop
        await client.query(
          `INSERT INTO audit_logs(actor_user_id, action, entity_type, entity_id, meta)
           VALUES ($1, 'admin.create_module_item', 'task', $2, jsonb_build_object('programId', $3::text, 'moduleId', $4::text))`,
          [req.user.sub, taskRes.rows[0].id, program.id, milestoneId]
        );
      }
    }

    await client.query('COMMIT');
    res.status(201).json({ program });
  } catch (err) {
    try {
      // Best-effort rollback if BEGIN succeeded.
      // eslint-disable-next-line no-await-in-loop
      await client.query('ROLLBACK');
    } catch (_) {
      // ignore
    }
    next(err);
  } finally {
    client.release();
  }
});

const assignLearnerSchema = z.object({ learnerId: z.string().uuid() });

const assignMentorSchema = z.object({ mentorId: z.string().uuid() });

router.post('/programs/:programId/assign-learner', async (req, res, next) => {
  try {
    const programId = req.params.programId;
    const body = assignLearnerSchema.parse(req.body);

    const learner = await pool.query('SELECT 1 FROM users WHERE id = $1 AND role = $2', [body.learnerId, 'learner']);
    if (learner.rowCount === 0) throw new HttpError(400, 'Invalid learnerId');

    await pool.query(
      `INSERT INTO program_learners(program_id, learner_id)
       VALUES ($1, $2)
       ON CONFLICT DO NOTHING`,
      [programId, body.learnerId]
    );

    await writeAudit({
      actorUserId: req.user.sub,
      action: 'admin.assign_learner',
      entityType: 'program',
      entityId: programId,
      meta: { learnerId: body.learnerId },
    });

    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

router.post('/programs/:programId/assign-mentor', async (req, res, next) => {
  try {
    const programId = req.params.programId;
    const body = assignMentorSchema.parse(req.body);

    const mentor = await pool.query('SELECT 1 FROM users WHERE id = $1 AND role = $2', [body.mentorId, 'mentor']);
    if (mentor.rowCount === 0) throw new HttpError(400, 'Invalid mentorId');

    const updated = await pool.query(
      `UPDATE programs
       SET mentor_id = $2
       WHERE id = $1
       RETURNING id, mentor_id`,
      [programId, body.mentorId]
    );
    if (updated.rowCount === 0) throw new HttpError(404, 'Program not found');

    await writeAudit({
      actorUserId: req.user.sub,
      action: 'admin.assign_mentor',
      entityType: 'program',
      entityId: programId,
      meta: { mentorId: body.mentorId },
    });

    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

const createMilestoneSchema = z.object({
  title: z.string().min(2).max(200),
  sortOrder: z.number().int().min(0).max(10000).optional().default(0),
});

router.post('/programs/:programId/milestones', async (req, res, next) => {
  try {
    const programId = req.params.programId;
    const body = createMilestoneSchema.parse(req.body);

    const { rows } = await pool.query(
      `INSERT INTO milestones(program_id, title, sort_order)
       VALUES ($1, $2, $3)
       RETURNING id, program_id, title, sort_order`,
      [programId, body.title, body.sortOrder]
    );

    await writeAudit({
      actorUserId: req.user.sub,
      action: 'admin.create_milestone',
      entityType: 'milestone',
      entityId: rows[0].id,
      meta: { programId },
    });

    res.status(201).json({ milestone: rows[0] });
  } catch (err) {
    next(err);
  }
});

const createTaskSchema = z.object({
  milestoneId: z.string().uuid().optional().nullable(),
  title: z.string().min(2).max(200),
  description: z.string().max(5000).optional().default(''),
  deadlineAt: z.coerce.date(),
  resourceLinks: z.array(z.string().url()).optional().default([]),
});

router.post('/programs/:programId/tasks', async (req, res, next) => {
  try {
    const programId = req.params.programId;
    const body = createTaskSchema.parse(req.body);

    if (body.milestoneId) {
      const ms = await pool.query('SELECT 1 FROM milestones WHERE id = $1 AND program_id = $2', [body.milestoneId, programId]);
      if (ms.rowCount === 0) throw new HttpError(400, 'Invalid milestoneId for program');
    }

    const { rows } = await pool.query(
      `INSERT INTO tasks(program_id, milestone_id, title, description, deadline_at, resource_links)
       VALUES ($1, $2, $3, $4, $5, $6::jsonb)
       RETURNING id, program_id, milestone_id, title, deadline_at`,
      [
        programId,
        body.milestoneId ?? null,
        body.title,
        body.description,
        body.deadlineAt.toISOString(),
        JSON.stringify(body.resourceLinks),
      ]
    );

    await writeAudit({
      actorUserId: req.user.sub,
      action: 'admin.create_task',
      entityType: 'task',
      entityId: rows[0].id,
      meta: { programId, milestoneId: rows[0].milestone_id },
    });

    res.status(201).json({ task: rows[0] });
  } catch (err) {
    next(err);
  }
});

router.get('/analytics/completion-trends', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT DATE_TRUNC('week', s.created_at) AS week,
              COUNT(*) FILTER (WHERE s.status = 'approved')::int AS approved,
              COUNT(*) FILTER (WHERE s.status = 'rejected')::int AS rejected,
              COUNT(*) FILTER (WHERE s.status = 'submitted')::int AS submitted
       FROM submissions s
       GROUP BY 1
       ORDER BY 1 DESC
       LIMIT 12`
    );

    res.json({ items: rows });
  } catch (err) {
    next(err);
  }
});

router.get('/analytics/learner-ranking', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT u.id, u.full_name, u.email,
              COUNT(*) FILTER (WHERE s.status = 'approved')::int AS approved_count,
              COALESCE(AVG(s.score), 0)::numeric(10,2) AS avg_score
       FROM users u
       LEFT JOIN submissions s ON s.learner_id = u.id
       WHERE u.role = 'learner'
       GROUP BY u.id
       ORDER BY approved_count DESC, avg_score DESC
       LIMIT 50`
    );

    res.json({ items: rows });
  } catch (err) {
    next(err);
  }
});

module.exports = router;

