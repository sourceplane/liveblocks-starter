"use server";

import { Organization } from "@/types";
import { db } from "./db";
import { getUser } from "./getUser";

type Props = {
  userId: string;
};

/**
 * Get Organizations
 *
 * Reads the organizations a user belongs to, in their order, from the D1 database
 *
 * @param userId - The user id to get organizations for
 */
export async function getUserOrganizations({ userId }: Props) {
  const user = await getUser(userId);
  if (!user) {
    return [];
  }

  const { results } = await db()
    .prepare(
      "SELECT o.id, o.name, o.avatar FROM memberships m JOIN organizations o ON o.id = m.organization_id WHERE m.user_id = ? ORDER BY m.position"
    )
    .bind(user.id)
    .all<Organization>();

  return results;
}
