# School app API connection

The main URL is stored once in `AppConfig.mainUrl` in `lib/config/config.dart`:

    https://edlive-admin-web-frontend-nine.vercel.app

Pages use `AppConfig.serverOrigin`, `AppConfig.baseUrl`, or `AppConfig.apiUri()`.
VS Code debug/profile/release launches use this shared config without URL overrides.
Change `AppConfig.mainUrl` to update the default URL across the app.

AppConfig adds /api for API requests. SERVER_ORIGIN and API_BASE_URL dart-define
arguments override config.dart, so remove any old EC2/Azure overrides from custom
terminal commands. Restart/rebuild the app after changing compile-time settings.

## Flutter Web

The VS Code launch configurations use 127.0.0.1:8081. For a terminal run:

    flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8081

In the backend Vercel project, add these exact origins to CORS_ORIGINS in the
Production environment, preserving any other approved entries:

    http://127.0.0.1:8081,http://localhost:8081

Redeploy after changing environment variables. The backend repository's private
.env.production and .env.vercel files contain these prepared settings; local file
edits do not update the running Vercel deployment. If Flutter Web is hosted at
another domain, add that actual origin to the same setting.

The production API health endpoint responds at /api/health. A successful health
check verifies database connectivity but does not verify CORS or account login.
Use browser network tools to confirm the OPTIONS preflight is accepted as well.
The existing tool/dev_api_proxy.dart is optional legacy tooling and is not the
app's default backend. Do not use its old upstream URL for this deployment.

## Shared student and teacher accounts

Admin web and the school app authenticate against the backend's same users table.
Do not place PostgreSQL credentials, the JWT secret, or Supabase secret keys in
Flutter. Keep those settings in Vercel's backend environment variables.

Temporary-password accounts must set a new password before opening dashboards.
The app now displays that screen during login. Password changes apply to the
same account in both clients. Teachers need staff.user_id linked to users.id;
students need students.user_id linked to users.id. Ask the administrator to
resolve missing links rather than using an account ID as a staff profile ID.

Native Android/iOS requests without an Origin header already pass API CORS.
Private images/documents still need authenticated downloads. Large file uploads
must use signed direct Storage uploads to avoid Vercel's request body limit;
those feature flows require separate device/browser checks before rollout.
