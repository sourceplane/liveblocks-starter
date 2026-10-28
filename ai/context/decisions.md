# liveblocks-starter — decisions

The choices that shape this repository, one line each, with where the full
reasoning lives. Superseded decisions stay listed, marked, so the history
reads in order.

| # | Decision | Why | Source |
|---|---|---|---|
| 1 | The directory (users, organizations, memberships) is D1 tables, the kit's demo rows a migration; `lib/database` keeps its four functions, signatures and semantics | The kit's "database" was arrays in its source, behind exactly that seam; a product needs a directory it can change without a deploy | design.md §3 |
| 2 | `lib/database`'s files are server functions (`"use server"`) | The kit's client provider resolves users in the browser; the data lived in the bundle, and D1 is server-side | design.md §3, risk LB-E |
| 3 | The session secret is generated once per database (`030_app_secrets`); an `AUTH_SECRET` Worker secret wins | The kit fell back to a secret written in its source; nothing is typed at build | design.md §4 |
| 4 | Liveblocks is optional: without `LIVEBLOCKS_SECRET_KEY` the client is a stub that refuses every call, the actions answer "not connected" and the dashboard says how to connect | A fresh product deploys and serves before its owner has a Liveblocks project; no request goes out with no key | design.md §5 |
| 5 | Liveblocks' keys are optional Orun secrets, kept out of the build (`env -u`) and handed to the Worker as Worker secrets (`tooling/wire/worker-secrets.mjs`) | They are read at request time; no bundle, build cache or log holds them | design.md §5 |
| 6 | `next build --webpack` | Turbopack's Worker is 3.08 MiB gzipped, over Workers Free's 3 MiB; webpack's is 2.3 MiB | spike notes, risk LB-C |
| 7 | The NextAuth route runs on the Node.js runtime (the kit's `runtime = "edge"`, marked optional, removed) | OpenNext answers 500 on that route under the Edge runtime | IMPLEMENTATION-STATUS |
| 8 | The schema is migrations (`packages/db`), applied by `infra/db-migrate` between the D1 apply and the Worker's deploy | The convergence's order then includes the schema | design.md §6 |
| 9 | `wrangler.jsonc` is rendered from the D1 root's wiring document per environment, and the fixture render is committed; dev renders the fixture | The deploy lane checks the config exists before the build; no root applies in dev | design.md §6 |
| 10 | One landing (`01-product`) then the record (`02-docs`); edges `mode: enforced` on main, advisory on a pull request | The plan, not a landing boundary, orders the database, its schema and the Worker | design.md §6 |
| 11 | The D1 apply and the migrations use their own `d1-edit` key (`CLOUDFLARE_D1_TOKEN`) | The `workers-deploy` token cannot touch D1 | design.md §6 |
| 12 | The smoke requires `</html>` on `/` and `"ok":true` from `/api/health` | Only a Worker that read its migrated database answers the health route; read-only, and true with or without Liveblocks | IMPLEMENTATION-STATUS |
| 13 | The migrations package is named `@saas/db` | stack-tectonic's db-migrate composition builds `--filter=@saas/db` | turso-starter's shape |
| 14 | Component docs are generated from the manifests and checked in CI | A hand-written copy of the dependency graph, bindings and migrations drifts silently | `tooling/catalog/gen-component-docs.py` |
