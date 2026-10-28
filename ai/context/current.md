# liveblocks-starter — where this repository stands

The entry page for anyone (or any agent) picking this repository up. It is
this repository's own state and does not ship to a product built from it;
the two pages that do are [operations.md](operations.md) and
[deployment.md](deployment.md).

## What it is

Liveblocks' Next.js Starter Kit (Vercel's Liveblocks Starter Kit template) —
a collaborative app: documents, notes, a whiteboard and a canvas edited in
real time, with comments, notifications, sharing and organizations — on
Cloudflare Workers + Static Assets, its directory and session secret in a
D1 database Terraform provisions and migrations fill, its documents in a
Liveblocks project the owner connects after the build. Packaged as an Orun
baseline: `orun new --blueprint repo-blueprint.yaml` builds a new product in
its own repository and takes it to live on stage and prod in one landing
(`01-product`: cloudflare-d1 → db-migrate → web per environment), then
records what went live (`02-docs`).

## Release

| | |
|---|---|
| Latest tag | `baseline-v1` (LB0–LB2: the kit on Workers, its directory on D1, Liveblocks optional) |
| Proven live | No. Everything short of the platform is proven offline in Baseline CI: the migration lane against a stand-in D1 API, the built Worker served with no Liveblocks project and against a stand-in Liveblocks API. A live bootstrap from a tag is still to come (risk LB-A) |

## Where to read

| Question | Page |
|---|---|
| What shipped, and every departure from upstream | `specs/epics/liveblocks-starter/IMPLEMENTATION-STATUS.md` |
| Why it is built this way | [decisions.md](decisions.md), then `specs/epics/liveblocks-starter/design.md` |
| What could still go wrong | [open-risks.md](open-risks.md), then `specs/epics/liveblocks-starter/risks-and-open-questions.md` |
| How to instantiate it | `BOOTSTRAP.md`, `docs/phases/` |
| What each component is | `<component>/docs/` beside each `component.yaml` — `apps/web`, `packages/db`, `infra/db-migrate`, `infra/terraform/cloudflare-d1`, `tests/{web,db}` (generated; `python3 tooling/catalog/gen-component-docs.py`) |

## Next

1. Bootstrap one product from `baseline-v1` against a workspace whose
   Cloudflare token can mint D1 Edit as well as Workers Scripts, connect a
   Liveblocks development project, and record its timings (closes LB-A, LB-B).
