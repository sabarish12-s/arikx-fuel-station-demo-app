const jwt = require('jsonwebtoken');
const User = require('../models/User');
const {jwtSecret} = require('../config/env');

async function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization || '';
  const [, token] = authHeader.split(' ');

  if (!token) {
    return res.status(401).json({message: 'Missing Bearer token'});
  }
  if (!jwtSecret) {
    return res.status(500).json({message: 'JWT_SECRET is not configured'});
  }

  try {
    const payload = jwt.verify(token, jwtSecret);
    const user = await User.findById(payload.sub);
    if (!user) {
      return res.status(401).json({message: 'Invalid token user'});
    }
    req.authUser = user;
    return next();
  } catch (error) {
    return res.status(401).json({message: 'Invalid token', error: error.message});
  }
}

function requireApproved(req, res, next) {
  if (!req.authUser || req.authUser.status !== 'approved') {
    return res.status(403).json({message: 'Approved account required'});
  }
  return next();
}

function requireSuperAdmin(req, res, next) {
  if (!req.authUser || req.authUser.status !== 'approved' || req.authUser.role !== 'superadmin') {
    return res.status(403).json({message: 'Superadmin access required'});
  }
  return next();
}

function requireManagement(req, res, next) {
  if (
    !req.authUser ||
    req.authUser.status !== 'approved' ||
    !['admin', 'superadmin'].includes(req.authUser.role)
  ) {
    return res.status(403).json({message: 'Management access required'});
  }
  return next();
}

module.exports = {requireApproved, requireAuth, requireManagement, requireSuperAdmin};
