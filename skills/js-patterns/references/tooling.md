# Tooling (Vite + Vue + TypeScript)

What the linter and type checker own, so a review does not repeat them; and the config holes that
silently switch them off.

## ESLint flat config

```js
// eslint.config.js (ESLint 9)
import js from '@eslint/js'
import pluginVue from 'eslint-plugin-vue'
import vueTsEslintConfig from '@vue/eslint-config-typescript'
import prettier from '@vue/eslint-config-prettier/skip-formatting'

export default [
  { ignores: ['dist/**', 'coverage/**', '.nuxt/**', '.output/**'] },   // top-level object = global
  js.configs.recommended,
  ...pluginVue.configs['flat/recommended'],      // includes vue3-essential: v-for keys, prop mutation, computed side effects
  ...vueTsEslintConfig(),
  prettier,
  {
    files: ['**/*.{ts,vue}'],
    rules: {
      'vue/multi-word-component-names': 'off',   // only if the project really names single-word pages
      'vue/no-v-html': 'warn',
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-floating-promises': 'error',
      'no-console': ['warn', { allow: ['warn', 'error'] }],
    },
  },
]
```

Config holes that make rules vanish:

- `ignores` inside an object that also has `files` is not global; `dist/` gets linted, or nothing is.
- One block with `files: ['**/*.vue']` only: every `.js` / `.ts` file is rule-free.
- `--ext .vue,.ts` in `package.json` is ignored by flat config; file matching comes from `files`.
- No `flat/essential` or `flat/recommended` from `eslint-plugin-vue`: `require-v-for-key`,
  `no-mutating-props`, `no-side-effects-in-computed-properties` are off.
- `no-floating-promises` needs `parserOptions.project` (type-aware linting); without it the rule
  errors or is skipped.
- The config exists but no CI job runs it.

Legacy `.eslintrc.cjs` projects: `extends: ['plugin:vue/vue3-recommended',
'@vue/eslint-config-typescript/recommended', '@vue/eslint-config-prettier']`; match the repo.

## Prettier

```json
// .prettierrc
{ "semi": false, "singleQuote": true, "printWidth": 100, "trailingComma": "all" }
```

Prettier formats, ESLint lints; `eslint-config-prettier` turns off the overlapping rules. Run
`prettier --check .` in CI; format on save locally.

## Type check: `vue-tsc --noEmit`

`tsc` does not understand `.vue`; `vue-tsc` does. `npm run typecheck` is `vue-tsc --noEmit -p
tsconfig.app.json` (or the config that owns `src/`). A project with `lang="ts"` in SFCs and no
`vue-tsc` in CI has no type check for its components.

## tsconfig strict flags

```json
{
  "extends": "@vue/tsconfig/tsconfig.dom.json",
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true,
    "noUnusedLocals": true,
    "verbatimModuleSyntax": true,
    "moduleResolution": "Bundler",
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["src/**/*.ts", "src/**/*.vue", "env.d.ts"]
}
```

`skipLibCheck: true` is fine (third-party `.d.ts`); loosening anything above in a diff is a finding.

## Vite essentials

```ts
// vite.config.ts
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { fileURLToPath, URL } from 'node:url'

export default defineConfig({
  plugins: [vue()],
  resolve: { alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) } },
  server: { proxy: { '/api': { target: 'http://localhost:8080', changeOrigin: true } } },
  build: {
    sourcemap: true,
    rollupOptions: { output: { manualChunks: { vendor: ['vue', 'vue-router', 'pinia'] } } },
  },
})
```

- Only `VITE_*` env vars reach the client (`import.meta.env.VITE_API_BASE`); everything else is
  server-side. A `VITE_` secret is a public secret.
- `npx vite-bundle-visualizer` (or `rollup-plugin-visualizer`) when a chunk grows; a chart library
  in the entry chunk is the usual culprit.
- Nuxt: `nuxt.config.ts` replaces this file; `runtimeConfig` replaces `VITE_*`.

## `package.json` scripts baseline

```json
{
  "scripts": {
    "dev": "vite",
    "build": "vue-tsc --noEmit -p tsconfig.app.json && vite build",
    "preview": "vite preview",
    "typecheck": "vue-tsc --noEmit -p tsconfig.app.json",
    "lint": "eslint . --fix",
    "lint:check": "eslint .",
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "test": "vitest run",
    "test:watch": "vitest",
    "test:e2e": "playwright test"
  }
}
```

CI runs `lint:check`, `format:check`, `typecheck`, `test`, `build`, in that order; `npm audit
--omit=dev` and `npx depcheck` on a schedule.

## `browserslist`

```
# .browserslistrc
> 0.5%, last 2 versions, not dead, not op_mini all
```

Vite's default `build.target` is `'modules'` (modern); an old-Safari or Android-WebView target
needs `@vitejs/plugin-legacy` and rules out syntax the docs recommend (`?.` on Safari < 13.1,
top-level `await` entirely). Read the project's list before proposing a newer idiom.
