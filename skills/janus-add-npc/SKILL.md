---
name: janus-add-npc
description: "Create a new NPC entry in data/campaign/npcs/. Use when adding an NPC, character, or contact to the campaign roster."
argument-hint: "<npc-name> [faction] [role]"
allowed-tools:
  - mcp__JanusGM__list_files
  - mcp__JanusGM__write_file
---

@$HOME/.claude/janus-skills/resources/schema-campaign.md

# /janus-add-npc

<objective>
Create a well-formed NPC YAML file at `data/campaign/npcs/<id>.yaml` using the JANUS MCP server.
The `id` field must EXACTLY equal the filename stem — this is enforced by the data loader and any
mismatch will cause the NPC to be silently skipped (Pitfall P2). All write operations go through
the MCP server which triggers a live SSE broadcast to connected terminals.
</objective>

<process>
1. Parse `$ARGUMENTS` for NPC name, and optional faction and role hints.

2. Call `list_files("campaign/npcs")` to enumerate existing NPC ids and avoid collision.

3. Derive `id`: convert name to lowercase, replace spaces and hyphens with underscores, then
   strip any character that is not `[a-z0-9_]`. This removes periods, apostrophes, accents,
   and other punctuation that would otherwise leak into the filename stem (Pitfall P2).
   Formula: `re.sub(r'[^a-z0-9_]', '', name.lower().replace(' ', '_').replace('-', '_'))`.
   Examples: "Captain Harrow" → `captain_harrow`, "Dr. Elena-Kim" → `dr_elena_kim`,
   "O'Malley" → `omalley`.
   If the derived id already exists in the listing, append a numeric suffix (`_2`, `_3`, ...)
   and warn the user that a suffix was added.
   CRITICAL (Pitfall P2): The `id:` field in the YAML must EXACTLY equal this derived id, which
   must EXACTLY equal the filename stem. A mismatch causes the character to be skipped on load.

4. Ask the user for any missing required fields: `faction`, `role`, `status`, `description`.
   `status` must be one of: `ACTIVE | INACTIVE | DECEASED | UNKNOWN`. Default to `ACTIVE` if
   the user confirms they want the NPC active; otherwise ask explicitly.

5. Ask the user whether this NPC is a **background NPC** (minimal) or a **combatant/significant NPC**
   (full stats). Background NPCs need only: `id`, `name`, `role`, `faction`, `status`, `description`.
   Full NPCs additionally need: `class`, `stats`, `saves`, `stress`, `health`, `wounds`, `armor`.

6. For combatant/significant NPCs, prompt for:
   - `class`: one of `Teamster | Scientist | Marine | Android`
   - `stats`: four integers (range 2–10, default 5 each)
     - `strength`, `speed`, `intellect`, `combat`
   - `saves`: three integers (range 0–99, percentage)
     - `sanity` (default 30), `fear` (default 40), `body` (default 40)
   - `stress`: integer, default 2
   - `health`: `current` and `max` (default `max: 10`, `current` equals `max`)
   - `wounds`: integer, default 0
   - `armor`: integer, default 0
   Also offer optional fields: `portrait` (image path), `background` (background occupation),
   `motivation` (character motivation).

7. Build the YAML string. Use double-quoted strings for all free-text fields (name, role, faction,
   description). Place `id:` as the first field — it must match the filename stem exactly (Pitfall P2).
   For background NPCs, output only the 6 required fields plus any provided optionals.
   For combatant NPCs, include the full stats/saves/health block.

8. Call `write_file("campaign/npcs/<id>.yaml", content)` where `<id>` is the derived id from step 3.

9. Confirm to the user: report the written path (`campaign/npcs/<id>.yaml`), any fields that were
   defaulted, and any id suffix that was appended.
</process>
