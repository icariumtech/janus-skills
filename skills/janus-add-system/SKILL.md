---
name: janus-add-system
description: "Add a new star system to the galaxy: appends an entry to data/galaxy/star_map.yaml and scaffolds the system directory with system_map.yaml + location.yaml. Use when introducing a new star system to the campaign map."
argument-hint: "<system-name> [coordinates]"
allowed-tools:
  - mcp__JanusGM__read_field
  - mcp__JanusGM__append_list_item
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

<process>
1. Parse `$ARGUMENTS` for system name and optional 3D coordinates `[x, y, z]`.

2. Call `read_field("galaxy/star_map.yaml", "systems")` to get the existing systems list
   for slug collision checking. This returns only the systems array, not the full file.

3. Derive the system slug: `name.lower().replace(" ", "-")`.
   Examples: "Tau Ceti" → `tau-ceti`, "Proxima Centauri" → `proxima-centauri`.
   CRITICAL (Pitfall P1): The slug must be all lowercase with hyphens. It must match the
   directory name exactly — a case mismatch silently breaks location loading.

4. Check for slug collision against existing `systems[].location_slug` values from step 2.
   If a collision is found, refuse to proceed and ask the user for a different system name or a
   custom slug. Do NOT append a numeric suffix for systems (unlike NPCs) — system slugs must be
   unique and human-readable.

5. Ask the user for required visual properties with sensible defaults:
   - `position`: 3D coordinates `[x, y, z]` (default `[0, 0, 0]` — warn user to set a real position)
   - `color`: hex star color as integer (default `16776874` which is `0xFFFFAA`)
   - `size`: float visual size (default 2.5)
   - `type`: string (default `"star"`)
   - `label`: boolean, show name label (default `true`)
   - `info.description`: short description string
   - `info.population`: population string (e.g., `"~50,000"`)

6. Build the new system entry dict. Call `append_list_item("galaxy/star_map.yaml", "systems",
   new_system_entry)`. The server appends atomically and triggers SSE — no need to read or
   reconstruct the full file. Note: colors are stored as integers (decimal), not hex literals.

7. Build the `system_map.yaml` content for the new system:
   - `star` block: `name` (system name), `color` (same integer as star_map entry), `size: 4.5`
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
