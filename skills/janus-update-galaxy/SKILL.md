---
name: janus-update-galaxy
description: "Edit data/galaxy/star_map.yaml to add nebulae, travel routes, or modify star system visual properties. The 'galaxy painter' skill. Use when adjusting the visual galaxy map."
argument-hint: "<action> [args]"
allowed-tools:
  - mcp__JanusGM__read_file
  - mcp__JanusGM__read_field
  - mcp__JanusGM__append_list_item
  - mcp__JanusGM__write_file
---

@$HOME/.claude/janus-skills/resources/schema-galaxy.md

# /janus-update-galaxy

<objective>
Apply one of three targeted sub-actions to `data/galaxy/star_map.yaml`:
- **add-nebula**: append a nebula entry — no file read required
- **add-route**: append a route entry — only the systems list is read for name validation
- **edit-system**: modify an existing star system — reads the full file, writes it back

This skill does NOT create new star systems or system directories — use `/janus-add-system` for that.

Note: the server uses PyYAML internally, so colors are stored as decimal integers (e.g. `5940378`)
rather than hex literals (e.g. `0x5aaa9a`). Both forms are numerically identical; the renderer
accepts either. When prompting users for colors, accept `0xRRGGBB` input and convert to integer.
</objective>

<process>
1. Parse `$ARGUMENTS` for an action keyword. Valid values: `add-nebula`, `add-route`,
   `edit-system`. If the argument is missing or unrecognised, list the three options and ask the
   user to choose before continuing.

2. **Branch: add-nebula** — skip to step 3. No file read needed.
   **Branch: add-route** — call `read_field("galaxy/star_map.yaml", "systems")` to get the
   systems list for name validation. Skip to step 4.
   **Branch: edit-system** — call `read_file("galaxy/star_map.yaml")` and parse the full YAML.
   Store all existing top-level keys. If the file is missing or unreadable, abort with a clear error.
   Skip to step 5.

3. **Branch: add-nebula**
   - Prompt the user for:
     - `name` (required): display name for the nebula
     - `position`: [x, y, z] in galaxy space (required)
     - `color`: color as integer (default `5940378`; accepts `0x5aaa9a` input — convert to int)
     - `size`: float (default `50`)
     - `particle_count`: integer (default `3000`)
     - `opacity`: float 0.0–1.0 (default `0.15`)
     - `type`: string (default `emission`; allow `absorption`, `planetary`, `reflection`)
   - Build the nebula dict. Call `append_list_item("galaxy/star_map.yaml", "nebulae", nebula_dict)`.
     The server creates the `nebulae` list if it doesn't exist yet.
   - Skip to step 9.

4. **Branch: add-route**
   - Prompt the user for:
     - `from` and `to`: system display names (required). Both must exist in the `systems[]`
       list from step 2 — refuse with a helpful message if either name is not found.
     - `color`: color as integer (default `5930138`; accepts `0x5a7a9a` input — convert to int)
     - `route_type`: string (default `major_trade`; allow `minor_trade`, `restricted`, `military`)
     - `travel_time_days`: integer (default `50`)
   - Verify `from` and `to` match `systems[].name` values. Do not accept slugs here.
   - Build the route dict. Call `append_list_item("galaxy/star_map.yaml", "routes", route_dict)`.
   - Skip to step 9.

5. **Branch: edit-system** (using full file data from step 2)
   - Prompt the user for the system name to edit (must exist in `systems[]` — refuse if not found).
   - Display the current values for: `color`, `size`, `type`, `label`, `position`,
     `info.description`, `info.population`.
   - For each field, prompt the user for a new value. Blank input = keep current value.
   - Apply only the changed fields to the system entry in the `systems[]` array.

6. Re-serialize the entire star_map.yaml preserving all top-level keys in their original order
   (`camera`, `systems`, `routes`, `nebulae`). If a key was absent from the original file and
   was not added by this operation, omit it.

7. Call `write_file("galaxy/star_map.yaml", updated_content)` to save the changes.

9. Confirm to the user: what was added or changed, the final state of the affected entry, and
   that the SSE broadcast will automatically refresh the player galaxy map within seconds.
</process>
