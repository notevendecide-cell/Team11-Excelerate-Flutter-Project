const express = require('express');
const cors = require('cors');
const helmet = require('helmet');

const { errorHandler } = require('./middleware/errorHandler');
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
