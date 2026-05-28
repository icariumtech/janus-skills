---
name: janus-add-location
description: "Create a new galaxy location (station, planet, or moon) with its location.yaml. Use when adding a location to an existing star system."
argument-hint: "<location-name> [type] [parent-system]"
allowed-tools:
  - mcp__JanusGM__list_files
  - mcp__JanusGM__read_file
  - mcp__JanusGM__write_file
---

@$HOME/.claude/janus-skills/resources/schema-galaxy.md

# /janus-add-location

<objective>
Create a location directory and `location.yaml` file at
`data/galaxy/<parent-system>/<location-slug>/location.yaml` using the JANUS MCP server.
The slug must be lowercase + hyphens only — a case mismatch silently prevents the location
from appearing on system maps (Pitfall P1). Moons live one level deeper than planets — at
`data/galaxy/<system>/<planet-slug>/<moon-slug>/location.yaml` — so this skill prompts for
a parent planet when type=moon. Ships do NOT live under `galaxy/` at all; if type=ship, this
skill redirects to `/janus-add-ship` and aborts. All write operations go through the MCP server
which triggers a live SSE broadcast.
</objective>

<process>
1. Parse `$ARGUMENTS` for location name, optional type, and optional parent system slug.

2. Ask the user (or infer from args) for `type` — must be one of:
   `station | planet | moon | system | ship`.

   - If type is `system`: redirect the user to `/janus-add-system` and abort (that skill
     handles the full system scaffolding with star_map.yaml + system_map.yaml updates).
   - If type is `ship`: redirect the user to `/janus-add-ship` and abort. Ships are NOT
     stored under `data/galaxy/` — they live in `data/ships/<slug>/location.yaml` with a
     body_slug pointer that self-injects onto the orbit map at runtime.
   - If type is `moon`: prompt the user for a `parent_planet_slug` (the planet this moon
     orbits, written as a lowercase-hyphenated directory name under
     `data/galaxy/<parent-system>/`). The moon's `location.yaml` lives one level deeper
     than a planet's — at `galaxy/<parent-system>/<parent-planet-slug>/<moon-slug>/location.yaml`.
     Verify the parent planet exists by calling
     `list_files("galaxy/<parent-system>/<parent-planet-slug>")` — if the call fails or
     returns empty, refuse with: "Parent planet '<parent_planet_slug>' not found under
     system '<parent-system>'. Add the planet first via this skill before adding moons."
   - If type is `planet` or `station`: proceed without additional prompts. The location
     will live at `galaxy/<parent-system>/<location-slug>/location.yaml`.

3. Ask for the parent system directory name (the slug under `data/galaxy/`) unless already
   provided in arguments.

4. Call `list_files("galaxy/<parent-system>")` to enumerate sibling directory slugs and verify
   the parent system exists. If the MCP call fails or returns an empty/error response, the parent
   system does not exist — instruct the user to run `/janus-add-system` first and abort.

5. Derive the slug from the location name:
   - Convert to lowercase
   - Replace spaces and underscores with hyphens
   - Remove or replace any character not in `[a-z0-9-]`
   Formula: `name.lower().replace(" ", "-").replace("_", "-")`
   Examples: "Veil Station" → `veil-station`, "Tau Ceti e" → `tau-ceti-e`
   CRITICAL (Pitfall P1): The slug must be all lowercase with hyphens. A case mismatch silently
   prevents the location from appearing on the system map.

6. Check for slug collision against the sibling listing from step 4. If the slug already exists,
   append a numeric suffix (`-2`, `-3`, ...) and inform the user. For moons, the collision check
   operates against the planet's child listing (`list_files("galaxy/<parent-system>/<parent-planet-slug>")`),
   not the system's top-level listing.

7. Ask the user for required fields: `status` (e.g., `OPERATIONAL`) and `description`.
   Offer optional fields: `population`, `crew_capacity`, `established`, `orbital_body`,
   `orbital_position`. Include only the fields the user provides.

8. Build the `location.yaml` content. Required keys: `name`, `type`, `parent_system`
   (the system slug), `status`, `description`. Append optional keys only if provided.
   Use the location.yaml schema from the schema reference (quoted strings for free-text fields).

9. Build the write path based on type:
   - `planet | station`: `galaxy/<parent-system>/<location-slug>/location.yaml`
   - `moon`: `galaxy/<parent-system>/<parent-planet-slug>/<location-slug>/location.yaml`
     (one level deeper — moons sit under the planet they orbit)

   Call `write_file(<write-path>, content)`. Triggers the same SSE broadcast for both types.

10. Confirm to the user that the location directory was created with its `location.yaml`.
    Suggest follow-up: run `/janus-add-body` if this location should also appear as a body
    on the system map (i.e., it needs an entry in `system_map.yaml`), or `/janus-update-galaxy`
    to add travel routes or visual updates to the galaxy map.
</process>
