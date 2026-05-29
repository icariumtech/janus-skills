---
name: janus-player-ship
description: "Set up or reconfigure the player's ship at data/campaign/ship/. Covers identity (ship.yaml), systems, resources, cargo, and location.yaml. Use when starting a new campaign ship or updating ship systems mid-campaign."
argument-hint: "[ship-name]"
allowed-tools:
  - mcp__JanusGM__list_files
  - mcp__JanusGM__read_file
  - mcp__JanusGM__write_file
  - mcp__JanusGM__patch_yaml
  - mcp__JanusGM__read_field
---

@$HOME/.claude/janus-skills/resources/schema-ships.md

# /janus-player-ship

<objective>
Create or update the player's ship data at `data/campaign/ship/`. This is the GM's ship — the
vessel the players crew — which lives in `campaign/ship/` rather than `data/ships/` because it
carries mutable campaign state (system conditions, faults, resources). The skill covers three
files: `ship.yaml` (identity + systems), `location.yaml` (display name/status), and optionally
`deckplan.yaml` (encounter map stub). All writes go through the MCP server which triggers a live
SSE broadcast.
</objective>

<process>
1. Parse `$ARGUMENTS` for a ship name. If not provided, call
   `read_file("campaign/ship/ship.yaml")` to check if a ship already exists. If it does, ask the
   user whether they want to **reconfigure** the existing ship or **replace** it entirely. If no
   file exists yet, ask for the ship name before continuing.

2. Collect the following identity fields. Ask for all of them up front if creating fresh, or show
   current values and ask which to change if reconfiguring:
   - **name**: full display name (e.g. "USCSS Morrigan")
   - **slug**: lowercase, underscores only (derived from name if not supplied; e.g. `uscss_morrigan`)
   - **class**: ship class description (e.g. "Hargrave-Class Light Freighter")
   - **location_slug**: current location slug (e.g. `phoebe`, `tau-ceti-f`) — where the ship is docked/parked in the galaxy
   - **crew_capacity** / **crew_count**: integers

3. Collect ship **stats** (all integers, 0–20 scale typical):
   - `battle` — combat effectiveness
   - `systems` — electronics/computer
   - `thrusters` — speed/maneuverability

4. Collect **systems**. For each system, ask the user to describe it or accept a suggested default
   set. The systems dict key is a lowercase slug (e.g. `engines`, `comms`). Each system has:

   | Field | Type | Notes |
   |---|---|---|
   | `display_name` | string | Label shown in the UI |
   | `icon` | string | Lowercase icon name — see valid icons below |
   | `status` | enum | `ONLINE \| OFFLINE \| DAMAGED` |
   | `condition` | int 0–5 | Current health (0 = destroyed) |
   | `power.max` | int | Max power units this system can draw |
   | `power.allocated` | int | Currently allocated (default 0) |
   | `subsystems` | list[str] | Capability tiers shown in UI (e.g. `SHORT RANGE`, `THRUSTERS`) |
   | `warnings` | list[str] | Optional status warnings shown in UI |
   | `faults` | list[{label, active}] | Active mechanical faults; `active: true/false` |

   **Reactor** is special — it uses `power_capacity` (total power budget) instead of a `power` block:

   | Field | Notes |
   |---|---|
   | `power_capacity` | int — total power available to distribute across all other systems |
   | `condition` | int 0–5 |
   | `status` | `ONLINE \| OFFLINE \| DAMAGED` |
   | `warnings` | optional list |

   **Valid icon names** (use exactly as shown, lowercase):
   `intercom`, `jumpdrive`, `ventillation`, `medbay`, `reactor core`, `weapon system`,
   `sensors`, `cargo`, `armory`, `lab`, `factory`, `refinery`, `fuel`, `automed`,
   `cryo`, `docking bay`, `command`, `ai`, `workshop`

   Suggested default system set (adjust to fit the ship's class):
   - `reactor` — power plant
   - `engines` — thrusters + jump drive
   - `comms` — short/in-system/long range
   - `life_support` — minimal/nominal/medical/cryo
   - `weapons` — point defense through combat ready
   - `medbay` — diagnostics, tools, surgical bed

5. Collect **resources**. Each entry is a named dict under `resources:`:

   | Field | Notes |
   |---|---|
   | `display_name` | string — label shown in UI |
   | `current` | int |
   | `max` | int |
   | `info` | string — short descriptor (e.g. "Reactor feed", "Galley stock") |

   Common resources: `fuel`, `o2`, `food`, `cryopods`, `escape_pods`.

6. Collect **cargo** items. This is a simple list of strings under `cargo.items`. Ask the user to
   list items, or accept an empty list to fill in later.

7. Build the complete YAML and call `write_file("campaign/ship/ship.yaml", content)`.
   Field order: `slug`, `class`, `name`, `location_slug`, `crew_capacity`, `crew_count`, `stats`,
   `systems`, `resources`, `cargo`.

8. If `campaign/ship/location.yaml` does not exist or the user wants to update it, write a
   minimal entry:
   ```yaml
   name: "<ship name>"
   type: "ship"
   slug: "<ship slug>"
   status: "OPERATIONAL"
   ```
   Call `write_file("campaign/ship/location.yaml", content)`.

9. Ask the user if they want an empty **deckplan stub** at `campaign/ship/deckplan.yaml`. If yes,
   write:
   ```yaml
   decks:
     - id: main_deck
       name: Main Deck
       level: 1
       default: true
       unit_size: 30
       rooms: []
   ```
   The deckplan uses the same grid format as encounter maps (see `schema-encounters.md`). A real
   deckplan can be added later via the SVG conversion tool or manually.

10. Confirm to the user:
    - Files written: `campaign/ship/ship.yaml`, `campaign/ship/location.yaml`, and (if created) `campaign/ship/deckplan.yaml`
    - Ship slug must match across all three files
    - SSE broadcast fires automatically on each write; the terminal will reflect changes within seconds
    - To update a single system later, use `patch_yaml("campaign/ship/ship.yaml", {"systems": {"<key>": {"status": "OFFLINE"}}})` directly — no need to rerun this skill for minor edits
</process>
