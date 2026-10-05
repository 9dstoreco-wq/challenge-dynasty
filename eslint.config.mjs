import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

export default defineConfig([
  ...nextVitals,
  ...nextTs,
  globalIgnores([".next/**", "out/**", "build/**", "next-env.d.ts"]),
  {
    // Los <img> son logos y fotos estaticas pequenas servidas desde /public; no pasan por el optimizador a proposito.
    rules: { "@next/next/no-img-element": "off" },
  },
]);