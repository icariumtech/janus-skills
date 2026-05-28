---
name: janus-add-body
description: "Add a planet, moon, or orbital station to an existing star system. Updates system_map.yaml (or orbit_map.yaml for moons) and creates the body directory with location.yaml. Use when adding a body to a star system."
argument-hint: "<body-name> <type> <parent-system> [parent-planet-for-moons]"
allowed-tools:
  - mcp__JanusGM__list_files
  - mcp__JanusGM__read_file
  - mcp__JanusGM__write_file
---

@$HOME/.claude/janus-skills/resources/schema-galaxy.md

# /janus-add-body

<objective>
Add a planet, moon, or station to an existing star system. This skill branches on `type`:

- **planet** or **station**: appends an entry to the system's `system_map.yaml` bodies list,
  and creates `data/galaxy/<system>/<body-slug>/location.yaml`
- **moon**: reads or creates the parent planet's `orbit_map.yaml`, appends to its `moons[]`
  list, and creates `data/galaxy/<system>/<planet>/<moon-slug>/location.yaml`

All writes go through the JANUS MCP server. Slugs must be lowercase + hyphens (Pitfall P1).
The `location_slug` in system_map.yaml or orbit_map.yaml must exactly match the directory name.
</objective>

<process>
1. Parse `$ARGUMENTS`: body name, type (`planet | moon | station`), parent system slug.
   If type is `moon`, also expect a parent planet slug. Ask for any missing required arguments.

2. Verify the parent system exists: call `read_file("galaxy/<system>/system_map.yaml")`.
   If the file is not found or returns an error, abort with: "System '<system>' not found.
   Run `/janus-add-system` to create it first."

3. If `type == moon`: verify the parent planet exists by calling
   `read_file("galaxy/<system>/<planet>/location.yaml")`.
   If not found, abort with: "Planet '<planet>' not found in system '<system>'."

4. Derive the slug: `name.lower().replace(" ", "-").replace("_", "-")`.
   Examples: "Tau Ceti e" → `tau-ceti-e`, "New Providence" → `new-providence`.
   CRITICAL (Pitfall P1): All lowercase + hyphens. The slug must EXACTLY match the directory
   to be created. A case mismatch silently prevents the body from appearing on the map.

5. Check for slug collision:
   - For planet/station: call `list_files("galaxy/<system>")` and check sibling slugs.
   - For moon: call `list_files("galaxy/<system>/<planet>")` and check sibling slugs.
   If collision found, append a numeric suffix (`-2`, `-3`, ...) and inform the user.

6. Branch on `type`:

   **planet or station path:**
   a. Parse the `system_map.yaml` content from step 2. Read the `bodies[]` list.
   b. Ask the user for body properties:
      - `orbital_radius`: float, distance from star (required)
      - `orbital_period`: float, animation period in arbitrary units (required; higher = slower)
      - `size`: float, visual size (required)
      - `color`: hex color (optional, e.g., `0x4682B4`)
      - `info.description`: short description string (optional)
      - `clickable`: boolean (default `true`)
      - `has_orbit_map`: boolean (default `true` for planets, `false` for stations)
   c. Build the bodies entry: `name`, `type`, `location_slug` (EXACT slug from step 4 — Pitfall P1),
      plus all user-supplied fields.
   d. Append the entry to `bodies[]`. Reconstruct full system_map.yaml preserving all existing
      fields (star, camera, existing bodies).
   e. Call `write_file("galaxy/<system>/system_map.yaml", updated_content)`.

   **moon path:**
   a. Attempt `read_file("galaxy/<system>/<planet>/orbit_map.yaml")`.
      If the file does not exist, build a new orbit_map.yaml scaffold:
      - Read the planet's `location.yaml` to get the planet name.
      - `planet` block: `name` (planet display name), `type: "planet"`, `size: 8.0`
      - `camera` block: `position: [0, 35, 58]`, `lookAt: [0, 0, 0]`, `fov: 60`
      - `moons: []`
   b. Ask the user for moon properties:
      - `orbital_radius`: float (required)
      - `orbital_period`: float (required; higher = slower)
      - `orbital_angle`: float in degrees (optional, default 0)
      - `inclination`: float in degrees (optional, default 0)
      - `size`: float (required)
      - `color`: hex color (optional)
      - `has_facilities`: boolean (default `false`)
      - `clickable`: boolean (default `false`)
   c. Build the moon entry: `name`, `location_slug` (EXACT slug from step 4), and all
      user-supplied fields.
   d. Append the entry to `moons[]`. Reconstruct full orbit_map.yaml preserving all existing
      fields (planet block, camera, existing moons).
   e. Call `write_file("galaxy/<system>/<planet>/orbit_map.yaml", updated_content)`.

7. Build the `location.yaml` content for the new body:
   Required fields: `name`, `type` (planet/moon/station), `parent_system` (the system slug),
   `status: "OPERATIONAL"`, `description`.
   For moons only: add `orbital_body` (parent planet display name).

8. Determine write path:
   - planet or station: `galaxy/<system>/<slug>/location.yaml`
   - moon: `galaxy/<system>/<planet>/<slug>/location.yaml`
   Call `write_file(path, content)`.

9. Confirm: list all files modified/written (system_map.yaml or orbit_map.yaml updated, plus
   the new location.yaml path). If user added a moon, include Pitfall P5 warning:
   "Note: moons are NOT valid body_slug targets for ship orbit injection. Only top-level
   planets (direct children of the system directory) can be used as body_slug values."
</process>
