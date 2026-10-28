-- The directory the app reads through apps/web/lib/database: users,
-- organizations, and who belongs to which, in order — a user's first
-- organization is the one they land in. The upstream kit kept these as
-- arrays in data/users.ts and data/organizations.ts.
-- Owner: app
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  avatar TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS organizations (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  avatar TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS memberships (
  user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  organization_id TEXT NOT NULL REFERENCES organizations (id) ON DELETE CASCADE,
  position INTEGER NOT NULL,
  PRIMARY KEY (user_id, organization_id)
);
CREATE INDEX IF NOT EXISTS memberships_organization ON memberships (organization_id);
