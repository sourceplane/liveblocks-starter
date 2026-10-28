import { redirect } from "next/navigation";
import { ReactNode } from "react";
import { auth } from "@/auth";
import { NotConnected } from "@/components/NotConnected";
import { DashboardLayout } from "@/layouts/Dashboard";
import { LIVEBLOCKS_CONNECTED } from "@/liveblocks.server.config";

export default async function Dashboard({ children }: { children: ReactNode }) {
  const session = await auth();

  // If not logged in, go to marketing page
  if (!session) {
    redirect("/");
  }

  // Until a Liveblocks project is connected there are no documents to list
  // (they are Liveblocks rooms): say how to connect one instead.
  if (!LIVEBLOCKS_CONNECTED) {
    return <NotConnected />;
  }

  return <DashboardLayout>{children}</DashboardLayout>;
}
