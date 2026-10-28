# liveblocks-starter

Liveblocks' [Next.js Starter Kit](https://liveblocks.io/docs/guides/nextjs-starter-kit)
— a collaborative app: rich-text documents, notes, a whiteboard and a canvas
edited together in real time, with comments, mentions, notifications,
sharing and organizations — on **Cloudflare Workers + Static Assets**
through [`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare). The
realtime documents live in **[Liveblocks](https://liveblocks.io)** (a
project you connect after the build); the directory — users, organizations
and who belongs to which — and the session secret live in a **Cloudflare
D1** database that Terraform provisions per environment, its schema applied
by migrations before every deploy.

## Live deployment

<!-- 02-docs:begin -->
Not recorded yet. The bootstrap's last phase writes the live URLs, the
workspace, whether Liveblocks is connected and the secrets the site uses
into [ai/context/deployment.md](ai/context/deployment.md); how the site
deploys and how to operate it is in
[ai/context/operations.md](ai/context/operations.md).
<!-- 02-docs:end -->

## Connecting Liveblocks

The site deploys and serves before any Liveblocks project exists: the
marketing page and the sign-in work, and the dashboard says "Liveblocks is
not connected". To connect one:

1. **Create a project** at [liveblocks.io](https://liveblocks.io/dashboard)
   and copy its **secret key** (`sk_…`) from its API keys page. A
   development key works on the site's workers.dev URLs as they are.
2. **Give the site its key**, once per deployed environment. It is this
   repository's Orun secret, and stage and prod can each name their own
   project:

   ```bash
   orun secrets set LIVEBLOCKS_SECRET_KEY --env stage   # prompts for the value
   orun secrets set LIVEBLOCKS_SECRET_KEY --env prod
   ```

   The build never sees it; the deploy hands it to the Worker as a Worker
   secret (`wrangler secret bulk`), so it is in no bundle, no build cache and
   no log. The browser needs no key of its own: it authenticates to a room
   through the site's room-auth action.
3. **Redeploy the site**: a secret reaches the Worker when the site deploys,
   and setting one deploys nothing. Use **Deploy by hand** below, or change
   the stamp on the last line of `apps/web/component.yaml`
   (`# orun: redeploy …`) and merge. From that deploy on, the dashboard lists
   your documents and `/api/health` reports `"liveblocks":"connected"`.

Email notifications (`/api/notifications/email`) take a webhook: add one in
the Liveblocks project pointing at `https://<the site>/api/notifications/email`,
and store its signing secret (`whsec_…`) as `LIVEBLOCKS_WEBHOOK_SECRET_KEY`
the same way (`orun secrets set LIVEBLOCKS_WEBHOOK_SECRET_KEY --env stage`,
then prod), and redeploy. Unsigned deliveries are refused. The handlers prepare the emails; sending them is yours to add
(`app/api/notifications/email/*.tsx` show where).

## Signing in

The kit's sign-in is a **demo login**: pick one of the directory's users
and you are signed in as them — no password. The users and organizations
are the kit's demo ones, seeded by the `020_demo_directory` migration. Before
real people use the site, replace the Credentials provider in
`apps/web/auth.config.ts` with a real one (Auth.js providers: GitHub, Auth0,
…) and add your users with a new migration. The session cookie is signed with
a secret generated once per database (`030_app_secrets`); an `AUTH_SECRET`
Worker secret wins.

## What is here

| Surface | Where |
|---|---|
| The pages: marketing, sign-in, the dashboard, the four document kinds | `apps/web/app` |
| The editors, the whiteboard, the canvas, comments and the inbox | `apps/web/components` |
| The server actions (documents, sharing, organizations, the room auth) | `apps/web/lib/actions` |
| The directory on D1 (users, organizations), the generated secret | `apps/web/lib/database`, `apps/web/lib/appSecret.ts` |
| Liveblocks' server client, and the "not connected" state | `apps/web/liveblocks.server.config.ts` |
| Auth.js (the demo login) | `apps/web/auth.ts`, `apps/web/auth.config.ts` |
| The site's name and source link | `apps/web/lib/site.ts` |
| The health route the deploy smoke-tests | `apps/web/app/api/health/route.ts` |
| Workers build, bindings and deploy contract | `apps/web/next.config.mjs`, `open-next.config.ts`, `wrangler.template.jsonc` + `wiring.fixture.json` (→ `wrangler.jsonc`), `component.yaml` |
| The D1 database (stage, prod) | `infra/terraform/cloudflare-d1` |
| The schema (migrations) and their runner | `packages/db`, applied by `infra/db-migrate` |
| Handing Liveblocks' keys to the Worker | `tooling/wire/worker-secrets.mjs` |
| Tests | `tests/web`, `tests/db` (vitest) |

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

For realtime locally, put your project's secret key in `apps/web/.dev.vars`
(`LIVEBLOCKS_SECRET_KEY=sk_dev_…`, for `wrangler dev`) or `.env.local` (for
`next dev`) — never commit it.

Make the site yours in `apps/web/`, and its name and the repository it links
to in `apps/web/lib/site.ts`.

## How the database is wired

The Worker binds the database as `DB`. Its id is never hand-written:
`apps/web/wrangler.template.jsonc` names it as a wiring token, and
`wrangler.jsonc` is that template rendered — from `wiring.fixture.json`
(placeholder ids) for local work and verification, and on every deploy from
the document the `cloudflare-d1` Terraform root publishes after its apply
(`WIRING_CLOUDFLARE_D1`, per environment). Edit the template, then
`pnpm run wire:fixture` and commit the render with the template.

The schema is `packages/db`'s migrations: each
`src/migrations/<NNN>_<name>/up.sql` is listed in `src/manifest.ts` with its
checksum, and the `db-migrate` component applies the pending ones to each
environment's database before the site deploys. To change the directory, add
a migration (never edit an applied one — its checksum is recorded), then
`pnpm --filter @saas/db run manifest:fix`. Locally,
`pnpm --filter @app/web db:migrate:local` applies the same files to
wrangler's local D1.

## How it deploys

Merges to `main` converge through [Orun](https://github.com/sourceplane/orun):
`.github/workflows/ci.yml` plans the changed components and runs each lane
against the workspace in `intent.yaml`. Per environment, the D1 database
applies first, then its migrations, then the site builds with that
environment's database id, hands it Liveblocks' keys (when the environment
has them) and deploys — to `stage`, then to `prod` once stage has converged
on the same commit; `dev` only verifies. The Worker is
`liveblocks-starter-web-<env>` on your account's workers.dev subdomain, and
every deploy is smoke-tested over HTTP: the marketing page must render to its
end, and `/api/health` must answer ok — which only a Worker that read its
database can. A pull request runs the same pipeline's verify lanes: the
packages type-checked, linted, tested and built, both test suites, and the
site built and dry-deployed for each environment, with nothing deployed. (A
push to `main` applies, migrates, builds and deploys.)

The pipeline holds one credential, GitHub's own `GITHUB_TOKEN`. The
Cloudflare tokens (one to deploy, one scoped to D1) and the account id are
brokered per run from the workspace's Cloudflare connection, the database
ids travel as Orun secrets, and Liveblocks' keys are the product's own Orun
secrets; nothing provider-shaped is stored in the repository or in GitHub.

**Deploy by hand.** Orunbase's **Deploy** button on a component, or **Run
workflow** on the CI workflow in GitHub's Actions tab (on `main`), runs
`ci.yml` for the environment and components you pick, and each one deploys
exactly as a merge would deploy it. Leave the component blank to redeploy
every component in that environment, with nothing changed: after storing
Liveblocks' key, say. A component with nothing to run in that environment (a
test suite in `prod`) is left out with a notice.

## Custom domain

The site answers on workers.dev from its first deploy. To serve it on your
own domain, add the domain to the Cloudflare account the site deploys into
and attach it to the Worker (dashboard → Workers & Pages →
`liveblocks-starter-web-prod` → Settings → Domains & Routes → Add → Custom
domain). The site renders no absolute link to itself, so nothing else has to
change (point Liveblocks' webhook at the new domain); the repository names the domain in one place, `BASE_DOMAIN` in
`intent.yaml`, which the site was born with as the reserved placeholder
`liveblocks-starter.example.com`. Replace it with your domain in the same change
that records it.

## Credits

The app is Liveblocks' Next.js Starter Kit
([liveblocks/liveblocks](https://github.com/liveblocks/liveblocks), `starter-kits/nextjs-starter-kit`,
Apache-2.0 — `apps/web/LICENSE.md`). Its whiteboard canvas uses
[tldraw](https://tldraw.dev), under the tldraw license
(`apps/web/components/Canvas/LICENSE.md`), which keeps its watermark.
