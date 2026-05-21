# Synced — Do Not Edit Here

The `schema-*.md` files in this directory are **auto-synced** from the
[`janus-console`](https://github.com/icariumtech/janus-console) repo by a GitHub
Action on every push to `main` over there. They are the canonical, condensed YAML
schema references that Claude Code skills (`/janus-add-npc`, `/janus-update-galaxy`,
etc.) `@-include` at runtime.

## To change a schema

Edit `docs/schemas/schema-*.md` in **`janus-console`**, not here. The next push to
`janus-console/main` will overwrite this directory's schema files (preserving this
notice and any non-`schema-*.md` files).

PRs that edit `resources/schema-*.md` directly will be reverted by the next sync.

## Provenance

Every sync commit message includes a back-link to the source commit on
`janus-console`. Example:

```
chore(schemas): sync from janus-console@4ba3dbe
Source: https://github.com/icariumtech/janus-console/commit/4ba3dbe...
```

## Workflow

See `.github/workflows/sync-skills-schemas.yml` in `janus-console`.
