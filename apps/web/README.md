# apps/web — the site

Liveblocks' Next.js Starter Kit (in
[liveblocks/liveblocks](https://github.com/liveblocks/liveblocks/tree/main/starter-kits/nextjs-starter-kit),
Apache-2.0 — `LICENSE.md`), running on Cloudflare Workers + Static Assets:

- Four kinds of collaborative document — rich text (Tiptap), notes
  (BlockNote), a whiteboard and a tldraw canvas — edited together in real
  time, with comments, mentions, notifications and sharing; each document is
  a Liveblocks room
- The dashboard lists a user's documents across their organizations; the
  server actions in `lib/actions` create, share, rename and delete them
  through Liveblocks' server API (`liveblocks.server.config.ts`)
- The directory — users, organizations, memberships — is in Cloudflare D1:
  `lib/database` keeps the kit's four functions and their signatures, as
  server functions that read the `DB` binding; the tables and the kit's demo
  users are migrations in `packages/db`
- Auth.js with the kit's demo login (pick a user, no password), its session
  signed with a secret generated in D1 (`lib/appSecret.ts`)
- Without `LIVEBLOCKS_SECRET_KEY` the site still builds and serves: the
  dashboard says Liveblocks is not connected and nothing calls Liveblocks

The site's name and the repository it links to are in `lib/site.ts`.

```bash
pnpm run wire:fixture      # wrangler.jsonc from the template, placeholder database ids
pnpm db:migrate:local      # the migrations, applied to wrangler's local D1
pnpm dev                   # next dev on http://localhost:3000, the local D1 through wrangler
pnpm build                 # next build --webpack + opennextjs-cloudflare build → .open-next/
pnpm preview               # wrangler dev over the built Worker, the same local D1
```

For realtime locally, put your Liveblocks project's secret key in `.dev.vars`
(`LIVEBLOCKS_SECRET_KEY=sk_dev_…`) — never commit it. How it is deployed —
the database from `infra/terraform/cloudflare-d1`, its schema from
`infra/db-migrate`, its id rendered into `wrangler.jsonc` per environment,
Liveblocks' keys handed to the Worker as Worker secrets, on merge to `main` —
is the repository's README and `component.yaml` beside this file.
