# liveblocks-starter — implementation status

| Milestone | State | Landed |
|---|---|---|
| LB0 — the spec | ✅ | LB-1 |
| LB1 — the collaborative app on Workers and D1 | ✅ | LB-2 |
| LB2 — a baseline | planned | LB-3 |

## Departures from the upstream kit

Everything not listed here is the kit as it is upstream at `4786148`.

| # | What | Why |
|---|---|---|
| 1 | The app lives in `apps/web` of a pnpm workspace (`@app/web`); npm → pnpm; every dependency at npm's locked version; `@tiptap/core`, `@tiptap/extension-link`, `@tiptap/extension-list` (3.29.0) and `prosemirror-view` (1.42.0) declared | The kit imports the last three without declaring them (npm's hoisting); without `@tiptap/core` pnpm pairs `@tiptap/react` 3 with BlockNote's `@tiptap/core` 2 and the build fails |
| 2 | Next.js `^16.1.6` → `16.3.8`; `next build --webpack`; `output: "standalone"`, `images.unoptimized`, `reactStrictMode` kept | OpenNext 1.20.11's supported line; Turbopack's Worker is over Workers Free's 3 MiB |
| 3 | `app/api/auth/[...nextauth]/route.ts` without `export const runtime = "edge"` (marked "optional" upstream) | OpenNext answers 500 on that route under the Edge runtime |
| 4 | `data/users.ts`, `data/organizations.ts` → migrations `010_directory` (tables) and `020_demo_directory` (the same rows); `data/colors.ts` kept | A directory a product can change without a deploy |
| 5 | `lib/database/*`: the same four functions, signatures and results, reading D1 (`lib/database/db.ts`), as server functions | Real storage; the client provider resolves users in the browser |
| 6 | `app/signin`: the demo picker's users come from D1 through the page | `data/users.ts` is gone |
| 7 | `auth.ts`: Auth.js configured lazily, its secret from `lib/appSecret.ts` (an `AUTH_SECRET`/`NEXTAUTH_SECRET` Worker secret, else `030_app_secrets`); the fallback secret written in the source removed; a user with no organization is not switched to `undefined` | Nothing typed; a database directory can hold such a user |
| 8 | `liveblocks.server.config.ts`: no throw without a key; `LIVEBLOCKS_CONNECTED`, `NOT_CONNECTED`, a stub client when not connected; `LIVEBLOCKS_BASE_URL` (unset in a product) | A product serves before it has a Liveblocks project; the offline tests point the client at a stand-in |
| 9 | Every action in `lib/actions` that reaches Liveblocks, and the email webhook, answer "not connected" first; `app/dashboard/layout.tsx` renders `components/NotConnected` instead | The same |
| 10 | `app/api/notifications/email/route.ts` uses the shared client | Its own client threw at build without a key |
| 11 | `app/api/health/route.ts` added | The deploy's smoke and the record's probe |
| 12 | `lib/site.ts` (`SITE_NAME`, `SOURCE_URL`): the page title; the marketing footer's copyright and source link (upstream: "Liveblocks Inc." and the kit's monorepo) | One rename seam; each product links its own repository |
| 13 | `getLiveUsers.ts` reads its entry with `?.` | `noUncheckedIndexedAccess` in the workspace's tests |
| 14 | ESLint: the flat config of eslint-config-next 16 with the kit's own rule choices (`no-explicit-any`, `ban-ts-comment`, `react/display-name`, `ban-types` off) and `react-hooks/set-state-in-effect`, `react-hooks/refs` off | `next lint` is gone in Next 16; the React Compiler rules postdate the kit |
| 15 | `apps/web/LICENSE.md` is the monorepo's Apache-2.0 text | The kit's `package.json` licence; the product carries it |
| 16 | `wrangler.template.jsonc` (the D1 binding), `component.yaml`, `cloudflare-env.d.ts`, `open-next.config.ts` | The Worker's config and the deploy contract replace Vercel's |
| 17 | `app/api/notifications/email/route.ts` verifies the webhook's signature over the body as sent (`request.text()`), not `JSON.stringify` of the parsed body | The signature covers the bytes Liveblocks sent; a re-serialization differs from them whenever the formatting does, and the e2e's signed delivery was refused |

## Verified

- `pnpm typecheck`, `lint`, `test` (tests/web 23, tests/db 14) and `build`
  green; the Worker is 2.3 MiB gzipped (Workers Free).
- Every Baseline CI tier passes locally on orun v2.89.0, the end-to-end tier
  included.
