const {
  claimsFor,
  getDataRecord,
  listDataRecords,
  upsertDataRecord,
} = require('../utils/authStore');
const {getFirestore} = require('../config/firebase');
const {nowIso} = require('../utils/time');

const ENTITY_TYPE = 'creditCustomer';
const COLLECTION_NAME = 'creditCustomers';
const STATION_CACHE_TTL_MS = 15000;
const stationCustomersCache = new Map();

function normalizeCustomerName(name) {
  return String(name || '').trim().replace(/\s+/g, ' ');
}

function normalizeCustomerKey(name) {
  return normalizeCustomerName(name).toLowerCase();
}

function customerId(stationId, normalizedName) {
  return `${stationId}:${normalizedName}`;
}

function sortCustomers(customers = []) {
  return [...customers].sort((a, b) => {
    const left = String(a.lastUsedAt || a.updatedAt || a.createdAt || '');
    const right = String(b.lastUsedAt || b.updatedAt || b.createdAt || '');
    return right.localeCompare(left);
  });
}

function cloneCustomers(customers = []) {
  return customers.map((customer) => new CreditCustomer(customer.toJson()));
}

class CreditCustomer {
  constructor({
    id,
    stationId,
    name,
    normalizedName,
    createdAt = null,
    updatedAt = null,
    lastUsedAt = null,
  }) {
    this.id = id;
    this.stationId = stationId;
    this.name = normalizeCustomerName(name);
    this.normalizedName = normalizeCustomerKey(normalizedName || name);
    this.createdAt = createdAt || null;
    this.updatedAt = updatedAt || null;
    this.lastUsedAt = lastUsedAt || null;
  }

  static fromRecord(record) {
    if (!record) {
      return null;
    }
    const claims = claimsFor(record);
    return new CreditCustomer({
      id: claims.id || claims.ek || '',
      stationId: claims.sid || '',
      name: claims.name || '',
      normalizedName: claims.nn || '',
      createdAt: claims.ca || null,
      updatedAt: claims.ua || null,
      lastUsedAt: claims.lu || null,
    });
  }

  static fromStoredDocument(snapshot) {
    if (!snapshot?.exists) {
      return null;
    }
    const data = snapshot.data() || {};
    return new CreditCustomer({
      id: data.id || data.ek || snapshot.id || '',
      stationId: data.sid || '',
      name: data.name || '',
      normalizedName: data.nn || '',
      createdAt: data.ca || data.createdAt || null,
      updatedAt: data.ua || data.updatedAt || null,
      lastUsedAt: data.lu || null,
    });
  }

  toRecordPayload() {
    return {
      id: this.id,
      sid: this.stationId,
      name: this.name,
      nn: this.normalizedName,
      ca: this.createdAt,
      ua: this.updatedAt,
      lu: this.lastUsedAt,
    };
  }

  async save() {
    const timestamp = nowIso();
    if (!this.createdAt) {
      this.createdAt = timestamp;
    }
    this.updatedAt = timestamp;
    await upsertDataRecord({
      entityType: ENTITY_TYPE,
      entityKey: this.id,
      displayName: `${this.name} Credit Customer`,
      payload: this.toRecordPayload(),
    });
    CreditCustomer.invalidateStationCache(this.stationId);
    return this;
  }

  static async findById(id) {
    return CreditCustomer.fromRecord(await getDataRecord(ENTITY_TYPE, id));
  }

  static async allForStation(stationId) {
    if (!stationId) {
      return [];
    }

    const cached = stationCustomersCache.get(stationId);
    if (cached && cached.expiresAt > Date.now()) {
      return cloneCustomers(cached.customers);
    }

    try {
      const snapshot = await getFirestore()
        .collection(COLLECTION_NAME)
        .where('sid', '==', stationId)
        .get();
      const directCustomers = sortCustomers(
        snapshot.docs
          .map((doc) => CreditCustomer.fromStoredDocument(doc))
          .filter(Boolean),
      );
      stationCustomersCache.set(stationId, {
        expiresAt: Date.now() + STATION_CACHE_TTL_MS,
        customers: cloneCustomers(directCustomers),
      });
      return cloneCustomers(directCustomers);
    } catch (error) {
      console.warn('CreditCustomer station query fallback:', error.message);
    }

    const fallbackCustomers = sortCustomers((await listDataRecords(ENTITY_TYPE))
      .map((record) => CreditCustomer.fromRecord(record))
      .filter(Boolean)
      .filter((customer) => customer.stationId === stationId));
    stationCustomersCache.set(stationId, {
      expiresAt: Date.now() + STATION_CACHE_TTL_MS,
      customers: cloneCustomers(fallbackCustomers),
    });
    return cloneCustomers(fallbackCustomers);
  }

  static invalidateStationCache(stationId) {
    if (!stationId) {
      return;
    }
    stationCustomersCache.delete(stationId);
  }

  static async findByName(stationId, name) {
    const normalizedName = normalizeCustomerKey(name);
    if (!stationId || !normalizedName) {
      return null;
    }
    return CreditCustomer.findById(customerId(stationId, normalizedName));
  }

  static async findOrCreate({stationId, name, usedAt}) {
    const normalizedName = normalizeCustomerKey(name);
    const normalizedLabel = normalizeCustomerName(name);
    if (!stationId || !normalizedName || !normalizedLabel) {
      return null;
    }

    const id = customerId(stationId, normalizedName);
    const existing = await CreditCustomer.findById(id);
    if (existing) {
      let changed = false;
      if (existing.name !== normalizedLabel) {
        existing.name = normalizedLabel;
        changed = true;
      }
      const usageTimestamp = usedAt || nowIso();
      if (
        !existing.lastUsedAt ||
        String(existing.lastUsedAt).localeCompare(String(usageTimestamp)) < 0
      ) {
        existing.lastUsedAt = usageTimestamp;
        changed = true;
      }
      if (changed) {
        await existing.save();
      }
      return existing;
    }

    const customer = new CreditCustomer({
      id,
      stationId,
      name: normalizedLabel,
      normalizedName,
      createdAt: usedAt || nowIso(),
      updatedAt: usedAt || nowIso(),
      lastUsedAt: usedAt || nowIso(),
    });
    await customer.save();
    return customer;
  }

  static async resolveReference({stationId, customerId: requestedId, name, usedAt}) {
    const normalizedName = normalizeCustomerName(name);
    if (requestedId) {
      const existing = await CreditCustomer.findById(String(requestedId));
      if (existing && existing.stationId === stationId) {
        if (
          normalizedName &&
          normalizedName !== existing.name
        ) {
          existing.name = normalizedName;
        }
        const usageTimestamp = usedAt || nowIso();
        if (
          !existing.lastUsedAt ||
          String(existing.lastUsedAt).localeCompare(String(usageTimestamp)) < 0
        ) {
          existing.lastUsedAt = usageTimestamp;
        }
        await existing.save();
        return {
          customerId: existing.id,
          name: existing.name,
        };
      }
    }

    const customer = await CreditCustomer.findOrCreate({
      stationId,
      name: normalizedName,
      usedAt,
    });
    if (!customer) {
      return null;
    }
    return {
      customerId: customer.id,
      name: customer.name,
    };
  }

  toJson() {
    return {
      id: this.id,
      stationId: this.stationId,
      name: this.name,
      normalizedName: this.normalizedName,
      createdAt: this.createdAt || '',
      updatedAt: this.updatedAt || '',
      lastUsedAt: this.lastUsedAt || '',
    };
  }
}

module.exports = CreditCustomer;
