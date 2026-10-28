import { Liveblocks } from "@liveblocks/node";
import { getProviders } from "@/auth";

// Your Liveblocks secret key
export const SECRET_API_KEY = process.env.LIVEBLOCKS_SECRET_KEY;

// Whether a Liveblocks project is connected. Without its secret key the site
// still builds and serves: the dashboard says how to connect one, and every
// call that would reach Liveblocks answers NOT_CONNECTED instead of sending a
// request with no key.
export const LIVEBLOCKS_CONNECTED = Boolean(SECRET_API_KEY);

export const NOT_CONNECTED = {
  code: 503,
  message: "Liveblocks is not connected",
  suggestion:
    "Store your Liveblocks project's secret key as the LIVEBLOCKS_SECRET_KEY secret and redeploy (the README's \"Connecting Liveblocks\").",
};

function notConnected(): Liveblocks {
  return new Proxy({} as Liveblocks, {
    get() {
      return () => Promise.reject(new Error(NOT_CONNECTED.message));
    },
  });
}

export const liveblocks: Liveblocks = SECRET_API_KEY
  ? new Liveblocks({
      secret: SECRET_API_KEY,
      // Unset, the client talks to Liveblocks itself. The offline tests point
      // it at a local stand-in.
      ...(process.env.LIVEBLOCKS_BASE_URL ? { baseUrl: process.env.LIVEBLOCKS_BASE_URL } : {}),
    })
  : notConnected();

// ============================================================================
if (typeof window !== "undefined") {
  console.log();
  console.error(
    "DANGER: You're using data from /liveblocks.server.config.ts on the client"
  );
  console.error("This may expose your secret key(s)");
  console.log();
}

(async () => {
  const providers = await getProviders();

  if (providers?.github) {
    if (!process.env.GITHUB_CLIENT_ID || !process.env.GITHUB_CLIENT_SECRET) {
      console.log(`Your GitHub secrets are missing from .env.local

Example .env.local file:
GITHUB_CLIENT_ID=sk_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
GITHUB_CLIENT_SECRET=sk_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

Follow the full starter kit guide to learn how to get them:
https://liveblocks.io/docs/guides/nextjs-starter-kit#github-authentication
      `);
    }
  }

  if (providers?.auth0) {
    if (
      !process.env.AUTH0_CLIENT_ID ||
      !process.env.AUTH0_CLIENT_SECRET ||
      !process.env.AUTH0_ISSUER_BASE_URL
    ) {
      throw new Error(`Your Auth0 secrets are missing from .env.local

Example .env.local file:
AUTH0_CLIENT_ID=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
AUTH0_CLIENT_SECRET=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
AUTH0_ISSUER_BASE_URL=https://XXXXXXXXXXXXXXXXXX.com

Follow the full starter kit guide to learn how to get them:
https://liveblocks.io/docs/guides/nextjs-starter-kit#auth0-authentication
      `);
    }
  }
})();
