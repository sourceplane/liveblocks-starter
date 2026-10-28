import NextAuth from "next-auth";
import { authConfig } from "@/auth.config";
import { getCurrentOrganization, switchOrganization } from "@/lib/actions";
import { appSecret } from "@/lib/appSecret";
import { getUser } from "@/lib/database/getUser";

// The session secret is generated once per database (the `app_secrets`
// migration) and read per request; an AUTH_SECRET Worker secret wins.
export const {
  handlers: { GET, POST },
  auth,
  signIn,
  signOut,
} = NextAuth(async () => ({
  secret: await appSecret("auth"),
  callbacks: {
    // Get extra user info from your database to pass to front-end
    // For front end, update next-auth.d.ts with session type
    async session({ session, token }: { session: any; token: any }) {
      const userInfo = await getUser(session.user.email);

      if (!userInfo) {
        throw new Error("User not found");
      }

      session.user.info = userInfo;
      session.user.currentOrganizationId = token.organizationId;

      // On every load, check current org and if user has access
      const currentOrganizationId = await getCurrentOrganization();

      if (currentOrganizationId) {
        if (userInfo.organizationIds.includes(currentOrganizationId)) {
          session.user.currentOrganizationId = currentOrganizationId;
        }
      }

      return session;
    },
    async jwt({ token, user }) {
      // Once on sign in, get user and current org. Set an org if not set already.
      if (user && user.email) {
        const userInfo = await getUser(user.email);

        if (userInfo) {
          const currentOrganizationId = await getCurrentOrganization();

          if (
            currentOrganizationId &&
            userInfo.organizationIds.includes(currentOrganizationId)
          ) {
            token.organizationId = currentOrganizationId;
          } else {
            // A user's first organization is where they land. The directory
            // is the database's now, and a user can have none: then there is
            // nothing to switch to.
            const firstOrganization = userInfo.organizationIds[0];
            if (firstOrganization) {
              token.organizationId = firstOrganization;
              await switchOrganization(firstOrganization);
            }
          }
        }
      }

      return token;
    },
  },
  pages: {
    signIn: "/signin",
  },

  ...authConfig,
}));

export function getProviders() {
  const providers: Record<string, string> = {};

  for (const provider of authConfig.providers) {
    if ("id" in provider) {
      providers[provider.id] = provider.name;
    }
  }

  return providers;
}
