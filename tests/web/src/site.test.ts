import { readFileSync } from "node:fs";
import * as path from "node:path";
import { describe, expect, it } from "vitest";

describe("site identity (apps/web/lib/site.ts)", () => {
  it("names the site and links its source repository", async () => {
    const { SITE_NAME, SOURCE_URL } = await import("@/lib/site");
    expect(SITE_NAME.trim()).not.toBe("");
    expect(SOURCE_URL).toMatch(/^https:\/\/github\.com\/[A-Za-z0-9-]+\/[a-z0-9-]+$/);
  });
});

describe("the site's name and source link reach the pages", () => {
  const web = (f: string) => readFileSync(path.resolve(__dirname, "../../../apps/web", f), "utf8");
  it("titles every page with SITE_NAME", () => {
    expect(web("app/layout.tsx")).toContain("title: SITE_NAME,");
  });
  it("links the site's own repository from the marketing footer", () => {
    const footer = web("components/Marketing/MarketingFooter.tsx");
    expect(footer).toContain("href={SOURCE_URL}");
    expect(footer).toContain("{SITE_NAME}");
  });
});
