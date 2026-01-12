const dotenv = require('dotenv');

dotenv.config();

function cleanEnvValue(value) {
  if (value == null) return value;
  let v = String(value);
  // Strip common invisible characters that often get introduced by copy/paste.
  v = v.replace(/[\u200B-\u200D\uFEFF]/g, '');
  // Remove leading/trailing whitespace first.
  v = v.trim();
  // Remove any remaining whitespace/newlines inside the value (common Vercel UI issue).
  // This is especially important for URLs.
  v = v.replace(/\s+/g, '');
  // Some hosting UIs accidentally include wrapping quotes.
  if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
    v = v.slice(1, -1).trim();
  }
  return v;
}

function requireEnv(name) {
  const value = cleanEnvValue(process.env[name]);
  if (!value) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
}

const env = {
  nodeEnv: cleanEnvValue(process.env.NODE_ENV) || 'development',
  port: Number(process.env.PORT || 3000),
  databaseUrl: requireEnv('DATABASE_URL'),
  jwtSecret: requireEnv('JWT_SECRET'),
  jwtExpiresIn: cleanEnvValue(process.env.JWT_EXPIRES_IN) || '7d',
  resetTokenExpiresMinutes: Number(process.env.RESET_TOKEN_EXPIRES_MINUTES || 30),
  frontendResetUrl: cleanEnvValue(process.env.FRONTEND_RESET_URL) || '',
  deadlineAlertsEnabled: (process.env.DEADLINE_ALERTS_ENABLED || 'true').toLowerCase() === 'true',
  deadlineAlertHours: Number(process.env.DEADLINE_ALERT_HOURS || 24),
  deadlineAlertIntervalMinutes: Number(process.env.DEADLINE_ALERT_INTERVAL_MINUTES || 10),
};

module.exports = { env };
