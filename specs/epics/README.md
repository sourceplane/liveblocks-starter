# Epics

Orun-style work programs. Each epic is a folder carrying `epic.yaml` (the
declaration the platform reads: slug, key prefix, milestones with exit
criteria and task keys) beside its doc set. The pull request that adds the
folder is the adoption; the merge creates the epic in the workspace.

| Epic | Cluster | Status | What it is |
|------|---------|--------|------------|
| [`liveblocks-starter/`](./liveblocks-starter/) | **LB** | ✅ Shipped (`baseline-v1`); not yet live | Vercel's Liveblocks Starter Kit — documents, notes, a whiteboard and a canvas edited in real time — on Cloudflare Workers with its directory in D1 and its documents in Liveblocks, and an Orun baseline that instantiates it in one landing (LB2) |

As-built ≠ intent: what shipped lives in each epic's `IMPLEMENTATION-STATUS.md`.
