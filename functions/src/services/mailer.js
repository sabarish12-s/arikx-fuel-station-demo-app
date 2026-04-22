const nodemailer = require('nodemailer');
const {
  smtpHost,
  smtpPort,
  smtpSecure,
  smtpUser,
  smtpPass,
  mailFrom,
} = require('../config/env');

let transporter;

function getTransporter() {
  if (!smtpHost || !smtpUser || !smtpPass) {
    return null;
  }
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: smtpHost,
      port: smtpPort,
      secure: smtpSecure,
      auth: {
        user: smtpUser,
        pass: smtpPass,
      },
    });
  }
  return transporter;
}

async function sendMail({to, subject, text, html}) {
  const tx = getTransporter();
  if (!tx) {
    return {sent: false, skipped: true};
  }
  await tx.sendMail({
    from: mailFrom,
    to,
    subject,
    text,
    html,
  });
  return {sent: true};
}

module.exports = {sendMail};
