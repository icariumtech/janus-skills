# CLAUDE.md

Dev orientation for working on the `janus-skills` repo itself. End-user docs live
in `README.md` — this file captures the gotchas that aren't obvious from the
code.

## Project shape

- `skills/janus-*/SKILL.md` — eight Claude Code slash commands (`/janus-add-npc`,
  `/janus-update-galaxy`, etc.). Each is a single SKILL.md with YAML frontmatter
  and an `@-include` pointing at one of the schema resources.
- `resources/schema-*.md` — condensed YAML schema references. **Auto-synced** from
  [`janus-console`](https://github.com/icariumtech/janus-console) (`docs/schemas/`).
  See `resources/_SYNCED_FROM_JANUS_CONSOLE.md`.
- `install.sh` / `install.ps1` — installers for Linux/macOS and Windows.
- `mcp-config-template.json` — `JanusGM` MCP server stanza with a `HOMELAB_IP`
  placeholder. Used by both installers when `--mcp-config` / `-McpConfig` is set.

## Non-obvious rules

1. **Do not edit `resources/schema-*.md` here.** They're overwritten on the next
   push to `janus-console/main`. To change a schema, PR against
   `janus-console/docs/schemas/`. The sync workflow lives at
   `janus-console/.github/workflows/sync-skills-schemas.yml`.

2. **`install.ps1` must stay ASCII-only.** Windows PowerShell 5.1 reads files as
   cp1252 when no BOM is present, and any em-dash, smart quote, or other non-ASCII
   byte causes parser errors like `The string is missing the terminator`. Also
   avoid `<placeholder>` syntax inside double-quoted `Write-Host` strings — the
   `<` triggers `'<' operator reserved for future use`. Use `PLACEHOLDER` or
   single quotes instead. Verify with:
   `LC_ALL=C grep -nP '[^\x00-\x7f]' install.ps1` (should match nothing).

3. **`install.ps1` copies, `install.sh` symlinks.** This is intentional — Windows
   symlinks require Developer Mode or admin. Consequence: Windows users must
   re-run `install.ps1` after `git pull` to pick up changes. Don't "fix" the
   Windows installer to symlink without addressing the Developer Mode dependency.

4. **SKILL.md `@-includes` use absolute `$HOME` paths**, not repo-relative:
   ```
   @$HOME/.claude/janus-skills/resources/schema-campaign.md
   ```
   These are resolved at skill-load time inside `~/.claude/`, not from the repo
   checkout. If you rename or relocate a schema file, all 8 SKILL.md files need
   updating in lockstep — `grep -rn 'janus-skills/resources/' skills/` to find
   them.

5. **`install.ps1` writes Claude Code config, not Claude Desktop config.** The
   `-McpConfig` flag injects into `%USERPROFILE%\.claude\settings.json` (Claude
   Code's location). Claude Desktop reads from
   `%APPDATA%\Claude\claude_desktop_config.json` and uses a different MCP entry
   shape (stdio + `mcp-remote` bridge for SSE servers). If we ever add Claude
   Desktop support, it'll need a separate flag and template.

## Testing changes

- **Schema** edits: PR against `janus-console/docs/schemas/`, let the sync workflow
  push here.
- **Skill** edits: re-run `install.sh --global` (or `install.ps1 -Global`), restart
  Claude Code, invoke the slash command.
- **Installer** edits: dry-run the script with a throwaway `--project /tmp/test`
  to avoid clobbering your real `~/.claude/`.
