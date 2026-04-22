const {
  claimsFor,
  getDataRecord,
  upsertDataRecord,
} = require('../utils/authStore');
const {nowIso} = require('../utils/time');

const ENTITY_TYPE = 'inventoryAlertLog';

class InventoryAlertLog {
  constructor({
    id,
    stationId,
    fuelTypeId,
    date,
    sentAt = null,
  }) {
    this.id = id;
    this.stationId = stationId;
    this.fuelTypeId = String(fuelTypeId || '').trim();
    this.date = String(date || '').trim();
    this.sentAt = sentAt || nowIso();
  }

  static idFor(stationId, fuelTypeId, date) {
    return `${stationId}:${fuelTypeId}:${date}`;
  }

  static fromRecord(record) {
    if (!record) {
      return null;
    }
    const claims = claimsFor(record);
    return new InventoryAlertLog({
      id: claims.id || claims.ek || '',
      stationId: claims.sid || '',
      fuelTypeId: claims.ft || '',
      date: claims.dt || '',
      sentAt: claims.sa || '',
    });
  }

  static async exists(stationId, fuelTypeId, date) {
    const id = InventoryAlertLog.idFor(stationId, fuelTypeId, date);
    return !!(await getDataRecord(ENTITY_TYPE, id));
  }

  async save() {
    await upsertDataRecord({
      entityType: ENTITY_TYPE,
      entityKey: this.id,
      displayName: `${this.fuelTypeId} reorder alert ${this.date}`,
      payload: {
        id: this.id,
        sid: this.stationId,
        ft: this.fuelTypeId,
        dt: this.date,
        sa: this.sentAt,
      },
    });
    return this;
  }
}

module.exports = InventoryAlertLog;
