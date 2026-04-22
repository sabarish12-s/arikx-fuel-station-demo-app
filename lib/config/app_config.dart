const String backendBaseUrl = String.fromEnvironment(
  'BACKEND_BASE_URL',
  defaultValue: 'https://asia-south1-rk-fuels-app-2026.cloudfunctions.net/api',
);

const String googleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue:
      '62828412342-i9jvc5lnbsebi7g43nn5doiiurva12e2.apps.googleusercontent.com',
);

const String googleClientId = String.fromEnvironment(
  'GOOGLE_CLIENT_ID',
  defaultValue: '',
);
