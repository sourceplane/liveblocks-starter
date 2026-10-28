# liveblocks-starter — risks and open questions

| ID | Risk | State | Notes |
|---|---|---|---|
| LB-A | `baseline-v1` is not yet proven live: the `d1-edit` mint, the D1 apply and its wiring publish, the migrations against the real D1 API, the deploy, the Worker-secrets push and the workers.dev probes | OPEN | Proven offline in Baseline CI. One bootstrap from the tag closes it |
| LB-B | Realtime against a real Liveblocks project is unproven: room auth, presence, comments, notifications, the inbox | OPEN | Exercised against a stand-in API that checks the key and the identify-user payload; a Liveblocks development project connected to a bootstrapped product closes it |
| LB-C | Worker size: 2.3 MiB gzipped (webpack) of Workers Free's 3 MiB; Turbopack's is 3.08 MiB | ACCEPTED | tldraw, BlockNote and Tiptap are most of it. A kit upgrade could cross 3 MiB — then Workers Paid (10 MiB) |
| LB-D | The sign-in is the kit's demo login: anyone can sign in as any directory user, with no password | ACCEPTED | The kit's design. The README and operations.md say to replace the Credentials provider before real use |
| LB-E | The directory is readable through `lib/database`'s server functions (anyone can call `getUsers`) | ACCEPTED | The kit shipped the whole directory in the browser bundle; names, avatars and email-shaped ids only |
| LB-F | The canvas is tldraw, under the tldraw license | ACCEPTED | Commercial use is allowed with its watermark kept (`components/Canvas/LICENSE.md`) |
| LB-G | Next.js 16 on OpenNext 1.20.11 | ACCEPTED | Pinned 16.3.8 (16.4.x fails on 1.20.11); no Cache Components |
| LB-H | A Liveblocks key removed from Orun stays on the Worker | ACCEPTED | The deploy pushes the keys that exist and deletes none; `wrangler secret delete` removes one |
| LB-I | The email handlers prepare emails but send none | ACCEPTED | As upstream: sending is the owner's to add |
| LB-J | `LIVEBLOCKS_BASE_URL` redirects the Liveblocks client | ACCEPTED | Unset in a product; a Worker variable only the owner sets. The offline tests use it |
