"use server";

import { colors } from "@/data/colors";
import { db } from "./db";

type UserRow = { id: string; name: string; avatar: string };

/**
 * Get User
 *
 * Reads a user and the organizations they belong to (in their order) from
 * the D1 database, with a colour seeded from their id
 *
 * @param userId - The user's id
 */
export async function getUser(userId: string) {
  const user = await db()
    .prepare("SELECT id, name, avatar FROM users WHERE id = ?")
    .bind(userId)
    .first<UserRow>();

  if (!user) {
    console.warn(`User "${userId}" was not found in the users table.`);
    return null;
  }

  const { results } = await db()
    .prepare(
      "SELECT organization_id FROM memberships WHERE user_id = ? ORDER BY position"
    )
    .bind(userId)
    .all<{ organization_id: string }>();

  const color = getRandom(colors, userId);
  return {
    color,
    ...user,
    organizationIds: results.map((row) => row.organization_id),
  };
}

function getRandom<T>(array: T[], seed?: string): T {
  const index = seed
    ? Math.abs(hashCode(seed)) % array.length
    : Math.floor(Math.random() * array.length);

  // `index` is always in range (a remainder of the length).
  return array[index]!;
}

function hashCode(string: string) {
  let hash = 0;

  if (string.length > 0) {
    let index = 0;

    while (index < string.length) {
      hash = ((hash << 5) - hash + string.charCodeAt(index++)) | 0;
    }
  }

  return hash;
}
