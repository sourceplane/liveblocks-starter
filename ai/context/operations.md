# liveblocks-starter — operating contract (for humans and agents)

This is the standing guide to how this site is deployed and operated.
Instance facts (live URLs, workspace, the secrets it uses) live in
[deployment.md](deployment.md), rendered from probed reality by the
bootstrap's `02-docs` phase; this file is the contract that stays true
between deployments. It is written to give an agent with repository read
access enough context to reason about and operate the site without any
other source.

## What this system is

Liveblocks' Next.js Starter Kit — a collaborative app: documents, notes, a
whiteboard and a canvas edited in real time, with comments, notifications,
sharing and organizations — on Cloudflare, with its realtime documents in
Liveblocks, expressed as an Orun component-native desired-state repo.

- **`infra/terraform/cloudflare-d1`** — one Cloudflare D1 database per
  deployed environment (`stage`, `prod`), applied by Terraform. After each
  apply it publishes a wiring document — `{d1_database_id, d1_database_name}`
  — as the Orun secret `WIRING_CLOUDFLARE_D1` on that environment.
- **`packages/db`** — the schema as migrations (`src/migrations/*/up.sql`,
  listed with their checksums in `src/manifest.ts`) and the runner that
  applies them to D1 over the REST API, recording each in a
  `_migrations_applied` table. `010_directory` is the directory (`users`,
  `organizations`, `memberships`), `020_demo_directory` the kit's demo users
  and organizations, `030_app_secrets` the session secret, generated once.
- **`infra/db-migrate`** — runs that runner per environment: it plans offline
  on a pull request and applies on a merge, finding the database through
  `WIRING_CLOUDFLARE_D1`.
- **`apps/web`** — the site: Next.js built (with webpack) by
  `@opennextjs/cloudflare` into one Worker plus Static Assets. Every page
  renders per request. Each document is a **Liveblocks room**: the server
  actions in `lib/actions` list, create, share and delete them through
  Liveblocks' server API, and the browser joins a room through the
  room-auth action (`authorizeLiveblocks`), which identifies the signed-in
  user and their organization. The directory is read from D1 through the
  `DB` binding (`lib/database`, server functions). Sign-in is Auth.js with
  the kit's **demo login**, its session signed with the generated secret
  (`lib/appSecret.ts`). Without `LIVEBLOCKS_SECRET_KEY` the site serves with
  a "Liveblocks is not connected" dashboard, every Liveblocks action answers
  that, and nothing calls Liveblocks (`liveblocks.server.config.ts`).
  `/api/health` counts the users table and says whether Liveblocks is
  connected.
- **`tests/web`**, **`tests/db`** — the directory, the secret, the
  not-connected client and actions and the health route over real SQLite
  with the migrations applied, and the migrations through the runner into
  real SQLite (vitest), verified on the `dev` rung.
- **`tooling/*`** — shared TypeScript and ESLint configuration, the wrangler
  renderer that turns `wrangler.template.jsonc` plus a wiring document into
  `wrangler.jsonc`, the Worker-secrets push (`tooling/wire/worker-secrets.mjs`)
  and the migration helpers (the manifest's checksum check, the local-D1
  apply).

Environments: **`stage`** and **`prod`** are deployed; **`dev` is
verify-only by design** — lanes build and test, nothing deploys, and no D1
database exists for it (its build renders the committed fixture).

## Identity and tenancy

Every remote operation runs against ONE Orun workspace, declared in
`intent.yaml` under `execution.state.workspace` — committed, enforced, and
what CI uses. Do not remove it; headless credentials depend on it. If it
reads `ws_SET_ME`, the bootstrap had no workspace to write: set the real one
before anything else.

## How deployment works

1. Merge (or push) to `main`.
2. CI (`.github/workflows/ci.yml`) runs `orun plan --changed` — only
   components whose files changed are planned — then runs each planned lane
   with `orun run --remote-state`, authenticated by GitHub OIDC (the
   exchange resolves this repository's linked workspace server-side).
3. **The database, then its schema, then the Worker**, per environment.
   `cloudflare-d1` applies and publishes `WIRING_CLOUDFLARE_D1`.
   `db-migrate` declares an enforced `dependsOn` on it for pushes to `main`,
   so it starts after that apply — a job resolves its secrets when it
   starts, so the document is there — and applies every pending migration.
   `apps/web` waits on both the same way.
4. `apps/web` renders `wrangler.jsonc` from that document (the real
   database id), builds once per environment with no Liveblocks key in its
   environment, hands the environment's Liveblocks keys (when it has them)
   to the Worker as Worker secrets, `wrangler deploy` ships
   `liveblocks-starter-web-<env>`, and a smoke test requires `/` to render to its
   end and `/api/health` to answer `"ok":true` — which only a Worker that
   read the migrated `users` table can.
5. `prod` deploys after `stage` has converged on the same commit
   (`environments.prod.promotion` in intent.yaml).
6. **The convergence run is the deployment.** A green run means every
   planned lane applied. Failed lanes are retried with
   `gh run rerun --failed`, which resumes the same execution.

On a pull request nothing applies or deploys: the D1 root plans, the
migrations plan offline (their checksums verified), the site builds and
dry-deploys, and the edges in step 3 are advisory.

Caveats that matter:

- A push that touches no component files plans zero lanes — that run is
  green and deployed nothing. Never treat "latest run green" as "site
  converged"; probe the URLs instead.
- A change to `intent.yaml`'s `environments` maps to no component and
  redeploys nothing on its own. Land it with a change under `apps/web`.
- `wrangler.jsonc` is generated. Edit `wrangler.template.jsonc`, run
  `pnpm run wire:fixture` and commit both; the deploy renders its own
  config from the template, so a stale committed render misleads local work.
- An applied migration is immutable: its checksum is recorded, and the
  runner refuses to run while a file no longer matches it. Change the
  schema with a NEW migration.

## Secrets model

- **Brokered provider secrets**, minted per run from the workspace's
  Cloudflare connection — no long-lived values at rest, nothing to rotate by
  hand:
  - `CLOUDFLARE_API_TOKEN` (`workers-deploy`: Workers Scripts) — the site's
    deploy;
  - `CLOUDFLARE_D1_TOKEN` (`d1-edit`: D1) — the D1 root's apply and the
    migration runner, which bind it as their `CLOUDFLARE_API_TOKEN`; the
    deploy token cannot touch D1;
  - `CLOUDFLARE_ACCOUNT_ID` — a connection fact all three bind.
- **Wiring**: `WIRING_CLOUDFLARE_D1` on `stage` and `prod`, written by the
  D1 root's apply (lease-published), read by the migration runner and by the
  Worker's build as `WIRING_CLOUDFLARE_D1_<ENV>`. It holds ids, not
  credentials.
- Inspect by NAME only: `orun secrets list --org <ws> --project` and
  `--env stage|prod`. No tooling in this repository prints a secret value,
  and no document in `ai/context/` may contain one.
- **The product's own secrets** (optional, best-effort: a key nobody has
  stored is skipped and the site serves without it):
  `LIVEBLOCKS_SECRET_KEY` (the Liveblocks project's secret key) and
  `LIVEBLOCKS_WEBHOOK_SECRET_KEY` (its webhook's signing secret), per
  environment — `orun secrets set LIVEBLOCKS_SECRET_KEY --env <env>`, then
  redeploy. The deploy pushes them to the Worker with `wrangler secret
  bulk` and deletes none: a key you remove from Orun stays on the Worker
  until `wrangler secret delete`.
- **The session secret** is generated once per database by `030_app_secrets`
  (table `app_secrets`) and read by the Worker from D1; an `AUTH_SECRET`
  Worker secret wins. Rotating it signs everyone out.

## Verifying the system

```bash
# the site on each environment (also recorded, probed, in deployment.md);
# the health route reads D1 and says whether Liveblocks is connected
curl -s https://liveblocks-starter-web-stage.your-workers-subdomain.workers.dev/api/health
curl -s -o /dev/null -w '%{http_code}\n' https://liveblocks-starter-web-prod.your-workers-subdomain.workers.dev/

# the wiring the migrations and deploys read, and workspace readiness
orun secrets list --org <ws> --env stage && orun secrets list --org <ws> --env prod
orun integrations list --org <ws> --json && orun cloud check --org <ws>
```

## Common operations

| task | how |
|---|---|
| change the site | edit `apps/web/` (its name and source link: `apps/web/lib/site.ts`), merge |
| connect Liveblocks | create a project, `orun secrets set LIVEBLOCKS_SECRET_KEY --env stage` (and `prod`), redeploy — README, "Connecting Liveblocks" |
| email notifications | a webhook in the Liveblocks project to `/api/notifications/email`, its secret as `LIVEBLOCKS_WEBHOOK_SECRET_KEY`, redeploy; the handlers prepare the emails, sending them is yours to add |
| add or change users and organizations | a NEW migration that inserts or updates `users`, `organizations`, `memberships` (a user's first membership, by `position`, is where they land) |
| replace the demo login | a real Auth.js provider in `apps/web/auth.config.ts`, then the users it signs in in the directory |
| change the schema | add `packages/db/src/migrations/<NNN>_<name>/up.sql` (idempotent: `IF NOT EXISTS`), list it in `src/manifest.ts`, `pnpm --filter @saas/db run manifest:fix`, merge — db-migrate applies it before the site redeploys |
| try the schema locally | `pnpm --filter @app/web db:migrate:local` applies every migration to wrangler's local D1 |
| deploy a change | merge to `main`; watch the run; failed lanes → `gh run rerun --failed` |
| deploy by hand | Orunbase's Deploy button, or `gh workflow run ci.yml --ref main -f environment=<env> [-f component=<a,b>]` — the named components (blank: every one) run in that environment as a merge runs them; started off `main` it is refused |
| redeploy without a change | edit the last line of `apps/web/component.yaml` (`# orun: redeploy <reason> <stamp>`) and merge — it is a deploy trigger, nothing reads it |
| query a live database | `wrangler d1 execute <name> --remote --command "SELECT id, name FROM users"` (the name is in the environment's `WIRING_CLOUDFLARE_D1`) |
| add a binding (R2, KV, another D1) | a Terraform root under `infra/terraform/` that publishes `WIRING_<ROOT>`, a token in `wrangler.template.jsonc`, its fixture entry, the root in the build's `--components`, the `WIRING_<ROOT>_<ENV>` secretEnv and an enforced `dependsOn` on it in `apps/web/component.yaml` |
| serve a custom domain | attach it to the Worker in Cloudflare (README, "Custom domain"), then replace the placeholder `liveblocks-starter.example.com` in `intent.yaml`'s `BASE_DOMAIN` with it |
| add a runtime secret | `orun secrets set <KEY> --org <ws> --env <env>` |
| headless credentials | `ORUN_TOKEN` (workspace-scoped) + `GITHUB_TOKEN` |

The deployment record is the bootstrap's `02-docs` phase. Re-running it (the
Orun console's Retry on that phase, or `orun new … --phase 02-docs`)
re-probes the URLs and re-renders [deployment.md](deployment.md); it is
idempotent.

## Evolution

D1 has no interactive transactions and caps a database's size; the
directory needs neither — the documents themselves are Liveblocks'. Structural changes follow the same contract that deployed the
site: add a component under `apps/`, `infra/` or `packages/` with a
`component.yaml`, land it as a pull request, and the convergence run applies
it.
