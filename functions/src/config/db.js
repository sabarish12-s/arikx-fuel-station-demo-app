const {getAuth, initializeFirebaseAdmin} = require('./firebase');
const {runLegacyDataMigration} = require('./env');
const Station = require('../models/Station');
const FuelType = require('../models/FuelType');
const FuelPrice = require('../models/FuelPrice');
const {migrateLegacyDataToSplitCollections} = require('../utils/authStore');

function initializeDatabase() {
  initializeFirebaseAdmin();
  getAuth();
}

async function seedDatabaseDefaults() {
  if (runLegacyDataMigration) {
    const migration = await migrateLegacyDataToSplitCollections();
    if (migration.migrated > 0 || migration.deletedLegacy > 0 || migration.skipped > 0) {
      console.log('Firestore collection migration:', migration);
    }
  }
  await Station.ensureDefault();
  await FuelType.ensureDefaults();
  await FuelPrice.ensureDefaults();
}

async function connectDatabase() {
  initializeDatabase();
  await seedDatabaseDefaults();
}

module.exports = {
  connectDatabase,
  initializeDatabase,
  seedDatabaseDefaults,
};
