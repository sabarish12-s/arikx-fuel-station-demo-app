const {getMessaging} = require('../config/firebase');

async function sendFcmToTokens(tokens, payload) {
  if (!tokens?.length) {
    return {sent: 0, skipped: true};
  }
  const uniqueTokens = [...new Set(tokens.filter(Boolean))];
  if (!uniqueTokens.length) {
    return {sent: 0, skipped: true};
  }

  let messaging;
  try {
    messaging = getMessaging();
  } catch (error) {
    console.error('Skipping FCM send:', error.message);
    return {sent: 0, skipped: true};
  }

  const response = await messaging.sendEachForMulticast({
    tokens: uniqueTokens,
    notification: payload.notification,
    data: payload.data || {},
  });

  return {
    sent: response.successCount,
    failed: response.failureCount,
  };
}

module.exports = {sendFcmToTokens};
