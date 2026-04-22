# RK Fuels (Flutter App)

## Firebase project

This app is linked to:

- Project ID: `rk-fuels-app-2026`

Registered apps were created with `flutterfire configure`, and config is in:

- `lib/firebase_options.dart`

## Required Firebase Console step

Enable Google provider in:

- Firebase Console -> Authentication -> Sign-in method -> Google -> Enable

## Run

Use your backend URL and Google client IDs:

```bash
flutter run \
  --dart-define=BACKEND_BASE_URL=https://your-render-api.onrender.com \
  --dart-define=GOOGLE_WEB_CLIENT_ID=your-web-client-id.apps.googleusercontent.com \
  --dart-define=GOOGLE_CLIENT_ID=your-ios-client-id.apps.googleusercontent.com
```

Notes:
- `GOOGLE_WEB_CLIENT_ID` is used as `serverClientId` so Google returns `idToken`.
- `GOOGLE_CLIENT_ID` is optional for Android, but useful for iOS/web compatibility.

## Firebase Functions backend

The Express backend can be deployed from `functions` as the `api` HTTPS function.

1. Create `functions/.env` from `functions/.env.example` and fill the real values.
2. Deploy:
   ```bash
   firebase deploy --only functions
   ```
3. Test the health endpoint:
   ```bash
   curl https://asia-south1-rk-fuels-app-2026.cloudfunctions.net/api/health
   ```
4. Test the Flutter app against Firebase Functions without changing source:
   ```bash
   flutter run \
     --dart-define=BACKEND_BASE_URL=https://asia-south1-rk-fuels-app-2026.cloudfunctions.net/api \
     --dart-define=GOOGLE_WEB_CLIENT_ID=your-web-client-id.apps.googleusercontent.com \
     --dart-define=GOOGLE_CLIENT_ID=your-ios-client-id.apps.googleusercontent.com
   ```

The Firebase Functions backend uses the project's built-in Firebase Admin credentials, so it does not need `FIREBASE_SERVICE_ACCOUNT_JSON` when deployed on Firebase.

## Auth flow implemented

1. Tap **Continue with Google**
2. Get Google `idToken`
3. Capture FCM token (if available)
4. Send to backend `POST /auth/google` with `{ idToken, fcmToken }`
5. Store returned JWT + user payload securely
6. Navigate by role/status:
   - `pending` -> Access Pending screen
   - `approved + role=sales/admin` -> Sales Dashboard
   - `approved + role=superadmin` -> Superadmin Requests screen

## Admin workflow implemented

- Superadmin email is `sabarish9911@gmail.com` (configured server-side).
- New non-admin users get created as:
  - `role=sales`
  - `status=pending`
- Superadmin can load and approve pending requests from the app (`/admin/requests`).
- On approval, user status becomes `approved` and they can access dashboard.

## FCM notes

- Flutter app now sends device FCM token to backend during login.
- Backend uses that for:
  - notifying superadmin on new pending requests
  - notifying user when approved

The Render backend needs valid Firebase Cloud Messaging credentials via `FIREBASE_SERVICE_ACCOUNT_JSON`; the Firebase Functions backend uses built-in project credentials.
4. Store returned JWT securely (`flutter_secure_storage`)
5. Navigate:
   - `pending` -> Pending Approval screen
   - `approved` -> Dashboard

## App icon and splash

- Logo asset: `assets/images/hp_logo.png`
- Launcher icons generated via `flutter_launcher_icons`
- Splash generated via `flutter_native_splash`
