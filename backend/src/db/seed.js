const bcrypt = require('bcryptjs');

const { pool } = require('./pool');

async function ensureUser({ email, password, role, fullName }) {
  const existing = await pool.query('SELECT id FROM users WHERE email = $1', [email.toLowerCase()]);
  if (existing.rowCount > 0) return existing.rows[0].id;

  const passwordHash = await bcrypt.hash(password, 10);
  const created = await pool.query(
    `INSERT INTO users(email, password_hash, role, full_name)
     VALUES ($1, $2, $3, $4)
     RETURNING id`,
    [email.toLowerCase(), passwordHash, role, fullName]
  );
  return created.rows[0].id;
}

async function ensureProgram({ title, description, mentorId }) {
  const existing = await pool.query('SELECT id FROM programs WHERE title = $1', [title]);
  if (existing.rowCount > 0) return existing.rows[0].id;

  const created = await pool.query(
    `INSERT INTO programs(title, description, mentor_id)
     VALUES ($1, $2, $3)
     RETURNING id`,
    [title, description, mentorId]
  );
  return created.rows[0].id;
}

async function ensureMilestone({ programId, title, sortOrder }) {
  const existing = await pool.query('SELECT id FROM milestones WHERE program_id = $1 AND title = $2', [programId, title]);
  if (existing.rowCount > 0) return existing.rows[0].id;

  const created = await pool.query(
    `INSERT INTO milestones(program_id, title, sort_order)
     VALUES ($1, $2, $3)
     RETURNING id`,
    [programId, title, sortOrder]
  );
  return created.rows[0].id;
}

async function ensureTask({ programId, milestoneId, title, description, deadlineAt, resourceLinks }) {
  const existing = await pool.query('SELECT id FROM tasks WHERE program_id = $1 AND title = $2', [programId, title]);
  if (existing.rowCount > 0) return existing.rows[0].id;

  const created = await pool.query(
    `INSERT INTO tasks(program_id, milestone_id, title, description, deadline_at, resource_links)
     VALUES ($1, $2, $3, $4, $5, $6::jsonb)
     RETURNING id`,
    [programId, milestoneId, title, description, deadlineAt, JSON.stringify(resourceLinks ?? [])]
  );
  return created.rows[0].id;
}

async function ensureLearnerAssignment({ programId, learnerId }) {
  await pool.query(
    `INSERT INTO program_learners(program_id, learner_id)
     VALUES ($1, $2)
     ON CONFLICT DO NOTHING`,
    [programId, learnerId]
  );
}

async function ensureSubmission({ taskId, learnerId, link, notes, status, reviewedBy, feedbackText, score }) {
  const existing = await pool.query('SELECT id FROM submissions WHERE task_id = $1 AND learner_id = $2', [taskId, learnerId]);
  if (existing.rowCount > 0) return existing.rows[0].id;

  const reviewedAt = status === 'approved' || status === 'rejected' ? new Date().toISOString() : null;

  const created = await pool.query(
    `INSERT INTO submissions(task_id, learner_id, link, notes, status, feedback_text, score, reviewed_by, reviewed_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
     RETURNING id`,
    [taskId, learnerId, link, notes, status, feedbackText ?? null, score ?? null, reviewedBy ?? null, reviewedAt]
  );
  return created.rows[0].id;
}

async function seed() {
  const adminEmail = process.env.SEED_ADMIN_EMAIL || 'admin@skilltrack.local';
  const mentorEmail = process.env.SEED_MENTOR_EMAIL || 'mentor@skilltrack.local';
  const learnerEmail = process.env.SEED_LEARNER_EMAIL || 'learner@skilltrack.local';
  const password = process.env.SEED_DEFAULT_PASSWORD || 'Password123!';
  const seedDemoData = String(process.env.SEED_DEMO_DATA || 'true').toLowerCase() === 'true';

  const adminId = await ensureUser({
    email: adminEmail,
    password,
    role: 'admin',
    fullName: 'SkillTrack Admin',
  });

  const mentorId = await ensureUser({
    email: mentorEmail,
    password,
    role: 'mentor',
    fullName: 'SkillTrack Mentor',
  });

  const learnerId = await ensureUser({
    email: learnerEmail,
    password,
    role: 'learner',
    fullName: 'SkillTrack Learner',
  });

  let demo = null;
  if (seedDemoData) {
    const programId = await ensureProgram({
      title: process.env.SEED_DEMO_PROGRAM_TITLE || 'Flutter Internship Track',
      description:
        process.env.SEED_DEMO_PROGRAM_DESCRIPTION ||
        'A guided track with milestones, tasks, and mentor reviews to simulate a real internship workflow.',
      mentorId,
    });

    await ensureLearnerAssignment({ programId, learnerId });

    const m1 = await ensureMilestone({ programId, title: 'Onboarding', sortOrder: 1 });
    const m2 = await ensureMilestone({ programId, title: 'Core Delivery', sortOrder: 2 });

    const daysFromNow = (days) => new Date(Date.now() + days * 24 * 60 * 60 * 1000).toISOString();

    const t1 = await ensureTask({
      programId,
      milestoneId: m1,
      title: 'Project Setup & Git Workflow',
      description: 'Set up the repo locally, understand branches, and document your workflow.',
      deadlineAt: daysFromNow(3),
      resourceLinks: ['https://docs.github.com/en/get-started/using-git/about-git'],
    });

    const t2 = await ensureTask({
      programId,
      milestoneId: m2,
      title: 'Build Learner Program Flow',
      description: 'Implement program browsing, milestones, tasks list, and submission UI in Flutter.',
      deadlineAt: daysFromNow(7),
      resourceLinks: ['https://docs.flutter.dev/'],
    });

    const t3 = await ensureTask({
      programId,
      milestoneId: m2,
      title: 'Mentor Review + Notifications',
      description: 'Review submissions and validate notifications appear for the learner.',
      deadlineAt: daysFromNow(10),
      resourceLinks: ['https://pub.dev/packages/go_router'],
    });

    // Optional sample submissions to make mentor/admin screens non-empty.
    await ensureSubmission({
      taskId: t1,
      learnerId,
      link: 'https://example.com/submission/1',
      notes: 'Initial setup done. Please review.',
      status: 'submitted',
    });

    await ensureSubmission({
      taskId: t2,
      learnerId,
      link: 'https://example.com/submission/2',
      notes: 'Implemented screens and routing.',
      status: 'approved',
      reviewedBy: mentorId,
      feedbackText: 'Nice work — clean UI and solid error handling.',
      score: 92,
    });

    demo = { programId, milestones: [m1, m2], tasks: [t1, t2, t3] };
  }

  // eslint-disable-next-line no-console
  console.log('Seed complete:', { adminId, mentorId, learnerId, password, demo });
}

seed()
  .catch((err) => {
    // eslint-disable-next-line no-console
    console.error('Seed failed:', err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await pool.end();
  });
