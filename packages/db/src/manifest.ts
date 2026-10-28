import type { MigrationManifest } from "./types.js";

// Every migration the runner applies, in order, with the sha256 of its file.
// `pnpm --filter @saas/db run manifest:check` verifies the checksums;
// `manifest:fix` rewrites them after a migration file changes (only ever
// before that migration has been applied anywhere — an applied migration's
// checksum is immutable).
export const manifest: MigrationManifest = {
  version: 1,
  migrations: [
    {
      id: "000_control_baseline",
      context: "control",
      path: "000_control/up.sql",
      checksum:
        "c7f11499fa82d6fd2baa1af7fc75eeb73cd7be252af2e56841509c66001d638b",
      description:
        "Baseline control migration — creates the migration tracking schema",
    },
    {
      id: "010_directory",
      context: "app",
      path: "010_directory/up.sql",
      checksum:
        "2b9f5c41fb1cd790a7def687f603be516bd23eaa2205ca4d74553cdd4977b679",
      description:
        "The directory: users, organizations and memberships (in order), which the kit kept as arrays in data/",
    },
    {
      id: "020_demo_directory",
      context: "app",
      path: "020_demo_directory/up.sql",
      checksum:
        "ae5125029ed8bfbae378e21a59543c7d1a223f1c2dd9afa80aac254c67ef5861",
      description:
        "The kit's demo users and organizations — the people its demo sign-in accepts",
    },
    {
      id: "030_app_secrets",
      context: "app",
      path: "030_app_secrets/up.sql",
      checksum:
        "9e253962cd7fa527bc310b5f701f2ee600b75ba14bfedb7b8a2da6ddb262f13a",
      description:
        "The session secret, generated once per database and never typed",
    },
  ],
};
