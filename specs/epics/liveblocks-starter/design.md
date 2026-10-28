# liveblocks-starter — design

## 1. The kit

Liveblocks' Next.js Starter Kit (Vercel lists it as the Liveblocks Starter
Kit) is a Next.js 16 app: a marketing page, a sign-in, a dashboard of
documents across a user's organizations, and four kinds of collaborative
document — rich text (Tiptap), notes (BlockNote), a whiteboard and a tldraw
canvas — with presence, comments, mentions, an inbox of notifications,
sharing and an email webhook. Each document is a **Liveblocks room**: the
server actions in `lib/actions` list, create, share, rename and delete rooms
through `@liveblocks/node`, and the browser joins a room through a server
action (`authorizeLiveblocks`) that identifies the signed-in user, their
organization (a Liveblocks group) and their name, colour and avatar. Sign-in
is Auth.js with a Credentials provider — a demo login — and the users and
organizations are arrays in `data/`, behind four functions in
`lib/database/` that "simulate calling your database".

## 2. How each piece maps

| Vercel-side | Here |
|---|---|
| Next.js hosting, server actions | `@opennextjs/cloudflare` → one Worker + Static Assets, built with webpack |
| The kit inside the liveblocks/liveblocks monorepo, npm | its own pnpm workspace (turso-starter's shape); `pnpm import` of npm's lockfile showed the three undeclared imports npm's hoisting hid |
| `data/users.ts`, `data/organizations.ts` | D1: `users`, `organizations`, `memberships(user_id, organization_id, position)` |
| `NEXTAUTH_SECRET` or a secret written in `auth.ts` | generated once per database (`app_secrets`) |
| `LIVEBLOCKS_SECRET_KEY` required at import | an optional Orun secret, a Worker secret at request time |
| The NextAuth route on the Edge runtime | the Node.js runtime |
| `next/image` against liveblocks.io | `images.unoptimized` — Workers runs no optimizer |

## 3. The directory on D1

The four functions keep their names, arguments and results, so nothing else
in the kit changes: `getUser(id)` returns the user with their
`organizationIds` in order and a colour seeded from their id, or `null`;
`getUsers({ userIds, search })` keeps a `null` for an unknown id and filters
by name or id; `getOrganization(id)`, `getUserOrganizations({ userId })`.
They read the `DB` binding (`getCloudflareContext`) and are **server
functions** (`"use server"`): the kit's client provider resolves user ids in
the browser (`resolveUsers`), which worked only because the arrays were in
the bundle. `position` keeps a user's organizations in order — the first is
where they land. The schema is `010_directory`; the kit's demo users and
organizations are `020_demo_directory` (INSERT OR IGNORE, generated from the
kit's own files, so an owner's change is never overwritten). The sign-in
page's picker reads the same directory.

## 4. The session secret

Auth.js is configured lazily (`NextAuth(async () => ({ secret: … }))`), so
the secret is read per request: an `AUTH_SECRET` (or `NEXTAUTH_SECRET`)
Worker secret if one is set, else the 32 random bytes `030_app_secrets`
generated in the database once. Nothing is typed at build, and the kit's
fallback secret written in its source is gone.

## 5. Liveblocks optional

`liveblocks.server.config.ts` threw at import without a key, and the email
route built its own client that threw at **build** without one. Now:
`LIVEBLOCKS_CONNECTED` is whether the key is set; without it `liveblocks` is
a stub whose every method rejects with "Liveblocks is not connected", every
server action that reaches Liveblocks answers `{ error: NOT_CONNECTED }`
before it does anything (the kit's own error shape), the room-auth action
does so before it reads a session, the webhook answers 503, and the
dashboard renders a notice saying how to connect a project. So a fresh
product builds, deploys and passes its smoke with no Liveblocks project, and
no request ever leaves with no key.

The keys — the project's secret key and the webhook's signing secret — are
the product's optional Orun secrets (`optionalSecretEnv`, best-effort). The
build runs without them (`env -u`), and `tooling/wire/worker-secrets.mjs`
hands the ones the environment has to the Worker with `wrangler secret
bulk`, as clerk-auth-starter does with Clerk's. The browser needs no key: it
authenticates through the room-auth action. `LIVEBLOCKS_BASE_URL` (unset in
a product) points the client at a stand-in for the offline tests.

## 6. The repository and the build

turso-starter's shape: `apps/web` (`cloudflare-workers-assets-turbo`),
`infra/terraform/cloudflare-d1`, `packages/db` + `infra/db-migrate`,
`tests/web`, `tests/db`. Per environment, on a merge: the D1 apply publishes
`WIRING_CLOUDFLARE_D1`, db-migrate applies the migrations, and the site
renders `wrangler.jsonc` from that document, builds, pushes Liveblocks' keys
to the Worker and deploys; `dev` only verifies. The smoke requires `/` to
render to its end and `/api/health` to answer `"ok":true` — the route counts
the users table, so only a Worker that read its migrated database passes,
with or without Liveblocks. One landing (`01-product`), then the record
(`02-docs`), which probes `/api/health` and says whether Liveblocks is
connected.

`next build --webpack`: Turbopack's Worker is 3.08 MiB gzipped, over Workers
Free's 3 MiB; webpack's is 2.3 MiB (spike notes).

## 7. Alternatives rejected

- **Keep the directory in the source.** A product could not add a user
  without a deploy, and the arrays shipped in the browser bundle.
- **A Liveblocks key at build, inlined.** The kit needs none in the browser;
  the key belongs at request time, out of every bundle.
- **Turn Liveblocks off by a build flag.** The connection is the Worker's
  secret; reading it at request time means storing a key and redeploying is
  enough, with nothing rebuilt differently.
- **Replace the demo login now.** The kit is a starter; its login is its
  demo, and the README says to replace it before real use (risk LB-D).
