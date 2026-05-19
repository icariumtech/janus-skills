---
name: janus-add-system
description: "Add a new star system to the galaxy: appends an entry to data/galaxy/star_map.yaml and scaffolds the system directory with system_map.yaml + location.yaml. Use when introducing a new star system to the campaign map."
argument-hint: "<system-name> [coordinates]"
allowed-tools:
  - mcp__JanusGM__read_file
  - mcp__JanusGM__write_file
---

@$HOME/.claude/janus-skills/resources/schema-galaxy.md

# /janus-add-system

<objective>
Add a new star system to the campaign galaxy by creating three files:
1. Append a new entry to `data/galaxy/star_map.yaml` (the 3D galaxy visualization)
2. Create `data/galaxy/<system-slug>/system_map.yaml` (the system's 3D solar map)
3. Create `data/galaxy/<system-slug>/location.yaml` (the system root location record)

All writes go through the JANUS MCP server which triggers live SSE broadcasts. The slug must
be lowercase + hyphens only — a case mismatch silently breaks location discovery (Pitfall P1).
</objective>

<schema>
@$HOME/.claude/janus-skills/resources/schema-galaxy.md
</schema>

<process>
1. Parse `$ARGUMENTS` for system name and optional 3D coordinates `[x, y, z]`.

2. Call `read_file("galaxy/star_map.yaml")` to load the current galaxy map. Parse the YAML
   to extract the `systems[]` list and all other top-level blocks (camera, routes, nebulae).

3. Derive the system slug: `name.lower().replace(" ", "-")`.
   Examples: "Tau Ceti" → `tau-ceti`, "Proxima Centauri" → `proxima-centauri`.
   CRITICAL (Pitfall P1): The slug must be all lowercase with hyphens. It must match the
   directory name exactly — a case mismatch silently breaks location loading.

4. Check for slug collision against existing `systems[].location_slug` values in star_map.yaml.
   If a collision is found, refuse to proceed and ask the user for a different system name or a
   custom slug. Do NOT append a numeric suffix for systems (unlike NPCs) — system slugs must be
   unique and human-readable.

5. Ask the user for required visual properties with sensible defaults:
   - `position`: 3D coordinates `[x, y, z]` (default `[0, 0, 0]` — warn user to set a real position)
   - `color`: hex star color (default `0xFFFFAA`)
   - `size`: float visual size (default 2.5)
   - `type`: string (default `"star"`)
   - `label`: boolean, show name label (default `true`)
   - `info.description`: short description string
   - `info.population`: population string (e.g., `"~50,000"`)

6. Build the new system entry dict. Append it to the `systems[]` list from step 2.
   Reconstruct the full star_map.yaml content — PRESERVE all existing top-level blocks
   (camera, routes, nebulae). Do not lose any existing data.
   Call `write_file("galaxy/star_map.yaml", updated_content)`.

7. Build the `system_map.yaml` content for the new system:
   - `star` block: `name` (system name), `color` (same hex as star_map entry), `size: 4.5`
   - `camera` block: `position: [0, 127, 127]`, `lookAt: [0, 0, 0]`, `fov: 75`
   - `bodies: []` (empty list — bodies added later via `/janus-add-body`)
   Call `write_file("galaxy/<system-slug>/system_map.yaml", content)`.

8. Build the `location.yaml` content for the system root:
   - `name`: system display name
   - `type: "system"`
   - `status: "OPERATIONAL"`
   - `description`: from step 5 info.description
   Call `write_file("galaxy/<system-slug>/location.yaml", content)`.

9. Confirm to the user: list all three files written (`galaxy/star_map.yaml` updated,
   `galaxy/<system-slug>/system_map.yaml` created, `galaxy/<system-slug>/location.yaml` created).
   Suggest follow-up: run `/janus-add-body` to add planets and stations, or `/janus-update-galaxy`
   to add travel routes or visual adjustments to the galaxy map.
</process>
