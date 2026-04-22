const path = require('path');
const dotenv = require('dotenv');

dotenv.config({path: path.resolve(process.cwd(), '.env'), quiet: true});

function getEnv(name, fallback = '') {
  const value = process.env[name] ?? fallback;
  return typeof value === 'string' ? value.trim() : value;
}

function getCsvEnv(name) {
  const value = getEnv(name);
  if (!value) {
    return [];
  }
  return [...new Set(value.split(',').map((item) => item.trim()).filter(Boolean))];
}

const googleClientId = getEnv('GOOGLE_CLIENT_ID');
const googleClientIds = getCsvEnv('GOOGLE_CLIENT_IDS');

module.exports = {
  port: Number(getEnv('PORT', '3000')),
  googleClientId,
  googleClientIds:
    googleClientIds.length > 0
      ? googleClientIds
      : googleClientId
        ? [googleClientId]
        : [],
  jwtSecret: getEnv('JWT_SECRET'),
  jwtExpiresIn: getEnv('JWT_EXPIRES_IN', '7d'),
  adminEmail: getEnv('ADMIN_EMAIL', 'sabarish9911@gmail.com').toLowerCase(),
  firebaseServiceAccountJson: getEnv('FIREBASE_SERVICE_ACCOUNT_JSON'),
  smtpHost: getEnv('SMTP_HOST'),
  smtpPort: Number(getEnv('SMTP_PORT', '587')),
  smtpSecure: getEnv('SMTP_SECURE', 'false').toLowerCase() === 'true',
  smtpUser: getEnv('SMTP_USER'),
  smtpPass: getEnv('SMTP_PASS'),
  mailFrom: getEnv('MAIL_FROM', 'RK Fuels <no-reply@rkfuels.local>'),
  inventoryAlertRunToken: getEnv('INVENTORY_ALERT_RUN_TOKEN'),
  publicApiBaseUrl: getEnv('PUBLIC_API_BASE_URL'),
  runLegacyDataMigration: getEnv('RUN_LEGACY_DATA_MIGRATION', 'false').toLowerCase() === 'true',
};
