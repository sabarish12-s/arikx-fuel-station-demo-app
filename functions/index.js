const {onRequest} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {defineString} = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const app = require('./src/app');
const {initializeDatabase, seedDatabaseDefaults} = require('./src/config/db');

const backendReorderAlertUrl = defineString('BACKEND_REORDER_ALERT_URL');
const inventoryAlertRunToken = defineString('INVENTORY_ALERT_RUN_TOKEN');

let apiInitialized = false;
let seedPromise = null;

function initializeApi() {
  if (!apiInitialized) {
    initializeDatabase();
    apiInitialized = true;
  }
  if (!seedPromise) {
    seedPromise = seedDatabaseDefaults()
      .then(() => {
        logger.info('Firestore defaults are ready.');
      })
      .catch((error) => {
        logger.error('Firestore default seed failed.', {
          message: error.message,
          code: error.code,
        });
      });
  }
}

exports.api = onRequest(
  {
    region: 'asia-south1',
    minInstances: 0,
    maxInstances: 3,
    memory: '512MiB',
    timeoutSeconds: 60,
    invoker: 'public',
  },
  (req, res) => {
    initializeApi();
    return app(req, res);
  },
);

function normalizeBaseUrl(value) {
  return String(value || '').trim().replace(/\/+$/, '');
}

exports.runInventoryReorderAlerts = onSchedule(
  {
    schedule: '0 7 * * *',
    timeZone: 'Asia/Kolkata',
    region: 'asia-south1',
  },
  async () => {
    const baseUrl = normalizeBaseUrl(backendReorderAlertUrl.value());
    const runToken = String(inventoryAlertRunToken.value() || '').trim();

    if (!baseUrl) {
      logger.error('BACKEND_REORDER_ALERT_URL is not configured.');
      return;
    }
    if (!runToken) {
      logger.error('INVENTORY_ALERT_RUN_TOKEN is not configured.');
      return;
    }

    const response = await fetch(`${baseUrl}/inventory/reorder-alerts/run`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-inventory-alert-token': runToken,
      },
    });

    const body = await response.text();
    if (!response.ok) {
      logger.error('Inventory reorder alert run failed.', {
        status: response.status,
        body,
      });
      throw new Error(`Inventory reorder alert run failed with ${response.status}.`);
    }

    logger.info('Inventory reorder alerts completed.', {body});
  },
);
