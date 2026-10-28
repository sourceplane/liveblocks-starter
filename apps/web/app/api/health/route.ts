import { db } from "@/lib/database/db";
import { LIVEBLOCKS_CONNECTED } from "@/liveblocks.server.config";

// The deploy's smoke test and the deployment record's probe: proves the
// Worker serves, its D1 binding answers and the migrations ran (the users
// table is there), and says whether a Liveblocks project is connected.
// Counts only, nothing about who is in the directory.
export const dynamic = "force-dynamic";

export async function GET() {
  const row = await db()
    .prepare("SELECT count(*) AS users FROM users")
    .first<{ users: number }>();
  return Response.json({
    ok: true,
    users: row?.users ?? 0,
    liveblocks: LIVEBLOCKS_CONNECTED ? "connected" : "not-connected",
  });
}
