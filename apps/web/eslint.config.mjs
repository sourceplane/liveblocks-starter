import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

export default defineConfig([
  ...nextVitals,
  ...nextTs,
  {
    rules: {
      // The kit's own lint settings (its .eslintrc.cjs), carried into the flat
      // config: it types loosely in places, uses @ts-ignore, and defines its
      // forwardRef components without display names.
      "@typescript-eslint/no-explicit-any": "off",
      "@typescript-eslint/ban-ts-comment": "off",
      "react/display-name": "off",
      // `ban-types: off` in the kit's config; typescript-eslint 8 split its
      // `{}` check into this rule.
      "@typescript-eslint/no-empty-object-type": "off",
      "@typescript-eslint/no-unused-vars": ["warn", { argsIgnorePattern: "^_" }],
      // The kit sets state from effects and reads a ref while rendering (the
      // whiteboard); the rules that flag those arrived with eslint-config-next
      // 16, after the kit was written.
      "react-hooks/set-state-in-effect": "off",
      "react-hooks/refs": "off",
    },
  },
  globalIgnores([".next/**", ".open-next/**", "next-env.d.ts", "cloudflare-env.d.ts"]),
]);
