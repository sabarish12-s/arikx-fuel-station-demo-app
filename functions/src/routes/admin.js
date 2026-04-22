const express = require('express');

const AccessRequest = require('../models/AccessRequest');
const User = require('../models/User');
const {requireApproved, requireAuth, requireSuperAdmin} = require('../middleware/auth');
const {sendFcmToTokens} = require('../services/fcm');

const router = express.Router();

router.use(requireAuth, requireApproved, requireSuperAdmin);

router.get('/requests', async (_req, res) => {
  try {
    const requests = await AccessRequest.find({status: 'pending'});
    return res.status(200).json({
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
    });
  } catch (error) {
    return res.status(500).json({
      message: 'Failed to fetch requests',
      error: error.message,
    });
  }
});

router.post('/requests/:requestId/approve', async (req, res) => {
  try {
    const requestDoc = await AccessRequest.findById(req.params.requestId);
    if (!requestDoc) {
      return res.status(404).json({message: 'Request not found'});
    }

    const user = await User.findById(requestDoc.userId);
    if (!user) {
      return res.status(404).json({message: 'User not found'});
    }

    user.approve(requestDoc.roleRequested === 'admin' ? 'admin' : 'sales', req.authUser._id);
    await user.save();

    try {
      await sendFcmToTokens(user.fcmTokens, {
        notification: {
          title: 'Access Approved',
          body: 'Your RK Fuels account has been approved. You can login now.',
        },
        data: {
          type: 'access_approved',
          userId: String(user._id),
        },
      });
    } catch (notifyError) {
      console.error('Approval notification failed:', notifyError.message);
    }

    return res.status(200).json({
      message: 'Request approved',
      user: user.toAuthResponse(),
    });
  } catch (error) {
    return res.status(500).json({
      message: 'Failed to approve request',
      error: error.message,
    });
  }
});

module.exports = router;
