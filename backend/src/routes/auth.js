const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { z } = require('zod');

const { env } = require('../config/env');
const { pool } = require('../db/pool');
const { HttpError } = require('../utils/httpErrors');
const { requireAuth } = require('../middleware/auth');
const { writeAudit } = require('../utils/audit');

const router = express.Router();

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
});

const signupSchema = z.object({
  fullName: z.string().trim().min(2),
  email: z.string().email(),
  password: z.string().min(6),
});

router.post('/login', async (req, res, next) => {
  try {
    const body = loginSchema.parse(req.body);
    const { rows } = await pool.query(
      'SELECT id, email, password_hash, role, full_name FROM users WHERE email = $1',
      [body.email.toLowerCase()]
    );
    const user = rows[0];
    if (!user) throw new HttpError(401, 'Invalid credentials');

    const ok = await bcrypt.compare(body.password, user.password_hash);
    if (!ok) throw new HttpError(401, 'Invalid credentials');

    const token = jwt.sign(
      { sub: user.id, role: user.role, email: user.email },
      env.jwtSecret,
      { expiresIn: env.jwtExpiresIn }
    );

    res.json({
      token,
      user: { id: user.id, email: user.email, role: user.role, fullName: user.full_name },
    });
  } catch (err) {
    next(err);
  }
});

router.post('/signup', async (req, res, next) => {
  try {
    const body = signupSchema.parse(req.body);
    const email = body.email.toLowerCase();

    const passwordHash = await bcrypt.hash(body.password, 10);

    let user;
    try {
      const { rows } = await pool.query(
        `INSERT INTO users(email, password_hash, role, full_name)
         VALUES ($1, $2, 'learner', $3)
         RETURNING id, email, role, full_name`,
        [email, passwordHash, body.fullName]
      );
      user = rows[0];
    } catch (e) {
      // Unique violation (email already exists)
      if (e && e.code === '23505') {
        throw new HttpError(409, 'Email is already registered');
      }
      throw e;
    }

    await writeAudit({
      actorUserId: null,
      action: 'learner_signup',
      entityType: 'user',
      entityId: user.id,
      meta: { email: user.email, role: user.role },
    });

    const token = jwt.sign(
      { sub: user.id, role: user.role, email: user.email },
      env.jwtSecret,
      { expiresIn: env.jwtExpiresIn }
    );

    res.status(201).json({
      token,
      user: { id: user.id, email: user.email, role: user.role, fullName: user.full_name },
    });
  } catch (err) {
    next(err);
  }
});

router.get('/me', requireAuth, async (req, res, next) => {
  try {
    const userId = req.user.sub;
    const { rows } = await pool.query(
      'SELECT id, email, role, full_name, created_at FROM users WHERE id = $1',
      [userId]
    );
    const user = rows[0];
    if (!user) throw new HttpError(404, 'User not found');
    res.json({ user: { id: user.id, email: user.email, role: user.role, fullName: user.full_name } });
  } catch (err) {
    next(err);
  }
});

const requestResetSchema = z.object({ email: z.string().email() });

router.post('/request-password-reset', async (req, res, next) => {
  try {
    const body = requestResetSchema.parse(req.body);
    const email = body.email.toLowerCase();

    const { rows } = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
    const user = rows[0];

    // Always return 200 to avoid account enumeration.
    if (!user) return res.json({ ok: true });

    const token = require('crypto').randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + env.resetTokenExpiresMinutes * 60 * 1000);

    await pool.query(
      'INSERT INTO password_resets(user_id, token, expires_at) VALUES ($1, $2, $3)',
      [user.id, token, expiresAt]
    );

    // Production: send by email. Dev: log it.
    // eslint-disable-next-line no-console
    console.log('Password reset link:', `${env.frontendResetUrl}${token}`);

    return res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

const resetSchema = z.object({
  token: z.string().min(10),
  newPassword: z.string().min(6),
});

router.post('/reset-password', async (req, res, next) => {
  try {
    const body = resetSchema.parse(req.body);

    const { rows } = await pool.query(
      `SELECT pr.id, pr.user_id
       FROM password_resets pr
       WHERE pr.token = $1 AND pr.used_at IS NULL AND pr.expires_at > NOW()
       ORDER BY pr.created_at DESC
       LIMIT 1`,
      [body.token]
    );

    const reset = rows[0];
    if (!reset) throw new HttpError(400, 'Invalid or expired reset token');

    const passwordHash = await bcrypt.hash(body.newPassword, 10);

    await pool.query('BEGIN');
    await pool.query('UPDATE users SET password_hash = $1 WHERE id = $2', [passwordHash, reset.user_id]);
    await pool.query('UPDATE password_resets SET used_at = NOW() WHERE id = $1', [reset.id]);
    await pool.query('COMMIT');

    res.json({ ok: true });
  } catch (err) {
    try {
      await pool.query('ROLLBACK');
    } catch (_) {}
    next(err);
  }
});

module.exports = router;
