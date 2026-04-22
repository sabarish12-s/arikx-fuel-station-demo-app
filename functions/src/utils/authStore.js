const {getAuth, getFirestore} = require('../config/firebase');

const DATA_EMAIL_PREFIX = 'rk-data';
const CLAIMS_TYPE_STAFF = 'staff';
const CLAIMS_TYPE_DATA = 'data';
const LEGACY_DATA_COLLECTION = 'appDataRecords';

const ENTITY_COLLECTIONS = Object.freeze({
  station: 'stations',
  fuelType: 'fuelTypes',
  fuelPrice: 'fuelPrices',
  fuelPriceUpdateRequest: 'fuelPriceUpdateRequests',
  shiftEntry: 'shiftEntries',
  creditCustomer: 'creditCustomers',
  creditTransaction: 'creditTransactions',
  dailySalesSummary: 'dailySalesSummaries',
  deliveryReceipt: 'deliveryReceipts',
  inventoryAlertLog: 'inventoryAlertLogs',
  inventoryLedgerEntry: 'inventoryLedgerEntries',
  inventoryStockSnapshot: 'inventoryStockSnapshots',
  pumpOpeningReadingLog: 'pumpOpeningReadingLogs',
  stationDaySetup: 'stationDaySetups',
  dailyFuelRecord: 'dailyFuelRecords',
});

const META_FIELDS = new Set(['displayName', 'disabled', 'createdAt', 'updatedAt', 'et', 'ek']);

function claimsFor(record) {
  return record?.customClaims || {};
}

function isDataRecord(record) {
  return !!record?.email?.startsWith(`${DATA_EMAIL_PREFIX}+`);
}

function isStaffRecord(record) {
  return !!record?.email && !isDataRecord(record);
}

function getEntityCollectionName(entityType) {
  const collectionName = ENTITY_COLLECTIONS[String(entityType || '').trim()];
  if (!collectionName) {
    throw new Error(`Unsupported data entity type: ${entityType}`);
  }
  return collectionName;
}

function normalizeEntityKey(entityKey) {
  const raw = String(entityKey || '').trim();
  if (!raw) {
    throw new Error('Entity key is required.');
  }
  return raw.includes('/') ? Buffer.from(raw, 'utf8').toString('base64url') : raw;
}

function getEntityCollection(entityType) {
  return getFirestore().collection(getEntityCollectionName(entityType));
}

function getLegacyDataCollection() {
  return getFirestore().collection(LEGACY_DATA_COLLECTION);
}

function stripMetaFields(data = {}) {
  return Object.entries(data || {}).reduce((result, [key, value]) => {
    if (!META_FIELDS.has(key)) {
      result[key] = value;
    }
    return result;
  }, {});
}

function toDataRecordAdapter(entityType, entityKey, data = {}) {
  const payload = data?.payload && typeof data.payload === 'object'
    ? data.payload
    : stripMetaFields(data);
  return {
    uid: entityKey || '',
    email: data.email || null,
    displayName: data.displayName || '',
    disabled: data.disabled !== false,
    customClaims: {
      rt: CLAIMS_TYPE_DATA,
      et: entityType || data.et || '',
      ek: entityKey || data.ek || '',
      ...(payload || {}),
    },
    metadata: {
      creationTime: data.createdAt || null,
      lastRefreshTime: data.updatedAt || null,
    },
  };
}

function toStoredDocument({displayName, disabled = true, payload, createdAt = null}) {
  const now = new Date().toISOString();
  return {
    ...(payload || {}),
    displayName: displayName || '',
    disabled,
    createdAt: createdAt || now,
    updatedAt: now,
  };
}

async function getUserByEmailSafe(email) {
  try {
    return await getAuth().getUserByEmail(email);
  } catch (error) {
    if (error?.code === 'auth/user-not-found') {
      return null;
    }
    throw error;
  }
}

async function getLegacyDataSnapshot(entityType, entityKey) {
  const snapshot = await getLegacyDataCollection()
    .where('et', '==', entityType)
    .where('ek', '==', entityKey)
    .limit(1)
    .get();
  return snapshot.docs[0] || null;
}

async function upsertDataRecord({
  entityType,
  entityKey,
  displayName,
  disabled = true,
  payload,
}) {
  const docId = normalizeEntityKey(entityKey);
  const docRef = getEntityCollection(entityType).doc(docId);
  const existing = await docRef.get();
  const nextData = toStoredDocument({
    displayName: displayName || `${entityType}:${entityKey}`,
    disabled,
    payload,
    createdAt: existing.exists ? (existing.data()?.createdAt || null) : null,
  });
  await docRef.set(nextData, {merge: true});
  return toDataRecordAdapter(entityType, entityKey, nextData);
}

async function getDataRecord(entityType, entityKey) {
  const docId = normalizeEntityKey(entityKey);
  const snapshot = await getEntityCollection(entityType).doc(docId).get();
  if (snapshot.exists) {
    return toDataRecordAdapter(entityType, entityKey, snapshot.data());
  }

  const legacyDoc = await getLegacyDataSnapshot(entityType, entityKey);
  if (!legacyDoc) {
    return null;
  }
  return toDataRecordAdapter(entityType, entityKey, legacyDoc.data());
}

async function deleteDataRecord(entityType, entityKey) {
  const docId = normalizeEntityKey(entityKey);
  const collectionRef = getEntityCollection(entityType);
  const docRef = collectionRef.doc(docId);
  const snapshot = await docRef.get();
  let deleted = false;

  if (snapshot.exists) {
    await docRef.delete();
    deleted = true;
  }

  const legacyDoc = await getLegacyDataSnapshot(entityType, entityKey);
  if (legacyDoc) {
    await legacyDoc.ref.delete();
    deleted = true;
  }

  return deleted;
}

async function listAllAuthUsers() {
  const auth = getAuth();
  const records = [];
  let nextPageToken;

  do {
    const page = await auth.listUsers(1000, nextPageToken);
    records.push(...page.users);
    nextPageToken = page.pageToken;
  } while (nextPageToken);

  return records;
}

async function listDataRecords(entityType) {
  const collectionSnapshot = await getEntityCollection(entityType).get();
  const merged = new Map(
    collectionSnapshot.docs.map((doc) => {
      const entityKey = String(doc.data()?.ek || doc.id || '').trim() || doc.id;
      return [entityKey, toDataRecordAdapter(entityType, entityKey, doc.data())];
    }),
  );

  const legacySnapshot = await getLegacyDataCollection().where('et', '==', entityType).get();
  legacySnapshot.forEach((doc) => {
    const data = doc.data() || {};
    const entityKey = String(data.ek || '').trim();
    if (!entityKey || merged.has(entityKey)) {
      return;
    }
    merged.set(entityKey, toDataRecordAdapter(entityType, entityKey, data));
  });

  return [...merged.values()];
}

async function migrateLegacyDataToSplitCollections() {
  const legacySnapshot = await getLegacyDataCollection().get();
  if (legacySnapshot.empty) {
    return {migrated: 0, deletedLegacy: 0, skipped: 0};
  }

  let migrated = 0;
  let deletedLegacy = 0;
  let skipped = 0;

  for (const doc of legacySnapshot.docs) {
    const data = doc.data() || {};
    const entityType = String(data.et || '').trim();
    const entityKey = String(data.ek || '').trim();
    if (!entityType || !entityKey || !ENTITY_COLLECTIONS[entityType]) {
      skipped += 1;
      continue;
    }

    const targetRef = getEntityCollection(entityType).doc(normalizeEntityKey(entityKey));
    const targetSnapshot = await targetRef.get();
    if (!targetSnapshot.exists) {
      const payload = data?.payload && typeof data.payload === 'object'
        ? data.payload
        : stripMetaFields(data);
      await targetRef.set({
        ...(payload || {}),
        displayName: data.displayName || `${entityType}:${entityKey}`,
        disabled: data.disabled !== false,
        createdAt: data.createdAt || new Date().toISOString(),
        updatedAt: data.updatedAt || data.createdAt || new Date().toISOString(),
      }, {merge: true});
      migrated += 1;
    }

    await doc.ref.delete();
    deletedLegacy += 1;
  }

  return {migrated, deletedLegacy, skipped};
}

module.exports = {
  CLAIMS_TYPE_DATA,
  CLAIMS_TYPE_STAFF,
  ENTITY_COLLECTIONS,
  claimsFor,
  deleteDataRecord,
  getDataRecord,
  getUserByEmailSafe,
  isDataRecord,
  isStaffRecord,
  listAllAuthUsers,
  listDataRecords,
  migrateLegacyDataToSplitCollections,
  upsertDataRecord,
};
