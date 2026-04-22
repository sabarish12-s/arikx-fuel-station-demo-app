const {
  claimsFor,
  deleteDataRecord,
  getDataRecord,
  listDataRecords,
  upsertDataRecord,
} = require('../utils/authStore');
const {getFirestore} = require('../config/firebase');
const {nowIso} = require('../utils/time');
const CreditCustomer = require('./CreditCustomer');

const ENTITY_TYPE = 'creditTransaction';
const COLLECTION_NAME = 'creditTransactions';
const BACKFILL_COLLECTION_NAME = 'creditBackfillStatus';
const STATION_CACHE_TTL_MS = 15000;
const stationBackfillPromises = new Map();
const backfilledStations = new Set();
const stationTransactionsCache = new Map();
const customerTransactionsCache = new Map();

function roundNumber(value) {
  return Math.round((Number(value || 0) + Number.EPSILON) * 100) / 100;
}

function normalizePaymentMode(value) {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'cash' || normalized === 'check' || normalized === 'upi') {
    return normalized;
  }
  return null;
}

function normalizeTransactionType(value) {
  return String(value || '').trim().toLowerCase() === 'collection'
    ? 'collection'
    : 'issue';
}

function normalizeNote(value) {
  return String(value || '').trim();
}

function sortTransactions(transactions = []) {
  return [...transactions].sort((a, b) => {
    const dateCompare = String(a.date).localeCompare(String(b.date));
    if (dateCompare !== 0) {
      return dateCompare;
    }
    return String(a.createdAt || '').localeCompare(String(b.createdAt || ''));
  });
}

function stationRangeCacheKey(stationId, fromDate = '', toDate = '') {
  return `${stationId}:${fromDate || ''}:${toDate || ''}`;
}

function customerCacheKey(stationId, customerId) {
  return `${stationId || '*'}:${customerId || ''}`;
}

function cloneTransactions(transactions = []) {
  return transactions.map((transaction) => new CreditTransaction(transaction.toJson()));
}

function expectedTransactionCountForEntry(entry) {
  const creditCount = (entry?.creditEntries || []).filter(
    (item) =>
      (String(item?.customerId || '').trim() || String(item?.name || '').trim()) &&
      Number(item?.amount || 0) > 0,
  ).length;
  const collectionCount = (entry?.creditCollections || []).filter(
    (item) =>
      (String(item?.customerId || '').trim() || String(item?.name || '').trim()) &&
      Number(item?.amount || 0) > 0,
  ).length;
  return creditCount + collectionCount;
}

class CreditTransaction {
  constructor({
    id,
    stationId,
    customerId,
    customerNameSnapshot,
    type,
    amount,
    date,
    paymentMode = null,
    entryId = null,
    createdBy = '',
    createdAt = null,
    note = '',
  }) {
    this.id = id;
    this.stationId = stationId;
    this.customerId = customerId;
    this.customerNameSnapshot = String(customerNameSnapshot || '').trim();
    this.type = normalizeTransactionType(type);
    this.amount = roundNumber(amount);
    this.date = String(date || '').trim();
    this.paymentMode = normalizePaymentMode(paymentMode);
    this.entryId = entryId || null;
    this.createdBy = String(createdBy || '').trim();
    this.createdAt = createdAt || null;
    this.note = normalizeNote(note);
  }

  static fromRecord(record) {
    if (!record) {
      return null;
    }
    const claims = claimsFor(record);
    return new CreditTransaction({
      id: claims.id || claims.ek || '',
      stationId: claims.sid || '',
      customerId: claims.cid || '',
      customerNameSnapshot: claims.cn || '',
      type: claims.tp || 'issue',
      amount: claims.amt || 0,
      date: claims.dt || '',
      paymentMode: claims.pm || null,
      entryId: claims.eid || null,
      createdBy: claims.cb || '',
      createdAt: claims.ca || null,
      note: claims.nt || '',
    });
  }

  static fromStoredDocument(snapshot) {
    if (!snapshot?.exists) {
      return null;
    }
    const data = snapshot.data() || {};
    return new CreditTransaction({
      id: data.id || data.ek || snapshot.id || '',
      stationId: data.sid || '',
      customerId: data.cid || '',
      customerNameSnapshot: data.cn || '',
      type: data.tp || 'issue',
      amount: data.amt || 0,
      date: data.dt || '',
      paymentMode: data.pm || null,
      entryId: data.eid || null,
      createdBy: data.cb || '',
      createdAt: data.ca || data.createdAt || null,
      note: data.nt || '',
    });
  }

  toRecordPayload() {
    return {
      id: this.id,
      sid: this.stationId,
      cid: this.customerId,
      cn: this.customerNameSnapshot,
      tp: this.type,
      amt: this.amount,
      dt: this.date,
      pm: this.paymentMode,
      eid: this.entryId,
      cb: this.createdBy,
      ca: this.createdAt,
      nt: this.note,
    };
  }

  async save() {
    if (!this.createdAt) {
      this.createdAt = nowIso();
    }
    await upsertDataRecord({
      entityType: ENTITY_TYPE,
      entityKey: this.id,
      displayName: `${this.customerNameSnapshot} ${this.type}`,
      payload: this.toRecordPayload(),
    });
    CreditTransaction.invalidateStationCache(this.stationId);
    CreditTransaction.invalidateCustomerCache(this.stationId, this.customerId);
    return this;
  }

  static async findById(id) {
    return CreditTransaction.fromRecord(await getDataRecord(ENTITY_TYPE, id));
  }

  static async allForStation(stationId) {
    if (!stationId) {
      return [];
    }

    const cacheKey = stationRangeCacheKey(stationId);
    const cached = stationTransactionsCache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
      return cloneTransactions(cached.transactions);
    }

    try {
      const snapshot = await getFirestore()
        .collection(COLLECTION_NAME)
        .where('sid', '==', stationId)
        .get();
      const directTransactions = sortTransactions(
        snapshot.docs
          .map((doc) => CreditTransaction.fromStoredDocument(doc))
          .filter(Boolean),
      );
      stationTransactionsCache.set(cacheKey, {
        expiresAt: Date.now() + STATION_CACHE_TTL_MS,
        transactions: cloneTransactions(directTransactions),
      });
      return cloneTransactions(directTransactions);
    } catch (error) {
      console.warn('CreditTransaction station query fallback:', error.message);
    }

    const fallbackTransactions = sortTransactions((await listDataRecords(ENTITY_TYPE))
      .map((record) => CreditTransaction.fromRecord(record))
      .filter(Boolean)
      .filter((transaction) => transaction.stationId === stationId));
    stationTransactionsCache.set(cacheKey, {
      expiresAt: Date.now() + STATION_CACHE_TTL_MS,
      transactions: cloneTransactions(fallbackTransactions),
    });
    return cloneTransactions(fallbackTransactions);
  }

  static async allForStationRange(stationId, {fromDate = '', toDate = ''} = {}) {
    if (!stationId) {
      return [];
    }

    const normalizedFromDate = String(fromDate || '').trim();
    const normalizedToDate = String(toDate || '').trim();
    const cacheKey = stationRangeCacheKey(stationId, normalizedFromDate, normalizedToDate);
    const cached = stationTransactionsCache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
      return cloneTransactions(cached.transactions);
    }

    try {
      let query = getFirestore().collection(COLLECTION_NAME).where('sid', '==', stationId);
      if (normalizedFromDate) {
        query = query.where('dt', '>=', normalizedFromDate);
      }
      if (normalizedToDate) {
        query = query.where('dt', '<=', normalizedToDate);
      }
      const snapshot = await query.get();
      const directTransactions = sortTransactions(
        snapshot.docs
          .map((doc) => CreditTransaction.fromStoredDocument(doc))
          .filter(Boolean)
          .filter((transaction) => {
            if (normalizedFromDate && String(transaction.date || '') < normalizedFromDate) {
              return false;
            }
            if (normalizedToDate && String(transaction.date || '') > normalizedToDate) {
              return false;
            }
            return true;
          }),
      );
      stationTransactionsCache.set(cacheKey, {
        expiresAt: Date.now() + STATION_CACHE_TTL_MS,
        transactions: cloneTransactions(directTransactions),
      });
      return cloneTransactions(directTransactions);
    } catch (error) {
      console.warn('CreditTransaction range query fallback:', error.message);
    }

    const fallbackTransactions = sortTransactions((await listDataRecords(ENTITY_TYPE))
      .map((record) => CreditTransaction.fromRecord(record))
      .filter(Boolean)
      .filter((transaction) => {
        if (transaction.stationId !== stationId) {
          return false;
        }
        if (normalizedFromDate && String(transaction.date || '') < normalizedFromDate) {
          return false;
        }
        if (normalizedToDate && String(transaction.date || '') > normalizedToDate) {
          return false;
        }
        return true;
      }));
    stationTransactionsCache.set(cacheKey, {
      expiresAt: Date.now() + STATION_CACHE_TTL_MS,
      transactions: cloneTransactions(fallbackTransactions),
    });
    return cloneTransactions(fallbackTransactions);
  }

  static async allForCustomer(stationId, customerId) {
    if (!customerId) {
      return [];
    }

    const cacheKey = customerCacheKey(stationId, customerId);
    const cached = customerTransactionsCache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
      return cloneTransactions(cached.transactions);
    }

    try {
      const snapshot = await getFirestore()
        .collection(COLLECTION_NAME)
        .where('cid', '==', customerId)
        .get();
      const directTransactions = sortTransactions(
        snapshot.docs
          .map((doc) => CreditTransaction.fromStoredDocument(doc))
          .filter(Boolean)
          .filter((transaction) => !stationId || transaction.stationId === stationId),
      );
      customerTransactionsCache.set(cacheKey, {
        expiresAt: Date.now() + STATION_CACHE_TTL_MS,
        transactions: cloneTransactions(directTransactions),
      });
      return cloneTransactions(directTransactions);
    } catch (error) {
      console.warn('CreditTransaction customer query fallback:', error.message);
    }

    const fallbackTransactions = sortTransactions((await listDataRecords(ENTITY_TYPE))
      .map((record) => CreditTransaction.fromRecord(record))
      .filter(Boolean)
      .filter((transaction) => {
        if (transaction.customerId !== customerId) {
          return false;
        }
        if (stationId && transaction.stationId !== stationId) {
          return false;
        }
        return true;
      }));
    customerTransactionsCache.set(cacheKey, {
      expiresAt: Date.now() + STATION_CACHE_TTL_MS,
      transactions: cloneTransactions(fallbackTransactions),
    });
    return cloneTransactions(fallbackTransactions);
  }

  static async deleteByEntryId(entryId) {
    const deletedTransactions = [];

    try {
      const snapshot = await getFirestore()
        .collection(COLLECTION_NAME)
        .where('eid', '==', entryId)
        .get();

      if (!snapshot.empty) {
        const directTransactions = snapshot.docs
          .map((doc) => CreditTransaction.fromStoredDocument(doc))
          .filter(Boolean);
        deletedTransactions.push(...directTransactions);
        await Promise.all(snapshot.docs.map((doc) => doc.ref.delete()));
      }
    } catch (error) {
      console.warn('CreditTransaction delete-by-entry fallback:', error.message);
    }

    const transactions = (await listDataRecords(ENTITY_TYPE))
      .map((record) => CreditTransaction.fromRecord(record))
      .filter(Boolean)
      .filter((transaction) => transaction.entryId === entryId);
    deletedTransactions.push(...transactions);
    await Promise.all(
      transactions.map((transaction) => deleteDataRecord(ENTITY_TYPE, transaction.id)),
    );

    for (const transaction of deletedTransactions) {
      CreditTransaction.invalidateStationCache(transaction.stationId);
      CreditTransaction.invalidateCustomerCache(transaction.stationId, transaction.customerId);
    }
  }

  static async syncForEntry(entry, {createdBy} = {}) {
    if (!entry?.id || !entry.stationId) {
      return [];
    }

    await CreditTransaction.deleteByEntryId(entry.id);

    const synced = [];
    const issuedAt = entry.updatedAt || entry.submittedAt || nowIso();
    for (let index = 0; index < (entry.creditEntries || []).length; index += 1) {
      const item = entry.creditEntries[index];
      const resolved = await CreditCustomer.resolveReference({
        stationId: entry.stationId,
        customerId: item.customerId,
        name: item.name,
        usedAt: issuedAt,
      });
      if (!resolved || Number(item.amount || 0) <= 0) {
        continue;
      }
      const transaction = new CreditTransaction({
        id: `${entry.id}:issue:${index}`,
        stationId: entry.stationId,
        customerId: resolved.customerId,
        customerNameSnapshot: resolved.name,
        type: 'issue',
        amount: item.amount,
        date: entry.date,
        paymentMode: null,
        entryId: entry.id,
        createdBy: createdBy || entry.submittedBy,
        createdAt: issuedAt,
      });
      await transaction.save();
      entry.creditEntries[index] = {
        ...item,
        customerId: resolved.customerId,
        name: resolved.name,
      };
      synced.push(transaction);
    }

    for (let index = 0; index < (entry.creditCollections || []).length; index += 1) {
      const item = entry.creditCollections[index];
      const resolved = await CreditCustomer.resolveReference({
        stationId: entry.stationId,
        customerId: item.customerId,
        name: item.name,
        usedAt: issuedAt,
      });
      if (!resolved || Number(item.amount || 0) <= 0) {
        continue;
      }
      const transaction = new CreditTransaction({
        id: `${entry.id}:collection:${index}`,
        stationId: entry.stationId,
        customerId: resolved.customerId,
        customerNameSnapshot: resolved.name,
        type: 'collection',
        amount: item.amount,
        date: item.date || entry.date,
        paymentMode: item.paymentMode,
        entryId: entry.id,
        createdBy: createdBy || entry.submittedBy,
        createdAt: issuedAt,
        note: item.note,
      });
      await transaction.save();
      entry.creditCollections[index] = {
        ...item,
        customerId: resolved.customerId,
        name: resolved.name,
      };
      synced.push(transaction);
    }

    if (synced.length > 0) {
      await entry.save();
    }

    return synced;
  }

  static async backfillForStation(stationId) {
    const ShiftEntry = require('./ShiftEntry');
    const [entries, existingTransactions] = await Promise.all([
      ShiftEntry.findRaw({stationId}),
      CreditTransaction.allForStation(stationId),
    ]);
    const existingCountByEntryId = new Map();
    for (const transaction of existingTransactions) {
      if (!transaction.entryId) {
        continue;
      }
      existingCountByEntryId.set(
        transaction.entryId,
        Number(existingCountByEntryId.get(transaction.entryId) || 0) + 1,
      );
    }
    for (const entry of entries) {
      const expectedCount = expectedTransactionCountForEntry(entry);
      if (expectedCount <= 0) {
        continue;
      }
      if ((existingCountByEntryId.get(entry.id) || 0) === expectedCount) {
        continue;
      }
      await CreditTransaction.syncForEntry(entry, {createdBy: entry.submittedBy});
    }
  }

  static async ensureBackfilledForStation(stationId) {
    if (!stationId || backfilledStations.has(stationId)) {
      return;
    }
    const ShiftEntry = require('./ShiftEntry');
    const backfillRef = getFirestore().collection(BACKFILL_COLLECTION_NAME).doc(stationId);
    const backfillSnapshot = await backfillRef.get();
    if (backfillSnapshot.exists) {
      const latestEntry = await ShiftEntry.latestRawForStation(stationId);
      const lastBackfilledEntryId = String(backfillSnapshot.data()?.latestEntryId || '');
      const latestEntryId = String(latestEntry?.id || '');
      if (lastBackfilledEntryId === latestEntryId) {
        backfilledStations.add(stationId);
        return;
      }
    }
    const existingPromise = stationBackfillPromises.get(stationId);
    if (existingPromise) {
      await existingPromise;
      return;
    }

    const nextPromise = (async () => {
      await CreditTransaction.backfillForStation(stationId);
      const latestEntry = await ShiftEntry.latestRawForStation(stationId);
      await backfillRef.set({
        stationId,
        completedAt: nowIso(),
        latestEntryId: latestEntry?.id || '',
      }, {merge: true});
      backfilledStations.add(stationId);
      CreditTransaction.invalidateStationCache(stationId);
    })();
    stationBackfillPromises.set(stationId, nextPromise);

    try {
      await nextPromise;
    } finally {
      stationBackfillPromises.delete(stationId);
    }
  }

  static invalidateStationCache(stationId) {
    if (!stationId) {
      return;
    }
    for (const key of stationTransactionsCache.keys()) {
      if (key.startsWith(`${stationId}:`)) {
        stationTransactionsCache.delete(key);
      }
    }
  }

  static invalidateCustomerCache(stationId, customerId) {
    if (!customerId) {
      return;
    }
    customerTransactionsCache.delete(customerCacheKey(stationId, customerId));
    customerTransactionsCache.delete(customerCacheKey('', customerId));
  }

  static async recordStandaloneCollection({
    stationId,
    customerId,
    name,
    amount,
    date,
    paymentMode,
    createdBy,
    note,
  }) {
    const resolved = await CreditCustomer.resolveReference({
      stationId,
      customerId,
      name,
      usedAt: nowIso(),
    });
    if (!resolved) {
      throw new Error('Credit customer name is required.');
    }
    const transaction = new CreditTransaction({
      id: `${stationId}:standalone:${resolved.customerId}:${date}:${Date.now()}`,
      stationId,
      customerId: resolved.customerId,
      customerNameSnapshot: resolved.name,
      type: 'collection',
      amount,
      date,
      paymentMode,
      entryId: null,
      createdBy,
      createdAt: nowIso(),
      note,
    });
    if (transaction.amount <= 0) {
      throw new Error('Collection amount must be greater than zero.');
    }
    if (!transaction.date) {
      throw new Error('Collection date is required.');
    }
    if (!transaction.paymentMode) {
      throw new Error('Collection payment mode is required.');
    }
    await CreditTransaction.ensureBackfilledForStation(stationId);
    const existingTransactions = await CreditTransaction.allForCustomer(
      stationId,
      resolved.customerId,
    );
    const borrowedBalance = roundNumber(
      existingTransactions.reduce((balance, item) => {
        const itemAmount = Number(item.amount || 0);
        return item.type === 'issue'
          ? balance + itemAmount
          : balance - itemAmount;
      }, 0),
    );
    if (transaction.amount > borrowedBalance) {
      throw new Error(
        'Collection amount cannot be more than borrowed balance.',
      );
    }
    await transaction.save();
    return transaction;
  }

  toJson() {
    return {
      id: this.id,
      stationId: this.stationId,
      customerId: this.customerId,
      customerNameSnapshot: this.customerNameSnapshot,
      type: this.type,
      amount: this.amount,
      date: this.date,
      paymentMode: this.paymentMode,
      entryId: this.entryId,
      createdBy: this.createdBy,
      createdAt: this.createdAt || '',
      note: this.note,
    };
  }
}

module.exports = CreditTransaction;
