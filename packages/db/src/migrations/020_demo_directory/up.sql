-- The kit's demo directory, as data/users.ts and data/organizations.ts held
-- it: the users its demo sign-in accepts and the organizations they share.
-- INSERT OR IGNORE, so it never overwrites a row the owner changed. Replace
-- or remove it with a new migration once the site signs real people in.
-- Owner: app
INSERT OR IGNORE INTO organizations (id, name, avatar) VALUES ('liveblocks', 'Liveblocks', '/liveblocks.png');
INSERT OR IGNORE INTO organizations (id, name, avatar) VALUES ('charlie.layne@example.com', 'Charlie''s space', 'https://liveblocks.io/avatars/avatar-2.png');
INSERT OR IGNORE INTO organizations (id, name, avatar) VALUES ('mislav.abha@example.com', 'Mislav''s space', 'https://liveblocks.io/avatars/avatar-3.png');
INSERT OR IGNORE INTO organizations (id, name, avatar) VALUES ('tatum.paolo@example.com', 'Tatum''s space', 'https://liveblocks.io/avatars/avatar-4.png');
INSERT OR IGNORE INTO organizations (id, name, avatar) VALUES ('anjali.wanda@example.com', 'Anjali''s space', 'https://liveblocks.io/avatars/avatar-5.png');
INSERT OR IGNORE INTO organizations (id, name, avatar) VALUES ('emil.joyce@example.com', 'Emil''s space', 'https://liveblocks.io/avatars/avatar-6.png');
INSERT OR IGNORE INTO users (id, name, avatar) VALUES ('charlie.layne@example.com', 'Charlie Layne', 'https://liveblocks.io/avatars/avatar-2.png');
INSERT OR IGNORE INTO users (id, name, avatar) VALUES ('mislav.abha@example.com', 'Mislav Abha', 'https://liveblocks.io/avatars/avatar-3.png');
INSERT OR IGNORE INTO users (id, name, avatar) VALUES ('tatum.paolo@example.com', 'Tatum Paolo', 'https://liveblocks.io/avatars/avatar-4.png');
INSERT OR IGNORE INTO users (id, name, avatar) VALUES ('anjali.wanda@example.com', 'Anjali Wanda', 'https://liveblocks.io/avatars/avatar-5.png');
INSERT OR IGNORE INTO users (id, name, avatar) VALUES ('emil.joyce@example.com', 'Emil Joyce', 'https://liveblocks.io/avatars/avatar-6.png');
INSERT OR IGNORE INTO memberships (user_id, organization_id, position) VALUES ('charlie.layne@example.com', 'liveblocks', 0);
INSERT OR IGNORE INTO memberships (user_id, organization_id, position) VALUES ('charlie.layne@example.com', 'charlie.layne@example.com', 1);
INSERT OR IGNORE INTO memberships (user_id, organization_id, position) VALUES ('mislav.abha@example.com', 'liveblocks', 0);
INSERT OR IGNORE INTO memberships (user_id, organization_id, position) VALUES ('mislav.abha@example.com', 'mislav.abha@example.com', 1);
INSERT OR IGNORE INTO memberships (user_id, organization_id, position) VALUES ('tatum.paolo@example.com', 'liveblocks', 0);
INSERT OR IGNORE INTO memberships (user_id, organization_id, position) VALUES ('tatum.paolo@example.com', 'tatum.paolo@example.com', 1);
INSERT OR IGNORE INTO memberships (user_id, organization_id, position) VALUES ('anjali.wanda@example.com', 'liveblocks', 0);
INSERT OR IGNORE INTO memberships (user_id, organization_id, position) VALUES ('anjali.wanda@example.com', 'anjali.wanda@example.com', 1);
INSERT OR IGNORE INTO memberships (user_id, organization_id, position) VALUES ('emil.joyce@example.com', 'liveblocks', 0);
INSERT OR IGNORE INTO memberships (user_id, organization_id, position) VALUES ('emil.joyce@example.com', 'emil.joyce@example.com', 1);
