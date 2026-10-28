# liveblocks-starter — implementation plan

## LB0 — the spec (LB-1)

The repository is born with turso-starter's intent, CI, tooling and spec
index, renamed; this doc set and the three task contracts land on top.

## LB1 — the collaborative app on Workers and D1 (LB-2)

1. The kit (at `4786148`) into `apps/web`, its own pnpm workspace; the
   undeclared imports declared at npm's locked versions.
2. OpenNext: standalone output, the static-assets incremental cache,
   `images.unoptimized`, webpack; the NextAuth route on the Node.js runtime.
3. The directory as `packages/db` migrations (`010_directory`,
   `020_demo_directory` from the kit's own data, `030_app_secrets`);
   `lib/database` on D1 as server functions, the sign-in picker from D1.
4. The session secret from D1, Auth.js configured lazily.
5. Liveblocks optional: the stub client, the guard on every Liveblocks
   action and the webhook, the dashboard's notice; the keys as optional
   Orun secrets pushed to the Worker; `/api/health`.
6. Tests: `tests/web` (the directory over real SQLite with the migrations,
   the secret, Liveblocks not connected and connected, the health route, the
   secrets push), `tests/db` (the migrations through the runner).
7. The README: how it runs, connects Liveblocks, deploys, maps to Vercel.

## LB2 — a baseline (LB-3)

The card (one Cloudflare provider; Liveblocks connected after the build),
the build document (one landing, then the record), the identity and the
rename seam (`SITE_NAME`), the context pack, the deployment record probing
`/api/health`, and the baseline's tests: contract tiers, generated component
docs, the leak gate (the kit's licence and the new runtime files must ship),
placement (the optional Liveblocks refs, the keys kept out of the build),
the offline bootstrap, and the e2e — the stage lanes in staged job trees,
the migrations against a stand-in D1 API, the Worker served with no
Liveblocks project and against a stand-in Liveblocks API that refuses any
key but the project's. Then `baseline-v1`.
