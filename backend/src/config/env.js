const dotenv = require('dotenv');

dotenv.config();

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
}

const env = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: Number(process.env.PORT || 3000),
  databaseUrl: requireEnv('DATABASE_URL'),
  jwtSecret: requireEnv('JWT_SECRET'),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  resetTokenExpiresMinutes: Number(process.env.RESET_TOKEN_EXPIRES_MINUTES || 30),
  frontendResetUrl: process.env.FRONTEND_RESET_URL || '',
  deadlineAlertsEnabled: (process.env.DEADLINE_ALERTS_ENABLED || 'true').toLowerCase() === 'true',
  deadlineAlertHours: Number(process.env.DEADLINE_ALERT_HOURS || 24),
  deadlineAlertIntervalMinutes: Number(process.env.DEADLINE_ALERT_INTERVAL_MINUTES || 10),
};

module.exports = { env };
