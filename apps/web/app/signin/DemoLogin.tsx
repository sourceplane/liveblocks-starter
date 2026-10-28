"use client";

import { signIn } from "next-auth/react";
import { Select } from "@/primitives/Select";
import styles from "./signin.module.css";

// Used only for demo authentication, displays a dropdown of users — the
// directory's (read from D1 by the page)
export function DemoLogin({ users }: { users: { id: string; name: string }[] }) {
  return (
    <div className={styles.actions}>
      <Select
        items={users.map((user) => ({ value: user.id, title: user.name }))}
        onChange={(email) => {
          signIn("credentials", { email });
        }}
        placeholder="Choose a profile…"
      />
    </div>
  );
}
