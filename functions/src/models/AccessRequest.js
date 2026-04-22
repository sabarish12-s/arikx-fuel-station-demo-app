const User = require('./User');
const {toDate} = require('../utils/time');

function matchesFilters(record, filters = {}) {
  return Object.entries(filters).every(([field, expected]) => record[field] === expected);
}

class AccessRequest {
  constructor({
    id,
    userId,
    email,
    name,
    stationId = 'station-hq-01',
    roleRequested = 'sales',
    status = 'pending',
    createdAt = new Date(),
    reviewedAt = null,
    reviewedBy = null,
    rejectionReason = null,
  }) {
    this._id = id;
    this.userId = userId;
    this.email = (email || '').trim().toLowerCase();
    this.name = name;
    this.stationId = stationId || 'station-hq-01';
    this.roleRequested = roleRequested || 'sales';
    this.status = status || 'pending';
    this.createdAt = toDate(createdAt) || new Date();
    this.reviewedAt = toDate(reviewedAt);
    this.reviewedBy = reviewedBy || null;
    this.rejectionReason = rejectionReason || null;
  }

  static fromUser(user) {
    if (!user) {
      return null;
    }
    return new AccessRequest({
      id: user._id,
      userId: user._id,
      email: user.email,
      name: user.name,
      stationId: user.stationId,
      roleRequested: user.requestedRole || user.role || 'sales',
      status: user.status,
      createdAt: user.requestCreatedAt || user.createdAt,
      reviewedAt: user.reviewedAt,
      reviewedBy: user.reviewedBy,
      rejectionReason: user.rejectionReason,
    });
  }

  async save() {
    const user = await User.findById(this.userId || this._id);
    if (!user) {
      throw new Error('User not found');
    }
    user.stationId = this.stationId || user.stationId;
    user.requestedRole = this.roleRequested;
    user.status = this.status;
    user.requestCreatedAt = this.createdAt;
    user.reviewedAt = this.reviewedAt;
    user.reviewedBy = this.reviewedBy;
    user.rejectionReason = this.rejectionReason;
    await user.save();
    return this;
  }

  static async create(data) {
    const request = new AccessRequest({
      id: data.userId,
      ...data,
    });
    await request.save();
    return request;
  }

  static async findById(id) {
    return AccessRequest.fromUser(await User.findById(id));
  }

  static async findOne(filters = {}) {
    const requests = await AccessRequest.find(filters, {limit: 1});
    return requests[0] || null;
  }

  static async find(filters = {}, options = {}) {
    const requests = (await User.find())
      .map((user) => AccessRequest.fromUser(user))
      .filter(Boolean)
      .filter((request) => matchesFilters(request, filters));

    if (typeof options.limit === 'number') {
      return requests.slice(0, options.limit);
    }

    return requests;
  }
}

module.exports = AccessRequest;
