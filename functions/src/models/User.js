const {getAuth} = require('../config/firebase');
const {
  CLAIMS_TYPE_STAFF,
  claimsFor,
  getUserByEmailSafe,
  isStaffRecord,
  listAllAuthUsers,
} = require('../utils/authStore');
const {nowIso, toDate} = require('../utils/time');
const USER_CACHE_TTL_MS = 15000;
let cachedUsers = null;
let cachedUsersExpiresAt = 0;

function normalizeFcmTokens(tokens = []) {
  return [...new Set((tokens || []).filter(Boolean).map((token) => String(token).trim()).filter(Boolean))].slice(-1);
}

function matchesFilters(record, filters = {}) {
  return Object.entries(filters).every(([field, expected]) => record[field] === expected);
}

function cloneUser(user) {
  return new User({
    id: user?._id,
    name: user?.name,
    email: user?.email,
    profilePicture: user?.profilePicture,
    role: user?.role,
    status: user?.status,
    stationId: user?.stationId,
    requestedRole: user?.requestedRole,
    requestCreatedAt: user?.requestCreatedAt,
    reviewedAt: user?.reviewedAt,
    reviewedBy: user?.reviewedBy,
    rejectionReason: user?.rejectionReason,
    fcmTokens: user?.fcmTokens,
    createdAt: user?.createdAt,
  });
}

function cloneUsers(users = []) {
  return users.map((user) => cloneUser(user));
}

class User {
  constructor({
    id,
    name,
    email,
    profilePicture = '',
    role = 'sales',
    status = 'pending',
    stationId = 'station-hq-01',
    requestedRole = 'sales',
    requestCreatedAt = null,
    reviewedAt = null,
    reviewedBy = null,
    rejectionReason = null,
    fcmTokens = [],
    createdAt = new Date(),
  }) {
    this._id = id;
    this.name = name;
    this.email = (email || '').trim().toLowerCase();
    this.profilePicture = profilePicture || '';
    this.role = role || 'sales';
    this.status = status || 'pending';
    this.stationId = stationId || 'station-hq-01';
    this.requestedRole = requestedRole || role || 'sales';
    this.requestCreatedAt = toDate(requestCreatedAt);
    this.reviewedAt = toDate(reviewedAt);
    this.reviewedBy = reviewedBy || null;
    this.rejectionReason = rejectionReason || null;
    this.fcmTokens = normalizeFcmTokens(fcmTokens);
    this.createdAt = toDate(createdAt) || new Date();
  }

  static fromAuthRecord(record) {
    if (!record?.uid || !record.email || !isStaffRecord(record)) {
      return null;
    }

    const claims = claimsFor(record);
    return new User({
      id: record.uid,
      name: record.displayName || record.email.split('@')[0],
      email: record.email,
      profilePicture: record.photoURL || '',
      role: claims.role || 'sales',
      status: claims.status || 'pending',
      stationId: claims.stationId || 'station-hq-01',
      requestedRole: claims.requestedRole || claims.role || 'sales',
      requestCreatedAt: claims.requestCreatedAt || null,
      reviewedAt: claims.reviewedAt || null,
      reviewedBy: claims.reviewedBy || null,
      rejectionReason: claims.rejectionReason || null,
      fcmTokens: claims.fcmTokens || [],
      createdAt: record.metadata?.creationTime,
    });
  }

  toClaims() {
    return {
      rt: CLAIMS_TYPE_STAFF,
      role: this.role,
      status: this.status,
      stationId: this.stationId,
      requestedRole: this.requestedRole || this.role,
      requestCreatedAt: this.requestCreatedAt ? this.requestCreatedAt.toISOString() : null,
      reviewedAt: this.reviewedAt ? this.reviewedAt.toISOString() : null,
      reviewedBy: this.reviewedBy || null,
      rejectionReason: this.rejectionReason || null,
      fcmTokens: normalizeFcmTokens(this.fcmTokens),
    };
  }

  async save() {
    const auth = getAuth();
    const existingRecord = await auth.getUser(this._id);
    await auth.updateUser(this._id, {
      displayName: this.name || undefined,
      photoURL: this.profilePicture || undefined,
    });
    await auth.setCustomUserClaims(this._id, {
      ...claimsFor(existingRecord),
      ...this.toClaims(),
    });
    User.invalidateCache();
    return this;
  }

  static async create(data) {
    const user = new User({...data});
    const authRecord = await getAuth().createUser({
      email: user.email,
      displayName: user.name || undefined,
      photoURL: user.profilePicture || undefined,
    });

    user._id = authRecord.uid;
    if (!user.requestCreatedAt && user.status === 'pending') {
      user.requestCreatedAt = new Date();
    }
    await getAuth().setCustomUserClaims(authRecord.uid, user.toClaims());
    User.invalidateCache();
    return User.fromAuthRecord(await getAuth().getUser(authRecord.uid));
  }

  static invalidateCache() {
    cachedUsers = null;
    cachedUsersExpiresAt = 0;
  }

  static async _allCached({forceRefresh = false} = {}) {
    if (!forceRefresh && cachedUsers != null && cachedUsersExpiresAt > Date.now()) {
      return cloneUsers(cachedUsers);
    }

    const users = (await listAllAuthUsers())
      .map((record) => User.fromAuthRecord(record))
      .filter(Boolean);
    cachedUsers = cloneUsers(users);
    cachedUsersExpiresAt = Date.now() + USER_CACHE_TTL_MS;
    return cloneUsers(users);
  }

  static async findById(id) {
    if (!id) {
      return null;
    }

    try {
      return User.fromAuthRecord(await getAuth().getUser(String(id)));
    } catch (error) {
      if (error?.code === 'auth/user-not-found') {
        return null;
      }
      throw error;
    }
  }

  static async findOne(filters = {}) {
    if (filters.email) {
      const record = await getUserByEmailSafe(String(filters.email).trim().toLowerCase());
      return User.fromAuthRecord(record);
    }
    const users = await User.find(filters, {limit: 1});
    return users[0] || null;
  }

  static async find(filters = {}, options = {}) {
    const users = (await User._allCached())
      .filter((user) => matchesFilters(user, filters));

    if (typeof options.limit === 'number') {
      return users.slice(0, options.limit);
    }

    return users;
  }

  static async deleteById(id) {
    if (!id) {
      return false;
    }

    try {
      await getAuth().deleteUser(String(id));
      User.invalidateCache();
      return true;
    } catch (error) {
      if (error?.code === 'auth/user-not-found') {
        return false;
      }
      throw error;
    }
  }

  static async recordLogin({user, name, profilePicture, fcmToken}) {
    user.name = name || user.name;
    user.profilePicture = profilePicture || user.profilePicture;
    if (fcmToken && !user.fcmTokens.includes(fcmToken)) {
      user.fcmTokens.push(fcmToken);
    }
    await user.save();
    return user;
  }

  markPending(requestedRole = 'sales') {
    this.status = 'pending';
    this.requestedRole = requestedRole;
    this.requestCreatedAt = new Date();
    this.reviewedAt = null;
    this.reviewedBy = null;
    this.rejectionReason = null;
  }

  approve(role, reviewedBy) {
    this.role = role;
    this.requestedRole = role;
    this.status = 'approved';
    this.reviewedAt = new Date();
    this.reviewedBy = reviewedBy || null;
    this.rejectionReason = null;
  }

  reject(reason, reviewedBy) {
    this.status = 'rejected';
    this.reviewedAt = new Date();
    this.reviewedBy = reviewedBy || null;
    this.rejectionReason = reason || null;
  }

  toAuthResponse() {
    return {
      id: String(this._id),
      name: this.name,
      email: this.email,
      role: this.role,
      status: this.status,
      stationId: this.stationId,
    };
  }

  toManagementJson() {
    return {
      id: String(this._id),
      name: this.name,
      email: this.email,
      role: this.role,
      requestedRole: this.requestedRole,
      status: this.status,
      stationId: this.stationId,
      createdAt: this.createdAt,
      requestCreatedAt: this.requestCreatedAt,
      reviewedAt: this.reviewedAt,
      rejectionReason: this.rejectionReason,
    };
  }
}

module.exports = User;
