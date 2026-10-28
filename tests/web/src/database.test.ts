import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import * as path from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

// apps/web/lib/database over a real SQLite database (node:sqlite — D1's
// engine) with packages/db's migrations applied: the directory the kit kept
// as arrays in data/, read through the same four functions and signatures.
type Row = Record<string, unknown>;
interface Sqlite {
  exec(sql: string): void;
  prepare(sql: string): { all(...params: unknown[]): Row[] };
}
const { DatabaseSync } = createRequire(import.meta.url)("node:sqlite") as {
  DatabaseSync: new (file: string) => Sqlite;
};
const migrationsDir = path.resolve(__dirname, "../../../packages/db/src/migrations");
const MIGRATIONS = ["010_directory", "020_demo_directory", "030_app_secrets"];

let sqlite: Sqlite;
// The D1 binding's shape (prepare → bind → first/all) over that database.
function d1(db: Sqlite) {
  const statement = (sql: string, params: unknown[] = []) => ({
    bind: (...values: unknown[]) => statement(sql, values),
    async first<T>() {
      return (db.prepare(sql).all(...params)[0] as T | undefined) ?? null;
    },
    async all<T>() {
      return { results: db.prepare(sql).all(...params).map((r) => ({ ...r })) as T[] };
    },
  });
  return { prepare: (sql: string) => statement(sql) };
}
vi.mock("@opennextjs/cloudflare", () => ({
  getCloudflareContext: vi.fn(() => ({ env: { DB: d1(sqlite) } })),
}));
// Auth.js itself is not under test here (and does not load outside Next):
// the session reader and the provider list liveblocks.server.config reads.
const auth = vi.fn(async () => null);
vi.mock("@/auth", () => ({ auth, getProviders: () => ({ credentials: "Credentials" }) }));

function migrate(db: Sqlite, names = MIGRATIONS) {
  for (const name of names) db.exec(readFileSync(path.join(migrationsDir, name, "up.sql"), "utf8"));
}

const saved = { ...process.env };
beforeEach(() => {
  sqlite = new DatabaseSync(":memory:");
  migrate(sqlite);
  vi.resetModules();
  delete process.env.AUTH_SECRET;
  delete process.env.NEXTAUTH_SECRET;
  delete process.env.LIVEBLOCKS_SECRET_KEY;
  delete process.env.LIVEBLOCKS_BASE_URL;
});
afterEach(() => {
  process.env = { ...saved };
  vi.unstubAllGlobals();
});

describe("lib/database on D1", () => {
  it("reads a user with their organizations in order, and a colour seeded from their id", async () => {
    const { getUser } = await import("@/lib/database");
    const user = await getUser("charlie.layne@example.com");
    expect(user).toEqual({
      color: expect.stringMatching(/^#[0-9a-f]{6}$/),
      id: "charlie.layne@example.com",
      name: "Charlie Layne",
      avatar: "https://liveblocks.io/avatars/avatar-2.png",
      organizationIds: ["liveblocks", "charlie.layne@example.com"],
    });
    // The same user always gets the same colour (the kit's seeded pick).
    expect((await getUser("charlie.layne@example.com"))?.color).toBe(user?.color);
  });

  it("answers null for a user the directory does not hold", async () => {
    const { getUser } = await import("@/lib/database");
    expect(await getUser("nobody@example.com")).toBeNull();
  });

  it("lists every user in the directory's order, by ids (null for an unknown one), or by a search", async () => {
    const { getUsers } = await import("@/lib/database");
    expect((await getUsers()).map((u) => u?.id)).toEqual([
      "charlie.layne@example.com",
      "mislav.abha@example.com",
      "tatum.paolo@example.com",
      "anjali.wanda@example.com",
      "emil.joyce@example.com",
    ]);
    expect((await getUsers({ userIds: ["emil.joyce@example.com", "nobody@example.com"] })).map((u) => u?.id ?? null)).toEqual([
      "emil.joyce@example.com",
      null,
    ]);
    expect((await getUsers({ search: "TAT" })).map((u) => u?.id)).toEqual(["tatum.paolo@example.com"]);
  });

  it("reads an organization, and a user's organizations in their order", async () => {
    const { getOrganization, getUserOrganizations } = await import("@/lib/database");
    expect(await getOrganization("liveblocks")).toEqual({ id: "liveblocks", name: "Liveblocks", avatar: "/liveblocks.png" });
    expect(await getOrganization("nope")).toBeNull();
    expect((await getUserOrganizations({ userId: "anjali.wanda@example.com" })).map((o) => o.name)).toEqual([
      "Liveblocks",
      "Anjali's space",
    ]);
    expect(await getUserOrganizations({ userId: "nobody@example.com" })).toEqual([]);
  });

  it("follows a membership the owner adds", async () => {
    sqlite.prepare("INSERT INTO memberships (user_id, organization_id, position) VALUES (?, ?, ?)").all(
      "emil.joyce@example.com",
      "anjali.wanda@example.com",
      2,
    );
    const { getUser } = await import("@/lib/database");
    expect((await getUser("emil.joyce@example.com"))?.organizationIds).toEqual([
      "liveblocks",
      "emil.joyce@example.com",
      "anjali.wanda@example.com",
    ]);
  });

  it("runs on the server only: every file is a server function module", () => {
    for (const file of ["getUser", "getUsers", "getOrganization", "getUserOrganizations"]) {
      const source = readFileSync(path.resolve(__dirname, `../../../apps/web/lib/database/${file}.ts`), "utf8");
      expect(source.startsWith('"use server";'), file).toBe(true);
    }
  });
});

describe("the session secret (lib/appSecret)", () => {
  it("is the one the migration generated, read once", async () => {
    const { appSecret } = await import("@/lib/appSecret");
    const stored = String(sqlite.prepare("SELECT value FROM app_secrets WHERE name = 'auth'").all()[0]?.value);
    expect(await appSecret("auth")).toBe(stored);
    sqlite.prepare("UPDATE app_secrets SET value = 'changed' WHERE name = 'auth'").all();
    expect(await appSecret("auth")).toBe(stored);
  });

  it("is an AUTH_SECRET Worker secret when one is set", async () => {
    process.env.AUTH_SECRET = "from-the-worker";
    const { appSecret } = await import("@/lib/appSecret");
    expect(await appSecret("auth")).toBe("from-the-worker");
  });

  it("says to apply the migrations when the database has none", async () => {
    sqlite = new DatabaseSync(":memory:");
    migrate(sqlite, ["010_directory"]);
    sqlite.exec("CREATE TABLE app_secrets (name TEXT PRIMARY KEY, value TEXT NOT NULL)");
    const { appSecret } = await import("@/lib/appSecret");
    await expect(appSecret("auth")).rejects.toThrow(/apply the migrations/);
  });

  it("is never written in the source any more (the kit's fallback secret is gone)", () => {
    const auth = readFileSync(path.resolve(__dirname, "../../../apps/web/auth.ts"), "utf8");
    expect(auth).not.toMatch(/NEXTAUTH_SECRET \|\|/);
    expect(auth).toContain('secret: await appSecret("auth")');
  });
});

describe("Liveblocks, connected or not (liveblocks.server.config)", () => {
  it("without a secret key: builds and loads, and every call answers 'not connected' without a request", async () => {
    const fetchSpy = vi.fn();
    vi.stubGlobal("fetch", fetchSpy);
    const mod = await import("@/liveblocks.server.config");
    expect(mod.LIVEBLOCKS_CONNECTED).toBe(false);
    await expect(mod.liveblocks.getRoom("room")).rejects.toThrow("Liveblocks is not connected");
    await expect(mod.liveblocks.getRooms({})).rejects.toThrow("Liveblocks is not connected");
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("with a secret key: a real client, pointed at Liveblocks unless a base URL is set", async () => {
    process.env.LIVEBLOCKS_SECRET_KEY = "sk_test_offline_fixture_not_a_key";
    process.env.LIVEBLOCKS_BASE_URL = "http://127.0.0.1:9";
    const seen: string[] = [];
    vi.stubGlobal(
      "fetch",
      vi.fn(async (input: string | URL | Request, init?: RequestInit) => {
        seen.push(`${String(input)} ${new Headers(init?.headers).get("authorization")}`);
        return new Response(JSON.stringify({ token: "id.token" }), { status: 200, headers: { "content-type": "application/json" } });
      }),
    );
    const mod = await import("@/liveblocks.server.config");
    expect(mod.LIVEBLOCKS_CONNECTED).toBe(true);
    const { status } = await mod.liveblocks.identifyUser({ userId: "u", groupIds: [] });
    expect(status).toBe(200);
    expect(seen).toEqual(["http://127.0.0.1:9/v2/identify-user Bearer sk_test_offline_fixture_not_a_key"]);
  });

  it("guards every action that reaches Liveblocks, and the webhook", () => {
    const dir = path.resolve(__dirname, "../../../apps/web/lib/actions");
    const actions = [
      "authorizeLiveblocks",
      "createDocument",
      "deleteDocument",
      "getDocument",
      "getDocumentUsers",
      "getDocuments",
      "getLiveUsers",
      "getNextDocuments",
      "removeUserAccess",
      "renameDocument",
      "updateGeneralAccess",
      "updateUserAccess",
    ];
    for (const name of actions) {
      const source = readFileSync(path.join(dir, `${name}.ts`), "utf8");
      expect(source, name).toMatch(/if \(!LIVEBLOCKS_CONNECTED\) \{\n\s+return \{ error: NOT_CONNECTED \};/);
    }
    const webhook = readFileSync(path.resolve(__dirname, "../../../apps/web/app/api/notifications/email/route.ts"), "utf8");
    expect(webhook).toMatch(/if \(!LIVEBLOCKS_CONNECTED\) \{\n\s+return new Response\(NOT_CONNECTED\.message, \{ status: 503 \}\);/);
  });

  it("answers the room-auth action with NOT_CONNECTED before it reads a session", async () => {
    auth.mockClear();
    const { authorizeLiveblocks } = await import("@/lib/actions/authorizeLiveblocks");
    const { NOT_CONNECTED } = await import("@/liveblocks.server.config");
    expect(await authorizeLiveblocks("room")).toEqual({ error: NOT_CONNECTED });
    expect(auth).not.toHaveBeenCalled();
  });
});

describe("/api/health (the deploy's smoke)", () => {
  it("counts the directory through the DB binding and says whether Liveblocks is connected", async () => {
    const { GET } = await import("@/app/api/health/route");
    expect(await (await GET()).json()).toEqual({ ok: true, users: 5, liveblocks: "not-connected" });
    process.env.LIVEBLOCKS_SECRET_KEY = "sk_test_offline_fixture_not_a_key";
    vi.resetModules();
    const again = await import("@/app/api/health/route");
    expect(await (await again.GET()).json()).toEqual({ ok: true, users: 5, liveblocks: "connected" });
  });

  it("fails when the migrations have not run", async () => {
    sqlite = new DatabaseSync(":memory:");
    const { GET } = await import("@/app/api/health/route");
    await expect(GET()).rejects.toThrow(/no such table: users/);
  });
});
