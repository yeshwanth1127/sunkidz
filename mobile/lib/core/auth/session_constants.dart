/// Client and server session length (must match backend JWT_ACCESS_TOKEN_EXPIRE_MINUTES).
const int sessionDurationDays = 30;

/// Shown on login after automatic logout when the session ended.
const String sessionExpiredLoginMessage =
    "It's been a while — please sign in again to continue.";
