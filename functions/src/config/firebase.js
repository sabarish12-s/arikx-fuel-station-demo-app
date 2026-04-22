const admin = require('firebase-admin');
const {firebaseServiceAccountJson} = require('./env');

let firebaseApp;

function initializeFirebaseAdmin() {
  if (firebaseApp) {
    return firebaseApp;
  }

  if (admin.apps.length) {
    firebaseApp = admin.app();
    return firebaseApp;
  }

  if (!firebaseServiceAccountJson) {
    firebaseApp = admin.initializeApp();
    return firebaseApp;
  }

  let serviceAccount;
  try {
    serviceAccount = JSON.parse(firebaseServiceAccountJson);
  } catch (error) {
    throw new Error(`FIREBASE_SERVICE_ACCOUNT_JSON is invalid JSON: ${error.message}`);
  }

  firebaseApp = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  return firebaseApp;
}

function getFirestore() {
  initializeFirebaseAdmin();
  return admin.firestore();
}

function getAuth() {
  initializeFirebaseAdmin();
  return admin.auth();
}

function getMessaging() {
  initializeFirebaseAdmin();
  return admin.messaging();
}

module.exports = {
  admin,
  getAuth,
  getFirestore,
  getMessaging,
  initializeFirebaseAdmin,
};
