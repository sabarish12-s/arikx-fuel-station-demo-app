const String backendBaseUrl = String.fromEnvironment(
  'BACKEND_BASE_URL',
  defaultValue: 'demo://local-static-data',
);

const String authBackendBaseUrl = String.fromEnvironment(
  'AUTH_BACKEND_BASE_URL',
  defaultValue: '',
);

const String deviceAccountAuthKey = String.fromEnvironment(
  'DEVICE_ACCOUNT_AUTH_KEY',
  defaultValue: '',
);

const String googleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue: '',
);

const String googleClientId = String.fromEnvironment(
  'GOOGLE_CLIENT_ID',
  defaultValue: '',
);
