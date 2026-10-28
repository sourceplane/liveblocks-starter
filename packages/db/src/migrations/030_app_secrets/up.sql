-- The site's session secret, generated once per database and never typed:
-- Auth.js signs its session cookie with it (apps/web/lib/appSecret.ts reads
-- it; an AUTH_SECRET Worker secret wins). The upstream kit fell back to a
-- secret written in its source. INSERT OR IGNORE, so a re-run never rotates it.
-- Owner: app
CREATE TABLE IF NOT EXISTS app_secrets (name TEXT PRIMARY KEY, value TEXT NOT NULL);
INSERT OR IGNORE INTO app_secrets (name, value) VALUES ('auth', lower(hex(randomblob(32))));
