# liveblocks-starter — Vercel's Liveblocks Starter Kit on Cloudflare Workers and D1

**The kit is a collaborative app — rich-text documents, notes, a whiteboard
and a canvas edited together in real time, with comments, notifications,
sharing and organizations — whose documents are Liveblocks rooms and whose
"database" was arrays in its source. The port runs it as one Cloudflare
Worker, moves that directory into D1 behind the same four functions, makes
Liveblocks optional so a fresh product serves before it has a project — and
the baseline makes a copy of it somebody else's app in one landing.**

| | |
|---|---|
| Status | ✅ Shipped (`baseline-v1`) — proven offline in Baseline CI; not yet live (risk LB-A) |
| Upstream | [liveblocks/liveblocks `starter-kits/nextjs-starter-kit`](https://github.com/liveblocks/liveblocks/tree/main/starter-kits/nextjs-starter-kit) (Apache-2.0), at `4786148` (2026-10-27) |
| Reference | [turso-starter](https://github.com/sourceplane/turso-starter) — Next.js on OpenNext with D1, its migrations and bootstrap; [clerk-auth-starter](https://github.com/sourceplane/clerk-auth-starter) — a SaaS key as an optional secret pushed to the Worker |
| Key | `LB` |

## Read in this order

1. [design.md](design.md) — the kit, how each Vercel piece maps to
   Cloudflare, the directory on D1, Liveblocks optional, the repository and
   the build, and the alternatives rejected.
2. [implementation-plan.md](implementation-plan.md) — the milestones and
   what each one lands.
3. [risks-and-open-questions.md](risks-and-open-questions.md) — what is not
   proven, and what was accepted.
4. [IMPLEMENTATION-STATUS.md](IMPLEMENTATION-STATUS.md) — what shipped, and
   every departure from the upstream kit.

## Milestones

| Milestone | What it lands | Task |
|---|---|---|
| LB0 — the spec | the repository, its intent, CI, tooling and spec index; this doc set | LB-1 |
| LB1 — the collaborative app on Workers and D1 | the kit in `apps/web`, its directory as migrations, Liveblocks optional, its tests, the README | LB-2 |
| LB2 — a baseline | the console card, the build document, the context pack and the baseline's tests | LB-3 |
