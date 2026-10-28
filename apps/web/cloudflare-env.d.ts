// The bindings wrangler.jsonc declares, as the Worker (and `next dev` through
// the platform proxy) sees them.
interface CloudflareEnv {
  DB: D1Database;
  ASSETS: Fetcher;
}
