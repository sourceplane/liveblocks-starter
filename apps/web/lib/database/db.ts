import { getCloudflareContext } from "@opennextjs/cloudflare";

/**
 * The D1 database bound as `DB` (wrangler.jsonc): the users, organizations
 * and memberships the app reads through lib/database, and its generated
 * secrets. `next dev` reaches wrangler's local D1 through the platform proxy.
 */
export function db(): D1Database {
  return getCloudflareContext().env.DB;
}
