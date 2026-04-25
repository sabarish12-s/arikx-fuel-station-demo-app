const admin = require('firebase-admin');

const SUPERADMIN_EMAIL = normalizeEmail(process.env.SUPERADMIN_EMAIL || 'sabarish9911@gmail.com');
const STATION_ID = process.env.STATION_ID || 'station-demo-01';
const DEVICE_ACCOUNT_AUTH_KEY = process.env.DEVICE_ACCOUNT_AUTH_KEY || '';

function firebaseApp() {
  if (admin.apps.length > 0) {
    return admin.app();
  }

  const rawServiceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!rawServiceAccount) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON is not configured.');
  }

  const serviceAccount = JSON.parse(rawServiceAccount);
  return admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: serviceAccount.project_id || 'fuel-station-demo-app',
  });
}

function auth() {
  firebaseApp();
  return admin.auth();
}

function send(res, status, payload) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PATCH, DELETE, OPTIONS');
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.statusCode = status;
  res.end(JSON.stringify(payload));
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let raw = '';
    req.on('data', (chunk) => {
      raw += chunk;
      if (raw.length > 1_000_000) {
        reject(new Error('Request body is too large.'));
        req.destroy();
      }
    });
    req.on('end', () => {
      if (!raw.trim()) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(raw));
      } catch (error) {
        reject(error);
      }
    });
    req.on('error', reject);
  });
}

async function currentUser(req) {
  const header = req.headers.authorization || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    const error = new Error('Missing Firebase ID token.');
    error.statusCode = 401;
    throw error;
  }
  const decoded = await auth().verifyIdToken(match[1]);
  const user = await auth().getUser(decoded.uid);
  await ensureSuperadmin(user);
  return auth().getUser(decoded.uid);
}

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

function requireDeviceAccountAuth(req) {
  if (!DEVICE_ACCOUNT_AUTH_KEY) {
    return;
  }
  if (req.headers['x-arikx-demo-auth'] === DEVICE_ACCOUNT_AUTH_KEY) {
    return;
  }
  const error = new Error('Device account login is not authorized.');
  error.statusCode = 401;
  throw error;
}

function claimsFor(user) {
  const claims = user.customClaims || {};
  const email = normalizeEmail(user.email);
  if (email === SUPERADMIN_EMAIL) {
    return { role: 'superadmin', status: 'approved', stationId: STATION_ID };
  }
  return {
    role: String(claims.role || 'sales'),
    status: String(claims.status || 'pending'),
    stationId: String(claims.stationId || STATION_ID),
    rejectionReason: String(claims.rejectionReason || ''),
  };
}

function displayNameFor(user) {
  return user.displayName || (user.email || '').split('@')[0] || 'Station User';
}

function authUserJson(user) {
  const claims = claimsFor(user);
  return {
    id: user.uid,
    name: displayNameFor(user),
    email: user.email || '',
    role: claims.role,
    status: claims.status,
    stationId: claims.stationId,
  };
}

function managedUserJson(user) {
  const claims = claimsFor(user);
  const createdAt = user.metadata.creationTime
    ? new Date(user.metadata.creationTime).toISOString()
    : new Date(0).toISOString();
  const reviewedAt = claims.status === 'pending'
    ? ''
    : user.metadata.lastRefreshTime
      ? new Date(user.metadata.lastRefreshTime).toISOString()
      : createdAt;
  return {
    ...authUserJson(user),
    requestedRole: claims.role || 'sales',
    createdAt,
    requestCreatedAt: claims.status === 'pending' ? createdAt : '',
    reviewedAt,
    rejectionReason: claims.rejectionReason || '',
  };
}

function accessRequestJson(user) {
  const managed = managedUserJson(user);
  return {
    id: user.uid,
    userId: user.uid,
    stationId: managed.stationId,
    name: managed.name,
    email: managed.email,
    roleRequested: managed.requestedRole || 'sales',
    status: managed.status,
    createdAt: managed.requestCreatedAt || managed.createdAt,
  };
}

async function ensureSuperadmin(user) {
  if (normalizeEmail(user.email) !== SUPERADMIN_EMAIL) {
    return;
  }
  const claims = user.customClaims || {};
  if (
    claims.role === 'superadmin' &&
    claims.status === 'approved' &&
    claims.stationId === STATION_ID
  ) {
    return;
  }
  await auth().setCustomUserClaims(user.uid, {
    ...claims,
    role: 'superadmin',
    status: 'approved',
    stationId: STATION_ID,
  });
}

async function requireSuperadmin(req) {
  const user = await currentUser(req);
  const claims = claimsFor(user);
  if (claims.role !== 'superadmin' || claims.status !== 'approved') {
    const error = new Error('Only the superadmin can manage access.');
    error.statusCode = 403;
    throw error;
  }
  return user;
}

async function listAllUsers() {
  const users = [];
  let pageToken;
  do {
    const page = await auth().listUsers(1000, pageToken);
    users.push(...page.users);
    pageToken = page.pageToken;
  } while (pageToken);

  for (const user of users) {
    await ensureSuperadmin(user);
  }
  return users;
}

function overviewFrom(users) {
  const managedUsers = users.map(managedUserJson);
  const requests = users
    .filter((user) => claimsFor(user).status === 'pending')
    .map(accessRequestJson);
  const approved = managedUsers.filter((user) => user.status === 'approved');
  return {
    summary: {
      totalUsers: managedUsers.length,
      approvedUsers: approved.length,
      pendingRequests: requests.length,
      adminCount: approved.filter((user) => user.role === 'admin').length,
      salesCount: approved.filter((user) => user.role === 'sales').length,
      superAdminCount: approved.filter((user) => user.role === 'superadmin').length,
    },
    permissions: { canManageSuperAdmins: true },
    users: managedUsers,
    requests,
  };
}

async function setAccess(uid, status, role, rejectionReason = '') {
  const user = await auth().getUser(uid);
  if (normalizeEmail(user.email) === SUPERADMIN_EMAIL) {
    await ensureSuperadmin(user);
    return auth().getUser(uid);
  }

  await auth().setCustomUserClaims(uid, {
    ...(user.customClaims || {}),
    role: role || claimsFor(user).role || 'sales',
    status,
    stationId: STATION_ID,
    rejectionReason,
  });
  await auth().revokeRefreshTokens(uid);
  return auth().getUser(uid);
}

async function deleteManagedUser(uid) {
  const user = await auth().getUser(uid);
  if (normalizeEmail(user.email) === SUPERADMIN_EMAIL) {
    const error = new Error('The superadmin account cannot be deleted.');
    error.statusCode = 400;
    throw error;
  }
  await auth().deleteUser(uid);
}

async function createOrUpdateStaff(body) {
  const email = normalizeEmail(body.email);
  if (!email) {
    const error = new Error('Email is required.');
    error.statusCode = 400;
    throw error;
  }

  let user;
  try {
    user = await auth().getUserByEmail(email);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') {
      throw error;
    }
    user = await auth().createUser({
      email,
      displayName: String(body.name || '').trim() || email.split('@')[0],
      emailVerified: true,
    });
  }
  return setAccess(user.uid, 'approved', String(body.role || 'sales'));
}

async function verifyGoogleIdentity(body) {
  const idToken = String(body.idToken || '').trim();
  const accessToken = String(body.accessToken || '').trim();
  let tokenInfo;

  if (idToken) {
    const response = await fetch(
      `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`,
    );
    tokenInfo = await response.json();
    if (!response.ok) {
      const error = new Error(tokenInfo.error_description || 'Google ID token is invalid.');
      error.statusCode = 401;
      throw error;
    }
  } else if (accessToken) {
    const response = await fetch(
      `https://oauth2.googleapis.com/tokeninfo?access_token=${encodeURIComponent(accessToken)}`,
    );
    tokenInfo = await response.json();
    if (!response.ok) {
      const error = new Error(tokenInfo.error_description || 'Google access token is invalid.');
      error.statusCode = 401;
      throw error;
    }
  } else {
    const error = new Error('Google token is required.');
    error.statusCode = 400;
    throw error;
  }

  const verifiedEmail = normalizeEmail(tokenInfo.email);
  const requestedEmail = normalizeEmail(body.email);
  if (!verifiedEmail || (requestedEmail && requestedEmail !== verifiedEmail)) {
    const error = new Error('Google account email could not be verified.');
    error.statusCode = 401;
    throw error;
  }

  if (
    tokenInfo.email_verified !== undefined &&
    String(tokenInfo.email_verified).toLowerCase() !== 'true'
  ) {
    const error = new Error('Google account email is not verified.');
    error.statusCode = 401;
    throw error;
  }

  return {
    email: verifiedEmail,
    name: String(body.name || tokenInfo.name || verifiedEmail.split('@')[0]).trim(),
    photoUrl: String(body.photoUrl || tokenInfo.picture || '').trim(),
  };
}

async function firebaseUserForGoogleIdentity(identity) {
  let user;
  try {
    user = await auth().getUserByEmail(identity.email);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') {
      throw error;
    }
    user = await auth().createUser({
      email: identity.email,
      displayName: identity.name,
      photoURL: identity.photoUrl || undefined,
      emailVerified: true,
    });
  }

  const updates = {};
  if (identity.name && user.displayName !== identity.name) {
    updates.displayName = identity.name;
  }
  if (identity.photoUrl && user.photoURL !== identity.photoUrl) {
    updates.photoURL = identity.photoUrl;
  }
  if (!user.emailVerified) {
    updates.emailVerified = true;
  }
  if (Object.keys(updates).length > 0) {
    user = await auth().updateUser(user.uid, updates);
  }

  if (normalizeEmail(user.email) === SUPERADMIN_EMAIL) {
    await ensureSuperadmin(user);
  } else {
    const claims = user.customClaims || {};
    if (!claims.status) {
      user = await setAccess(user.uid, 'pending', 'sales');
    }
  }
  return auth().getUser(user.uid);
}

async function firebaseUserForDeviceAccount(body) {
  const email = normalizeEmail(body.email);
  if (!email || !email.endsWith('@gmail.com')) {
    const error = new Error('Please select a valid Gmail account.');
    error.statusCode = 400;
    throw error;
  }

  let user;
  try {
    user = await auth().getUserByEmail(email);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') {
      throw error;
    }
    user = await auth().createUser({
      email,
      displayName: String(body.name || email.split('@')[0]).trim(),
      emailVerified: true,
    });
  }

  if (normalizeEmail(user.email) === SUPERADMIN_EMAIL) {
    await ensureSuperadmin(user);
  } else {
    const claims = user.customClaims || {};
    if (!claims.status) {
      user = await setAccess(user.uid, 'pending', 'sales');
    }
  }
  return auth().getUser(user.uid);
}

async function route(req, res) {
  if (req.method === 'OPTIONS') {
    send(res, 204, {});
    return;
  }

  const url = new URL(req.url, 'https://arikx-fuel-station-auth.local');
  const pathname = url.pathname.replace(/^\/api/, '') || '/';

  if (req.method === 'GET' && pathname === '/health') {
    send(res, 200, { ok: true, app: 'Arikx fuel station auth' });
    return;
  }

  if (req.method === 'POST' && pathname === '/auth/google') {
    const identity = await verifyGoogleIdentity(await readJson(req));
    const user = await firebaseUserForGoogleIdentity(identity);
    const customToken = await auth().createCustomToken(user.uid);
    send(res, 200, { user: authUserJson(user), customToken });
    return;
  }

  if (req.method === 'POST' && pathname === '/auth/device-account') {
    requireDeviceAccountAuth(req);
    const user = await firebaseUserForDeviceAccount(await readJson(req));
    const customToken = await auth().createCustomToken(user.uid);
    send(res, 200, { user: authUserJson(user), customToken });
    return;
  }

  if (req.method === 'POST' && pathname === '/auth/me') {
    const user = await currentUser(req);
    const claims = claimsFor(user);
    if (claims.status !== 'approved' && normalizeEmail(user.email) !== SUPERADMIN_EMAIL) {
      await setAccess(user.uid, 'pending', claims.role || 'sales');
    }
    send(res, 200, { user: authUserJson(await auth().getUser(user.uid)) });
    return;
  }

  if (req.method === 'GET' && pathname === '/users/management') {
    await requireSuperadmin(req);
    send(res, 200, overviewFrom(await listAllUsers()));
    return;
  }

  if (req.method === 'GET' && pathname === '/users/requests') {
    await requireSuperadmin(req);
    const users = await listAllUsers();
    send(res, 200, {
      requests: users
        .filter((user) => claimsFor(user).status === 'pending')
        .map(accessRequestJson),
    });
    return;
  }

  const approveMatch = pathname.match(/^\/users\/requests\/([^/]+)\/approve$/);
  if (req.method === 'POST' && approveMatch) {
    await requireSuperadmin(req);
    const body = await readJson(req);
    const user = await setAccess(approveMatch[1], 'approved', String(body.role || 'sales'));
    send(res, 200, { user: managedUserJson(user) });
    return;
  }

  const rejectMatch = pathname.match(/^\/users\/requests\/([^/]+)\/reject$/);
  if (req.method === 'POST' && rejectMatch) {
    await requireSuperadmin(req);
    const body = await readJson(req);
    const user = await setAccess(
      rejectMatch[1],
      'rejected',
      'sales',
      String(body.reason || 'Rejected by superadmin.'),
    );
    send(res, 200, { user: managedUserJson(user) });
    return;
  }

  if (req.method === 'POST' && pathname === '/users/requests/bulk-approve') {
    await requireSuperadmin(req);
    const body = await readJson(req);
    const items = Array.isArray(body.items) ? body.items : [];
    await Promise.all(
      items.map((item) => setAccess(String(item.requestId || item.id), 'approved', String(item.role || 'sales'))),
    );
    send(res, 200, { ok: true });
    return;
  }

  if (req.method === 'POST' && pathname === '/users/requests/bulk-delete') {
    await requireSuperadmin(req);
    const body = await readJson(req);
    const ids = Array.isArray(body.requestIds) ? body.requestIds : [];
    await Promise.all(ids.map((uid) => deleteManagedUser(String(uid))));
    send(res, 200, { ok: true });
    return;
  }

  if (req.method === 'POST' && pathname === '/users/staff') {
    await requireSuperadmin(req);
    const user = await createOrUpdateStaff(await readJson(req));
    send(res, 201, { user: managedUserJson(user) });
    return;
  }

  const staffMatch = pathname.match(/^\/users\/staff\/([^/]+)$/);
  if (staffMatch && req.method === 'PATCH') {
    await requireSuperadmin(req);
    const body = await readJson(req);
    const user = await setAccess(staffMatch[1], 'approved', String(body.role || 'sales'));
    send(res, 200, { user: managedUserJson(user) });
    return;
  }

  if (staffMatch && req.method === 'DELETE') {
    await requireSuperadmin(req);
    await deleteManagedUser(staffMatch[1]);
    send(res, 200, { ok: true });
    return;
  }

  send(res, 404, { message: 'Route not found.' });
}

module.exports = async function handler(req, res) {
  try {
    await route(req, res);
  } catch (error) {
    send(res, error.statusCode || 500, {
      message: error.statusCode ? error.message : 'Auth service failed.',
      error: error.statusCode ? undefined : error.message,
    });
  }
};
