import { NOT_CONNECTED } from "@/liveblocks.server.config";
import styles from "@/layouts/Error/Error.module.css";

/**
 * What the dashboard shows until a Liveblocks project is connected: the
 * documents, their realtime editing, comments and notifications all live in
 * Liveblocks, so there is nothing to list yet.
 */
export function NotConnected() {
  return (
    <main className={styles.main} data-liveblocks="not-connected">
      <p className={styles.error}>{NOT_CONNECTED.message}</p>
      <p className={styles.suggestion}>{NOT_CONNECTED.suggestion}</p>
      <p className={styles.suggestion}>
        Create a project and copy its secret key from{" "}
        <a href="https://liveblocks.io/dashboard/apikeys">
          liveblocks.io/dashboard/apikeys
        </a>
        .
      </p>
    </main>
  );
}
