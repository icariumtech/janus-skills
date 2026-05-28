---
name: janus-add-ship
description: "Register a new ship in data/ships/ with a location.yaml that self-injects onto an orbit map via body_slug/system_slug. Use when adding a ship to the campaign."
argument-hint: "<ship-name> [parent-system] [parent-body]"
allowed-tools:
  - mcp__JanusGM__list_files
  - mcp__JanusGM__read_file
  - mcp__JanusGM__write_file
---

@$HOME/.claude/janus-skills/resources/schema-ships.md

# /janus-add-ship

<objective>
Create a ship entry at `data/ships/<slug>/location.yaml` using the JANUS MCP server. Ships live
under `data/ships/` — they are NOT nested under a galaxy body directory. Instead, the `body_slug`
and `system_slug` pointer fields in the location.yaml tell the data loader where to inject the
ship on the orbit map at runtime. An optional deckplan stub may also be created at
`ships/<slug>/deckplan.yaml` using the canonical `decks:` list format defined in `schema-encounters.md`
(the legacy `map/` directory format is NOT supported by EncounterMapDisplay). All write operations
go through the MCP server which triggers a live SSE broadcast to connected terminals.
</objective>

<process>
1. Parse `$ARGUMENTS` for: ship name (required), optional system slug (parent system), optional
   body slug (parent planet). If any are missing, prompt the user before continuing.

2. Determine ship kind. Ask if this ship will be:
   - **orbit** (default): ship orbits a planet and self-injects onto the orbit map
   - **surface**: ship is landed on a planet surface; `parent_type: surface`, no `orbital` block
   - **static**: ship is a permanent installation and does not need orbit injection

3. Derive the ship slug: `name.lower().replace(" ", "_")`. Underscores only — this matches the
   existing `patrol_gunboat` convention. Examples: "USCSS Iron Meridian" → `iron_meridian`,
   "Tug Delta-7" → `tug_delta-7`.

4. Enforce Pitfall P1: verify the slug matches `^[a-z0-9_-]+$`. If the user's input contains
   uppercase letters or special characters, normalize to lowercase and warn the user that the
   input was normalized. Both `system_slug` and `body_slug` must also match this pattern.

5. Call `list_files("ships")` to enumerate existing ship slugs. If a collision is detected,
   stop and ask the user to supply an alternate name or confirm they want to overwrite. Do NOT
   silently overwrite an existing ship.

6. **Orbit branch only**: Validate that the target system exists by calling
   `read_file("galaxy/<system_slug>/system_map.yaml")`. If the read fails (file not found),
   abort with: "System '<system_slug>' not found. Check slug against data/galaxy/ directories."

7. **Orbit branch — Pitfall P5 enforcement (CRITICAL)**: The `body_slug` must resolve to a
   direct child of the system directory (a planet), NOT a moon. Moons are nested one level
   deeper (e.g., `tau-ceti/tau-ceti-f/verdant/`) and will SILENTLY FAIL to inject the ship.
   - Call `list_files("galaxy/<system_slug>")` to get direct children of the system.
   - If `<body_slug>` does NOT appear in that listing, refuse with:
     "PITFALL P5: '<body_slug>' is not a direct child of system '<system_slug>'. It may be a
     moon. Ships can only orbit planets (direct system children). Use a planet slug such as
     'tau-ceti-f', not a moon slug such as 'verdant'."
   - If `<body_slug>` IS in the listing, proceed.

8. **Orbit branch**: Prompt for `orbital` sub-fields. Suggest these defaults:
   - `radius`: 32 (distance from planet centre)
   - `period`: 90 (higher = slower orbit animation)
   - `angle`: 135 (starting angle in degrees)
   - `inclination`: 0 (orbital plane tilt in degrees)
   - `size`: 1.5 (icon size)
   - `icon_type`: `ship` (allowed values: `ship`, `station`, `shipyard`)

9. **Surface branch**: Set `parent_type: surface` and omit the `orbital` block entirely. Still
   require `body_slug` and `system_slug` for location tracking.

10. **Static branch**: Omit both `parent_type` orbit injection fields and the `orbital` block.
    Record the ship name, type, description, and status only.

11. Build the YAML content for `location.yaml`. Use double-quoted strings for free-text fields.
    Place fields in this order: `name`, `type`, `description`, `status`, then `parent_type`,
    `body_slug`, `system_slug`, then the `orbital` block if applicable.

12. Call `write_file("ships/<ship-slug>/location.yaml", content)` to register the ship.

13. Ask the user if they want an empty deckplan stub. If yes, build a minimal
    `data/ships/<ship-slug>/deckplan.yaml` containing a single deck with no rooms:

    ```yaml
        decks:
          - id: main_deck
            name: Main Deck
            level: 1
            default: true
            unit_size: 30
            rooms: []
    ```

    Call `write_file("ships/<ship-slug>/deckplan.yaml", stub_content)`. Do NOT write into
    any `map/` subdirectory — that is the legacy format and will not load in EncounterMapDisplay
    (see schema-encounters.md → "Skills should write new format only").

14. Confirm to the user:
    - Written paths: `ships/<ship-slug>/location.yaml` and (if the deckplan stub was created) `ships/<ship-slug>/deckplan.yaml`
    - Pitfall P1 reminder: slug must match directory name exactly — lowercase, hyphens/underscores
    - Pitfall P5 reminder: `body_slug` must be a planet (direct system child), not a moon
    - SSE broadcast will trigger automatically; orbit map refreshes within seconds
</process>
