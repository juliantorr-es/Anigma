# AtlasumWeb

Build-time tool that generates the Anigma Atlas HTML from `Docs/Atlas/anigma-atlas.md`.

## Package-lock policy

- Keep `package-lock.json` committed so builds are reproducible.
- Do not commit `node_modules/`.
- Use `npm audit fix` to address advisories, then rerun the atlas build.

## Build

```sh
npm install
npm run build
```
