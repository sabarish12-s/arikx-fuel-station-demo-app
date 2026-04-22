const express = require('express');
const jwt = require('jsonwebtoken');
const {OAuth2Client} = require('google-auth-library');

const AccessRequest = require('../models/AccessRequest');
const User = require('../models/User');
const {requireAuth} = require('../middleware/auth');
const {
  adminEmail,
  googleClientId,
  googleClientIds,
  jwtExpiresIn,
  jwtSecret,
} = require('../config/env');
const {sendFcmToTokens} = require('../services/fcm');
const {sendMail} = require('../services/mailer');

const router = express.Router();
const oauthClient = new OAuth2Client(googleClientId || undefined);

function issueJwt(user) {
  return jwt.sign(
    {
      sub: String(user._id),
      email: user.email,
      role: user.role,
      status: user.status,
      stationId: user.stationId,
    },
    jwtSecret,
    {expiresIn: jwtExpiresIn},
  );
}

async function notifySuperAdmin(user, superAdminTokens) {
  const results = await Promise.allSettled([
    sendFcmToTokens(superAdminTokens, {
      notification: {
        title: 'New Access Request',
        body: `${user.name} (${user.email}) requested access.`,
      },
      data: {
        type: 'access_request',
        userId: String(user._id),
        email: user.email,
      },
    }),
    sendMail({
      to: adminEmail,
      subject: 'RK Fuels: New access request',
      text: `${user.name} (${user.email}) has requested access.`,
      html: `<p><strong>${user.name}</strong> (${user.email}) has requested access.</p>`,
    }),
  ]);

  for (const result of results) {
    if (result.status === 'rejected') {
      console.error('Superadmin notification failed:', result.reason?.message || result.reason);
    }
  }
}

router.get('/me', requireAuth, async (req, res) => {
  return res.status(200).json({user: req.authUser.toAuthResponse()});
});

router.post('/google', async (req, res) => {
  try {
    const {idToken, fcmToken} = req.body || {};
    if (!idToken || typeof idToken !== 'string') {
      return res.status(400).json({message: 'idToken is required'});
    }
    if (!jwtSecret) {
      return res.status(500).json({message: 'JWT_SECRET is not configured'});
    }

    const verifyPayload = {idToken};
    if (googleClientIds.length === 1) {
      verifyPayload.audience = googleClientIds[0];
    } else if (googleClientIds.length > 1) {
      verifyPayload.audience = googleClientIds;
    } else if (googleClientId) {
      verifyPayload.audience = googleClientId;
    }

    let ticket;
    try {
      ticket = await oauthClient.verifyIdToken(verifyPayload);
    } catch (error) {
      return res.status(401).json({
        message: 'Invalid Google token',
        error: error instanceof Error ? error.message : 'Unknown error',
      });
    }

    const payload = ticket.getPayload();
    if (!payload?.email) {
      return res.status(401).json({message: 'Google token has no email'});
    }

    const email = payload.email.toLowerCase();
    const name = payload.name || email.split('@')[0];
    const profilePicture = payload.picture || '';
    const normalizedFcmToken =
      typeof fcmToken === 'string' && fcmToken.trim() ? fcmToken.trim() : null;
    const isSuperAdminEmail = email === adminEmail;

    let user = await User.findOne({email});
    if (!user) {
      user = await User.create({
        name,
        email,
        profilePicture,
        role: isSuperAdminEmail ? 'superadmin' : 'sales',
        status: isSuperAdminEmail ? 'approved' : 'pending',
        stationId: 'station-hq-01',
        requestedRole: 'sales',
        requestCreatedAt: isSuperAdminEmail ? null : new Date(),
        fcmTokens: normalizedFcmToken ? [normalizedFcmToken] : [],
      });

      if (!isSuperAdminEmail) {
        await AccessRequest.create({
          userId: user._id,
          stationId: user.stationId,
          email: user.email,
          name: user.name,
          roleRequested: 'sales',
          status: 'pending',
          createdAt: new Date(),
        });

        const superAdmins = await User.find({role: 'superadmin', status: 'approved'});
        await notifySuperAdmin(
          user,
          superAdmins.flatMap((adminUser) => adminUser.fcmTokens || []),
        );
      }
    } else {
      if (isSuperAdminEmail) {
        user.approve('superadmin', 'system');
      }
      await User.recordLogin({
        user,
        name,
        profilePicture,
        fcmToken: normalizedFcmToken,
      });
    }

    const token = issueJwt(user);
    return res.status(200).json({
      user: user.toAuthResponse(),
      token,
    });
  } catch (error) {
    return res.status(500).json({
      message: 'Failed to authenticate user',
      error: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

module.exports = router;
