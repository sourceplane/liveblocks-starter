import { redirect } from "next/navigation";
import { auth, getProviders } from "@/auth";
import { DASHBOARD_URL } from "@/constants";
import { getUsers } from "@/lib/database";
import { DemoLogin } from "./DemoLogin";
import { NextAuthLogin } from "./NextAuthLogin";
import styles from "./signin.module.css";

export default async function SignInPage() {
  const session = await auth();

  // If logged in, go to dashboard
  if (session) {
    redirect(DASHBOARD_URL);
  }

  const providers = await getProviders();
  const users = providers?.credentials
    ? (await getUsers()).flatMap((user) =>
        user ? [{ id: user.id, name: user.name }] : []
      )
    : [];
  return (
    <div className={styles.container}>
      <main className={styles.main}>
        <h2 className={styles.title}>Sign in to your account</h2>
        {providers && providers.credentials ? (
          <DemoLogin users={users} />
        ) : (
          <NextAuthLogin providers={providers} />
        )}
      </main>
      <aside className={styles.aside} />
    </div>
  );
}
