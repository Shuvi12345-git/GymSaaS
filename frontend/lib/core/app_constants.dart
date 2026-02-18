// ---------------------------------------------------------------------------
// App constants – version and other build-time or app-wide values.
// ---------------------------------------------------------------------------
// [kAppVersion] is used when calling /version to prompt user to update if
// backend returns a higher min_app_version.
// ---------------------------------------------------------------------------

/// App version for update check. Must match pubspec version or be passed via --dart-define.
const String kAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.0',
);
