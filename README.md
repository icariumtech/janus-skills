# JANUS Skills

Claude Code skill library for AI-driven campaign data management with the JANUS GM tool
(`github.com/icariumtech/janus-skills`). Eight `/janus-*` slash commands let you add NPCs,
locations, star systems, ships, and more — all backed by the JANUS MCP server.

## Prerequisites

- **JANUS server** running via Docker Compose (see Phase 23 / `janus-deploy`):
  ```bash
  docker compose up -d
  ```
- **Claude Code** — latest stable release
- **Python 3** — required only if using `--mcp-config` flag (pre-installed on most systems)

## Installation

### Windows (PowerShell)

```powershell
git clone https://github.com/icariumtech/janus-skills.git "$env:USERPROFILE\janus-skills"
cd "$env:USERPROFILE\janus-skills"
.\install.ps1 -Global
```

With MCP config (prompts for homelab IP):
```powershell
.\install.ps1 -Global -McpConfig
```

Project-local install:
```powershell
.\install.ps1 -Project C:\path\to\my-campaign
.\install.ps1 -Project C:\path\to\my-campaign -McpConfig
```

> **Note:** `install.ps1` copies files rather than symlinking. Re-run after pulling
> repo updates to pick up changes to skills or resources.

---

### Linux / macOS (bash)

```bash
git clone https://github.com/icariumtech/janus-skills.git ~/janus-skills
cd ~/janus-skills
./install.sh --global
```

Installs all skills to `~/.claude/skills/` and schema resources to
`~/.claude/janus-skills/resources/`. Restart Claude Code after installing.

### Add MCP config (inject server connection)

```bash
./install.sh --global --mcp-config
# Prompts: Homelab server IP (e.g., 192.168.1.42)
```

Merges the `JanusGM` MCP server block into `~/.claude/settings.json`. Preserves any
existing `mcpServers` entries. The URL becomes `http://<your-ip>:8001/mcp/`.

### Project-local install

```bash
./install.sh --project /path/to/my-campaign
./install.sh --project /path/to/my-campaign --mcp-config
```

Installs skills to `<path>/.claude/skills/` instead. Resources always go to
`~/.claude/janus-skills/resources/` regardless of mode.

> **Note:** Do not move the janus-skills repo after installing — symlinks point to the
> original location. Rerunning `install.sh` is safe and idempotent.

## Skills Reference

| Skill | Description | Example |
|-------|-------------|---------|
| `/janus-generate-context` | Read location.yaml via MCP and write a `janus.yaml` GM context file for the location | `/janus-generate-context galaxy/anchor-system/veil-station` |
| `/janus-add-npc` | Create a new NPC entry at `data/campaign/npcs/[id].yaml` | `/janus-add-npc Captain Dex Harrow, salvager` |
| `/janus-add-location` | Create a galaxy location directory with `location.yaml` (slug, type, parent path) | `/janus-add-location Veil Station, type station, system anchor-system` |
| `/janus-session-prep` | Call `get_session_context()`, read relevant `janus.yaml` files, produce a structured GM session brief | `/janus-session-prep` |
| `/janus-add-system` | Add a star system entry to `star_map.yaml` and create the system directory with `system_map.yaml` | `/janus-add-system Proxima Centauri` |
| `/janus-add-body` | Add a planet, moon, or station to an existing system — updates `system_map.yaml` and `orbit_map.yaml` | `/janus-add-body Tau Ceti f, type planet` |
| `/janus-add-ship` | Register a new ship in `data/ships/` with `location.yaml` (body_slug, system_slug for orbit injection) | `/janus-add-ship USCSS Morrigan` |
| `/janus-player-ship` | Set up or reconfigure the player's ship at `data/campaign/ship/` — identity, systems, resources, cargo, location.yaml | `/janus-player-ship USCSS Morrigan` |
| `/janus-update-galaxy` | Edit `star_map.yaml` for nebulae, travel routes, and star system visual properties | `/janus-update-galaxy add nebula The Veil` |

## Schema Resources

The `resources/` directory contains condensed YAML schema references installed to
`~/.claude/janus-skills/resources/`. Each skill @-includes only the schema slice it
needs — keeping AI context lean during campaign management sessions.

> **Note:** These files are **auto-synced from `janus-console`** (`docs/schemas/`)
> by a GitHub Action. Do not edit them here — edits will be overwritten on the next
> sync. To change a schema, open a PR against
> [`janus-console`](https://github.com/icariumtech/janus-console). See
> `resources/_SYNCED_FROM_JANUS_CONSOLE.md` for details.

| File | Covers |
|------|--------|
| `schema-campaign.md` | Crew, NPCs, corporations, standby (`data/campaign/`) |
| `schema-galaxy.md` | `star_map.yaml`, `system_map.yaml`, `orbit_map.yaml`, location hierarchy |
| `schema-ships.md` | Ship `location.yaml`, slug-pointer model, orbit self-registration |
| `schema-encounters.md` | Deckplans, rooms, doors, POIs |
| `schema-janus-context.md` | `janus.yaml` format produced by `/janus-generate-context` |

## Troubleshooting

**Skills not appearing in Claude Code (`/janus-*` not found)**
Restart Claude Code after running `install.sh`. Skills are loaded at startup. Verify
symlinks exist: `ls -la ~/.claude/skills/janus-*`

**MCP connection refused (`JanusGM` tools unavailable)**
1. Verify the JANUS server is running: `docker compose ps` — all services should be `Up`
2. Check port 8001 is accessible: `curl http://<your-ip>:8001/mcp/`
3. Confirm `JanusGM` key exists in your settings.json:
   ```bash
   grep -A4 JanusGM ~/.claude/settings.json
   ```
4. Re-run `./install.sh --global --mcp-config` if the key is missing
