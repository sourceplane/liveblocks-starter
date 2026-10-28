# liveblocks-starter

Liveblocks' [Next.js Starter Kit](https://liveblocks.io/docs/guides/nextjs-starter-kit)
— Vercel's Liveblocks Starter Kit template: rich-text documents, notes, a
whiteboard and a canvas edited together in real time, with comments,
mentions, notifications, sharing and organizations — running on **Cloudflare
Workers + Static Assets** through
[`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare). The realtime
documents are **[Liveblocks](https://liveblocks.io)** rooms, in a project the
owner connects after the build; the directory the kit kept as arrays in its
source (users, organizations, memberships) and the session secret are in a
**Cloudflare D1** database provisioned by Terraform through
[Orun](https://github.com/sourceplane/orun), its schema applied by
migrations, deployed by
[Orun](https://github.com/sourceplane/orun) to stage and prod on every merge.
Packaging it as an Orun baseline is the next milestone (LB2).

The kit's `lib/database` functions keep their signatures and semantics; they
read D1 now, as server functions. The site goes live with no Liveblocks
project: the marketing page and the demo sign-in work, and the dashboard says
how to connect one. See
[`specs/epics/liveblocks-starter`](specs/epics/liveblocks-starter/README.md) for the
design, the milestones and the as-built status.

## What is here (the product)

| Surface | Where |
|---|---|
| The pages: marketing, sign-in, the dashboard, the four document kinds | `apps/web/app` |
| The editors, the whiteboard, the canvas, comments and the inbox | `apps/web/components` |
| The server actions (documents, sharing, organizations, the room auth) | `apps/web/lib/actions` |
| The directory on D1, the generated session secret | `apps/web/lib/database`, `apps/web/lib/appSecret.ts` |
| Liveblocks' server client, and the "not connected" state | `apps/web/liveblocks.server.config.ts` |
| The site's name and source link | `apps/web/lib/site.ts` |
| The health route the deploy smoke-tests | `apps/web/app/api/health/route.ts` |
| Workers build, bindings and deploy contract | `apps/web/next.config.mjs`, `open-next.config.ts`, `wrangler.template.jsonc` + `wiring.fixture.json` (→ the committed `wrangler.jsonc`), `component.yaml` |
| The D1 database (stage, prod) | `infra/terraform/cloudflare-d1` |
| The schema (migrations) and the runner that applies them over the D1 REST API | `packages/db`, run by `infra/db-migrate` |
| The wrangler renderer, Liveblocks' keys to the Worker, the migration helpers | `tooling/wire`, `tooling/migrations` |
| Tests | `tests/web` (the directory on real SQLite with the migrations applied, the secret, the not-connected client and actions, the health route, the secrets push), `tests/db` (the migrations through the runner, into real SQLite) |

## Getting started

```bash
pnpm install
pnpm run wire:fixture   # render apps/web/wrangler.jsonc from the offline fixture
pnpm typecheck
pnpm lint
pnpm test
pnpm build              # next build --webpack + opennextjs-cloudflare build → apps/web/.open-next
```

```bash
pnpm --filter @app/web db:migrate:local   # the directory, the demo users and the secret in wrangler's local D1
pnpm --filter @app/web dev                # http://localhost:3000 — the local D1 through wrangler's platform proxy
pnpm --filter @app/web preview            # wrangler dev over the built Worker, same local D1
```

## How it maps to Vercel

| Vercel-side | Here |
|---|---|
| Next.js hosting, server actions | One Cloudflare Worker (`.open-next/worker.js`) + Static Assets, built with webpack (Turbopack's Worker is over Workers Free's 3 MiB) |
| The kit in the liveblocks/liveblocks monorepo, npm | Its own pnpm workspace; three packages it imported without declaring (`@tiptap/extension-link`, `@tiptap/extension-list`, `prosemirror-view`) and `@tiptap/core` declared at npm's locked versions |
| `data/users.ts`, `data/organizations.ts` (arrays in the source) | D1 tables `users`, `organizations`, `memberships` (`010_directory`), the kit's demo rows as `020_demo_directory`; `lib/database`'s functions read them as server functions |
| `NEXTAUTH_SECRET` or a fallback written in `auth.ts` | A secret generated once per database (`030_app_secrets`); an `AUTH_SECRET` Worker secret wins |
| `LIVEBLOCKS_SECRET_KEY` in `.env.local` (required — the kit threw without it) | The product's optional Orun secret, handed to the Worker as a Worker secret on deploy; without it the site serves with a "Liveblocks is not connected" dashboard |
| `LIVEBLOCKS_WEBHOOK_SECRET_KEY` | The same, optional |
| The NextAuth route on the Edge runtime (`runtime = "edge"`, "optional") | The Node.js runtime: OpenNext serves the route there |
| Deploy on push | Orun applies the database, migrates it and deploys `<repo>-web-{stage,prod}` on merge to `main` |
| "Deploy with Vercel" (clone the template) | `orun new --blueprint repo-blueprint.yaml` — a new repository, branded, deployed |

## How the database reaches the Worker

```
infra/terraform/cloudflare-d1 ──apply──► orun secret WIRING_CLOUDFLARE_D1 (stage, prod)
                                               │   (the landing's await checks it exists)
                                               ▼
infra/db-migrate  dependsOn cloudflare-d1 (enforced on main) · secretEnv WIRING_CLOUDFLARE_D1
  apply:  packages/db's runner → POST …/d1/database/<id>/query, each pending migration once
                                               ▼
apps/web  dependsOn cloudflare-d1 + db-migrate (enforced on main) · secretEnv WIRING_CLOUDFLARE_D1_<ENV>
  build:  tooling/wire/live.mjs → wrangler.jsonc with the environment's database id
          (dev, verify-only, renders the fixture) → next build --webpack → opennextjs-cloudflare
          → tooling/wire/worker-secrets.mjs: Liveblocks' keys, when the environment has them,
            to the Worker as Worker secrets
```

`wrangler.jsonc` is committed as the fixture render of
`wrangler.template.jsonc`, because the deploy lane's `verify-app-structure`
step checks the config exists before it builds; `testing/e2e.test.sh` fails
if the two disagree.

## CI

| Workflow | What it runs | Ships to a product |
|---|---|---|
| `ci.yml` | the Orun pipeline, and the only workflow a product carries: `orun plan --changed`, then one job per lane. A pull request runs the verify lanes (packages type-checked, linted, tested and built, both test suites, the site built and dry-deployed per environment), except the bootstrap's own landings (`orun/BASE-*`), where `plan` alone is the check; a merge applies the D1 database, migrates it, then deploys stage → prod. It plans nothing while `intent.yaml` names the placeholder workspace `ws_CHANGE_ME`, as this repository does. A manual run (Orunbase's Deploy button, or Run workflow on `main`) plans the environment and components it names under the push-to-main trigger, so they deploy as a merge deploys them | yes |
