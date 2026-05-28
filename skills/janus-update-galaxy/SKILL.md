---
name: janus-update-galaxy
description: "Edit data/galaxy/star_map.yaml to add nebulae, travel routes, or modify star system visual properties. The 'galaxy painter' skill. Use when adjusting the visual galaxy map."
argument-hint: "<action> [args]"
allowed-tools:
  - mcp__JanusGM__read_file
  - mcp__JanusGM__write_file
---

@$HOME/.claude/janus-skills/resources/schema-galaxy.md

# /janus-update-galaxy

<objective>
Read `data/galaxy/star_map.yaml`, apply one of three targeted sub-actions (add-nebula, add-route,
or edit-system), then write the modified file back via the MCP server. All top-level keys
(`camera`, `systems`, `routes`, `nebulae`) are preserved. This skill does NOT create new star
systems or system directories — use `/janus-add-system` for that.
</objective>

<process>
1. Parse `$ARGUMENTS` for an action keyword. Valid values: `add-nebula`, `add-route`,
   `edit-system`. If the argument is missing or unrecognised, list the three options and ask the
   user to choose before continuing.

2. Call `read_file("galaxy/star_map.yaml")` and parse the YAML. Store all existing top-level
   keys. If the file is missing or unreadable, abort with a clear error.

3. **Branch: add-nebula**
   - Prompt the user for:
     - `name` (required): display name for the nebula
     - `position`: [x, y, z] in galaxy space (required)
     - `color`: hex integer (default `0x5aaa9a`)
     - `size`: float (default `50`)
     - `particle_count`: integer (default `3000`)
     - `opacity`: float 0.0–1.0 (default `0.15`)
     - `type`: string (default `emission`; allow `absorption`, `planetary`, `reflection`)
   - Build a new nebula mapping and append it to the `nebulae:` list. If `nebulae` does not
     exist in the file yet, create it as an empty list first.

4. **Branch: add-route**
   - Prompt the user for:
     - `from` and `to`: system display names (required). Both must exist in the `systems[]`
       array — refuse with a helpful message if either name is not found.
     - `color`: hex integer (default `0x5a7a9a`)
     - `route_type`: string (default `major_trade`; allow `minor_trade`, `restricted`, `military`)
     - `travel_time_days`: integer (default `50`)
   - Build a new route mapping and append it to the `routes:` list. If `routes` does not
     exist in the file yet, create it as an empty list first.
   - Verify `from` and `to` match system entries by comparing against `systems[].name` values.
     Do not accept slugs here — star_map.yaml routes use display names, not slugs.

5. **Branch: edit-system**
   - Prompt the user for the system name to edit (must exist in `systems[]` — refuse if not found).
   - Display the current values for: `color`, `size`, `type`, `label`, `position`,
     `info.description`, `info.population`.
   - For each field, prompt the user for a new value. Blank input = keep current value.
   - Apply only the changed fields to the system entry in the `systems[]` array.

6. Re-serialize the entire star_map.yaml preserving all top-level keys in their original order
   (`camera`, `systems`, `routes`, `nebulae`). If a key was absent from the original file and
   was not added by this operation, omit it.

7. **PyYAML hex-color caveat**: PyYAML's default YAML dumper converts integer values like
   `0x5aaa9a` to their decimal equivalents (e.g., `5940378`). If the serialized output contains
   decimal integers where hex literals are expected (colors), post-process the YAML string to
   restore the `0xRRGGBB` hex form. Identify color fields (`color:` keys) and rewrite any
   decimal value that corresponds to a known color as a `0x`-prefixed hex literal. Alternatively,
   serialize color values as quoted hex strings (e.g., `"0x5aaa9a"`) if the renderer accepts
   strings — confirm which format the existing file uses and match it exactly.

8. Call `write_file("galaxy/star_map.yaml", updated_content)` to save the changes.

9. Confirm to the user: what was added or changed, the final state of the affected entry, and
   that the SSE broadcast will automatically refresh the player galaxy map within seconds.
</process>
