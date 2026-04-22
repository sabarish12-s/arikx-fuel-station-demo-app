const express = require('express');

const AccessRequest = require('../models/AccessRequest');
const {adminEmail} = require('../config/env');
const User = require('../models/User');
const {requireApproved, requireAuth, requireSuperAdmin} = require('../middleware/auth');
const {sendFcmToTokens} = require('../services/fcm');

const router = express.Router();

router.use(requireAuth, requireApproved, requireSuperAdmin);

function normalizeRole(role) {
  return role === 'admin' ? 'admin' : 'sales';
}

function canManageSuperAdmins(actor) {
  return String(actor?.email || '').toLowerCase() === adminEmail;
}

function normalizeManagedRole(role, actor) {
  if (role === 'superadmin' && canManageSuperAdmins(actor)) {
    return 'superadmin';
  }
  return normalizeRole(role);
}

function canManageUser(actor, user) {
  if (!user) {
    return false;
  }
  if (String(actor?._id) === String(user._id)) {
    return false;
  }
  if (user.role === 'superadmin') {
    return canManageSuperAdmins(actor);
  }
  return true;
}

function summarizeUsers(users, requests) {
  const approvedUsers = users.filter((user) => user.status === 'approved');
  return {
    totalUsers: users.length,
    approvedUsers: approvedUsers.length,
    pendingRequests: requests.length,
    adminCount: approvedUsers.filter((user) => user.role === 'admin').length,
    salesCount: approvedUsers.filter((user) => user.role === 'sales').length,
    superAdminCount: approvedUsers.filter((user) => user.role === 'superadmin').length,
  };
}

async function loadOverview(actor) {
  const [users, requests] = await Promise.all([
    User.find(),
    AccessRequest.find({status: 'pending'}),
  ]);

  users.sort((a, b) => a.email.localeCompare(b.email));
  requests.sort((a, b) => b.createdAt - a.createdAt);

  return {
    summary: summarizeUsers(users, requests),
    permissions: {
      canManageSuperAdmins: canManageSuperAdmins(actor),
    },
    users: users.map((user) => user.toManagementJson()),
    requests: requests.map((request) => ({
      id: String(request._id),
      userId: String(request.userId),
      stationId: request.stationId,
      name: request.name,
      email: request.email,
      roleRequested: request.roleRequested,
      status: request.status,
      createdAt: request.createdAt,
    })),
  };
}

async function approveRequest(requestDoc, actor, role) {
  const user = await User.findById(requestDoc.userId);
  if (!user) {
    return {status: 404, body: {message: 'User not found'}};
  }

  user.approve(role, actor._id);
  await user.save();

  try {
    await sendFcmToTokens(user.fcmTokens, {
      notification: {
        title: 'Access Approved',
        body: `Your RK Fuels account has been approved as ${role}.`,
      },
      data: {
        type: 'access_approved',
        role,
        userId: String(user._id),
      },
    });
  } catch (notifyError) {
    console.error('Approval notification failed:', notifyError.message);
  }

  return {
    status: 200,
    body: {
      message: 'Request approved',
      user: user.toAuthResponse(),
    },
  };
}

router.get('/requests', async (req, res) => {
  const overview = await loadOverview(req.authUser);
  return res.status(200).json({requests: overview.requests});
});

router.get('/management', async (req, res) => {
  const overview = await loadOverview(req.authUser);
  return res.status(200).json(overview);
});

router.post('/staff', async (req, res) => {
  const email = req.body?.email?.toString().trim().toLowerCase();
  const name = req.body?.name?.toString().trim() || '';
  const role = normalizeManagedRole(req.body?.role?.toString(), req.authUser);

  if (!email) {
    return res.status(400).json({message: 'Email is required'});
  }

  let user = await User.findOne({email});

  if (user && !canManageUser(req.authUser, user) && user.role === 'superadmin') {
    return res.status(409).json({message: 'This superadmin account cannot be managed here'});
  }

  if (!user) {
    user = await User.create({
      name: name || email.split('@')[0],
      email,
      role,
      status: 'approved',
      stationId: 'station-hq-01',
      requestedRole: role,
      reviewedAt: new Date(),
      reviewedBy: req.authUser._id,
    });
  } else {
    user.name = name || user.name;
    user.stationId = 'station-hq-01';
    user.approve(role, req.authUser._id);
    await user.save();
  }

  return res.status(201).json({
    message: 'Staff member saved',
    user: user.toManagementJson(),
  });
});

router.patch('/staff/:userId', async (req, res) => {
  const user = await User.findById(req.params.userId);
  if (!user) {
    return res.status(404).json({message: 'User not found'});
  }
  if (!canManageUser(req.authUser, user)) {
    return res.status(403).json({message: 'This account cannot be edited here'});
  }

  const role = normalizeManagedRole(req.body?.role?.toString(), req.authUser);
  user.approve(role, req.authUser._id);
  await user.save();

  return res.status(200).json({
    message: 'User role updated',
    user: user.toManagementJson(),
  });
});

router.delete('/staff/:userId', async (req, res) => {
  const user = await User.findById(req.params.userId);
  if (!user) {
    return res.status(404).json({message: 'User not found'});
  }
  if (!canManageUser(req.authUser, user)) {
    return res.status(403).json({message: 'This account cannot be deleted here'});
  }

  const deleted = await User.deleteById(user._id);
  if (!deleted) {
    return res.status(404).json({message: 'User not found'});
  }

  return res.status(200).json({message: 'User deleted'});
});

router.post('/requests/bulk-approve', async (req, res) => {
  const items = Array.isArray(req.body?.items) ? req.body.items : [];
  if (items.length === 0) {
    return res.status(400).json({message: 'At least one request is required'});
  }

  const results = [];
  for (const item of items) {
    const requestDoc = await AccessRequest.findById(item?.requestId);
    if (!requestDoc) {
      results.push({requestId: item?.requestId, status: 'missing'});
      continue;
    }
    const role = normalizeManagedRole(
      item?.role?.toString() || requestDoc.roleRequested,
      req.authUser,
    );
    const result = await approveRequest(requestDoc, req.authUser, role);
    results.push({
      requestId: item?.requestId,
      status: result.status === 200 ? 'approved' : 'error',
    });
  }

  return res.status(200).json({message: 'Bulk approval completed', results});
});

router.post('/requests/bulk-delete', async (req, res) => {
  const requestIds = Array.isArray(req.body?.requestIds) ? req.body.requestIds : [];
  if (requestIds.length === 0) {
    return res.status(400).json({message: 'At least one request is required'});
  }

  const results = [];
  for (const requestId of requestIds) {
    const requestDoc = await AccessRequest.findById(requestId);
    if (!requestDoc) {
      results.push({requestId, status: 'missing'});
      continue;
    }
    const user = await User.findById(requestDoc.userId);
    if (!user) {
      results.push({requestId, status: 'missing-user'});
      continue;
    }
    if (!canManageUser(req.authUser, user) && user.role === 'superadmin') {
      results.push({requestId, status: 'forbidden'});
      continue;
    }
    await User.deleteById(user._id);
    results.push({requestId, status: 'deleted'});
  }

  return res.status(200).json({message: 'Bulk delete completed', results});
});

router.post('/requests/:requestId/approve', async (req, res) => {
  const requestDoc = await AccessRequest.findById(req.params.requestId);
  if (!requestDoc) {
    return res.status(404).json({message: 'Request not found'});
  }

  const role = normalizeManagedRole(
    req.body?.role?.toString() || requestDoc.roleRequested,
    req.authUser,
  );
  const result = await approveRequest(requestDoc, req.authUser, role);
  return res.status(result.status).json(result.body);
});

router.post('/requests/:requestId/reject', async (req, res) => {
  const requestDoc = await AccessRequest.findById(req.params.requestId);
  if (!requestDoc) {
    return res.status(404).json({message: 'Request not found'});
  }

  const user = await User.findById(requestDoc.userId);
  if (!user) {
    return res.status(404).json({message: 'User not found'});
  }

  user.reject(
    req.body?.reason?.toString() || 'Request rejected by superadmin.',
    req.authUser._id,
  );
  await user.save();

  return res.status(200).json({
    message: 'Request rejected',
    user: user.toAuthResponse(),
  });
});

module.exports = router;
