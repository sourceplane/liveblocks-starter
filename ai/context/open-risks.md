# liveblocks-starter — open risks

What is not yet proven or not yet decided. The full write-up of every risk,
including the accepted and resolved ones, is
`specs/epics/liveblocks-starter/risks-and-open-questions.md`; this page lists only
what is still live, so it should be short.

| ID | Risk | State | What closes it |
|---|---|---|---|
| LB-A | Not yet proven live: the `d1-edit` mint, the Terraform apply and its wiring publish, the migrations against the real D1 API, the deploy, the Worker-secrets push and the workers.dev probes | OPEN | One bootstrap from a tag against a workspace whose Cloudflare token can mint D1 Edit |
| LB-B | Realtime against a real Liveblocks project is unproven: the room auth, presence, comments and notifications were exercised only against a stand-in API | OPEN | Connect a Liveblocks development project to a bootstrapped product and edit a document from two browsers |

Accepted, and worth knowing before you change them: LB-C (the Worker is
2.3 MiB gzipped — Workers Free, with ~0.7 MiB headroom; tldraw and the
editors are most of it), LB-D (the sign-in is the kit's demo login: anyone
can sign in as any directory user — replace it before real use), LB-E (the
directory is readable through `lib/database`'s server functions, as the kit
shipped it in the browser bundle), LB-F (the canvas is tldraw, under the
tldraw license: its watermark stays).
