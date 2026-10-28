"use server";

import { db } from "./db";
import { Organization } from "@/types";

/**
 * Get Organization
 *
 * Reads an organization from the D1 database
 *
 * @param id - The organization's id
 */
export async function getOrganization(
  id: string
): Promise<Organization | null> {
  return await db()
    .prepare("SELECT id, name, avatar FROM organizations WHERE id = ?")
    .bind(id)
    .first<Organization>();
}
