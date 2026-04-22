const {
  claimsFor,
  deleteDataRecord,
  getDataRecord,
  listDataRecords,
  upsertDataRecord,
} = require('../utils/authStore');
const {DEFAULT_FUEL_TYPES} = require('../utils/seedData');

const ENTITY_TYPE = 'fuelType';

class FuelType {
  constructor({
    id,
    name,
    shortName,
    description,
    color,
    icon,
    active = true,
    createdAt = null,
  }) {
    this.id = id;
    this.name = name;
    this.shortName = shortName;
    this.description = description;
    this.color = color;
    this.icon = icon;
    this.active = active !== false;
    this.createdAt = createdAt;
  }

  static fromRecord(record) {
    if (!record) {
      return null;
    }
    const claims = claimsFor(record);
    return new FuelType({
      id: claims.id,
      name: claims.name,
      shortName: claims.shortName,
      description: claims.description,
      color: claims.color,
      icon: claims.icon,
      active: claims.active !== false,
      createdAt: record.metadata?.creationTime || null,
    });
  }

  async save() {
    const record = await upsertDataRecord({
      entityType: ENTITY_TYPE,
      entityKey: this.id,
      displayName: this.name,
      payload: {
        id: this.id,
        name: this.name,
        shortName: this.shortName,
        description: this.description,
        color: this.color,
        icon: this.icon,
        active: this.active,
      },
    });
    return FuelType.fromRecord(record);
  }

  toJson() {
    return {
      id: this.id,
      name: this.name,
      shortName: this.shortName,
      description: this.description,
      color: this.color,
      icon: this.icon,
      active: this.active,
      createdAt: this.createdAt,
    };
  }

  static async ensureDefaults() {
    const existing = await FuelType.findAll();
    if (existing.length === 0) {
      for (const item of DEFAULT_FUEL_TYPES) {
        await new FuelType(item).save();
      }
      return FuelType.findAll();
    }
    const existingIds = new Set(existing.map((item) => item.id));
    for (const item of DEFAULT_FUEL_TYPES) {
      if (!existingIds.has(item.id)) {
        await new FuelType(item).save();
      }
    }
    return FuelType.findAll();
  }

  static async findAll() {
    return (await listDataRecords(ENTITY_TYPE))
      .map((record) => FuelType.fromRecord(record))
      .filter(Boolean)
      .sort((a, b) => a.name.localeCompare(b.name));
  }

  static async findById(id) {
    return FuelType.fromRecord(await getDataRecord(ENTITY_TYPE, id));
  }

  static async deleteById(id) {
    return deleteDataRecord(ENTITY_TYPE, id);
  }
}

module.exports = FuelType;
