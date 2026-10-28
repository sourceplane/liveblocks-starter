import {
  WebhookHandler,
  isCustomNotificationEvent,
  isTextMentionNotificationEvent,
  isThreadNotificationEvent,
} from "@liveblocks/node";
import {
  LIVEBLOCKS_CONNECTED,
  NOT_CONNECTED,
  liveblocks,
} from "@/liveblocks.server.config";
import { addedToDocumentEmail } from "./addedToDocumentEmail";
import { textMentionEmail } from "./textMentionEmail";
import { threadEmail } from "./threadEmail";

// Learn more
// https://liveblocks.io/docs/guides/how-to-create-a-notification-settings-panel

// The shared client (liveblocks.server.config.ts), which needs no key to build

// Add your webhook secret key from a project's webhooks dashboard
const WEBHOOK_SECRET_KEY = process.env.LIVEBLOCKS_WEBHOOK_SECRET_KEY;

export async function POST(request: Request) {
  if (!LIVEBLOCKS_CONNECTED) {
    return new Response(NOT_CONNECTED.message, { status: 503 });
  }

  if (!WEBHOOK_SECRET_KEY) {
    return new Response("To use email notifications, first set up webhooks", {
      status: 400,
    });
  }

  // The signature covers the body's bytes as sent, so verify those — not a
  // re-serialization of the parsed JSON, which differs from them whenever the
  // sender's formatting does.
  const rawBody = await request.text();
  const headers = request.headers;

  let event;

  try {
    // Verify if this is a real webhook request
    const webhookHandler = new WebhookHandler(WEBHOOK_SECRET_KEY);
    event = webhookHandler.verifyRequest({
      headers: headers,
      rawBody,
    });
  } catch (err) {
    console.error(err);
    return new Response("Couldn't verify webhook call", { status: 400 });
  }

  if (isThreadNotificationEvent(event)) {
    return await threadEmail(liveblocks, event);
  } else if (isTextMentionNotificationEvent(event)) {
    return await textMentionEmail(liveblocks, event);
  } else if (
    isCustomNotificationEvent(event) &&
    event.data.kind === "$addedToDocument"
  ) {
    return await addedToDocumentEmail(liveblocks, event);
  }

  return new Response("Event type not used", {
    status: 200,
  });
}
