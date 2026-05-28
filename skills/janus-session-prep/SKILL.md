---
name: janus-session-prep
description: "Compose a structured GM session brief from live game state plus persisted janus.yaml context files. Use when starting a session or refreshing situational awareness mid-game."
argument-hint: "[focus-area]"
allowed-tools:
  - mcp__JanusGM__get_session_context
  - mcp__JanusGM__list_files
  - mcp__JanusGM__read_file
---

@$HOME/.claude/janus-skills/resources/schema-janus-context.md

@$HOME/.claude/janus-skills/resources/schema-campaign.md

# /janus-session-prep

<objective>
Compose a structured Markdown GM brief by combining live game state from `get_session_context()`
with persisted `janus.yaml` context files and NPC data. This is a READ-ONLY skill — it does NOT
call `write_file` and produces no output files. The brief is printed directly to the chat for the
GM to reference at the table. No file writes occur.
</objective>

<process>
1. Parse the optional `$ARGUMENTS` focus-area. Recognised values:
   - `crew`: focus on crew status and NPC interactions
   - `current-location`: focus on location detail and janus.yaml context
   - `npc:<id>`: pull full data for one specific NPC only
   - (blank / default): produce a full general brief

2. Call `get_session_context()`. This returns the live game state: `active_view`, current
   location, encounter state (if any), ship status, recent message activity, and NPC roster.
   This is the primary data source — all other reads are keyed from its output.

3. Extract `current_location` from the session context. Derive the location path from it
   (e.g., `galaxy/anchor-system/veil-station`). Call
   `read_file("<location-path>/janus.yaml")` if a path is available — swallow any "not found"
   error silently (many locations will not have a janus.yaml yet).

4. For each NPC listed as present at the current location (from the session context NPC roster):
   call `read_file("campaign/npcs/<id>.yaml")` to fetch their full record. Cap at 5 NPCs — if
   more are present, read the first 5 and note the remaining names in the brief without detail.
   If focus-area is `npc:<id>`, skip this general pull and fetch ONLY the specified NPC record.

5. Optionally call `read_file("campaign/ship/location.yaml")` and/or
   `read_file("campaign/ship/ship.yaml")` to get the player ship's current status detail, if
   `active_view` or session context indicates ship data is relevant.

6. Compose the Markdown brief with these sections in this order:

   **## Active View**
   Current view type and any active encounter name.

   **## Current Location**
   Location name, type, and status from location.yaml summary. If a janus.yaml was found,
   include its full `context` body here verbatim.

   **## Ship Status**
   Player ship name, status, and current docking/orbit position if available.

   **## NPCs Present**
   For each fetched NPC: name, role, faction, status, and one-sentence description.
   If more than 5 NPCs were present, list remaining names under "Also present (no detail)".

   **## Open Threads**
   Derived from recent message activity or encounter state in the session context — list 2–4
   unresolved narrative threads the GM should be aware of.

   **## Suggested GM Beats**
   1–3 short prompts based on the synthesized context (LLM judgment, not data fetches). These
   are atmospheric suggestions to help the GM open the session — keep them terse and in-universe.

7. Print the complete brief to the chat. Do NOT call `write_file`. Do NOT save the brief to disk.
   The brief is ephemeral — re-run `/janus-session-prep` to refresh it at any point.
</process>
