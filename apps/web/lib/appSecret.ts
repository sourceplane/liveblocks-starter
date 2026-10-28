import { db } from "@/lib/database/db";

const cache = new Map<string, string>();

/**
 * A secret the app signs with, generated once per database by the
 * `app_secrets` migration. A Worker secret of the upper-case name wins.
 */
export async function appSecret(name: "auth"): Promise<string> {
  const fromEnv = name === "auth" ? process.env.AUTH_SECRET || process.env.NEXTAUTH_SECRET : undefined;
  if (fromEnv) return fromEnv;
  const hit = cache.get(name);
  if (hit) return hit;
  const row = await db()
    .prepare("SELECT value FROM app_secrets WHERE name = ?")
    .bind(name)
    .first<{ value: string }>();
  if (!row) {
    throw new Error(`No "${name}" secret in app_secrets: apply the migrations first`);
  }
  cache.set(name, row.value);
  return row.value;
}
