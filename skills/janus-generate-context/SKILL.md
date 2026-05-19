---
name: janus-generate-context
description: "Read a location.yaml and write a sibling janus.yaml capturing the AI-curated GM context for that location. Core skill for the Obsidian→JANUS notes pipeline. Use when generating or refreshing a location's runtime context."
argument-hint: "<location-path> [notes-or-source-text]"
allowed-tools:
  - mcp__JanusGM__read_file
  - mcp__JanusGM__write_file
---

@$HOME/.claude/janus-skills/resources/schema-galaxy.md

@$HOME/.claude/janus-skills/resources/schema-janus-context.md

# /janus-generate-context

<objective>
Read `data/<location-path>/location.yaml` and write a sibling `data/<location-path>/janus.yaml`
containing an AI-curated GM context blob. The `janus.yaml` has exactly two top-level fields:
`generated` (ISO 8601 UTC timestamp) and `context` (YAML literal block with a terse, atmospheric
summary written in-character as a ship or station AI). The file is read at runtime by the JANUS
AI terminal and by `/janus-session-prep`. Write operations go through the MCP server and
automatically trigger an SSE broadcast — the JANUS terminal refreshes without a manual reload.
</objective>

<schema>
@$HOME/.claude/janus-skills/resources/schema-galaxy.md

@$HOME/.claude/janus-skills/resources/schema-janus-context.md
</schema>

<process>
1. Parse `$ARGUMENTS`:
   - `location-path`: path relative to `data/`, e.g., `galaxy/anchor-system/veil-station` or
     `ships/patrol_gunboat`. Required. Prompt the user if missing.
   - Optional notes blob: free-text from Obsidian export, clipboard content, or inline user
     input. This is the raw campaign notes the AI uses to synthesize the context.

2. Call `read_file("<location-path>/location.yaml")`. If the file is not found, abort with:
   "location.yaml not found at '<location-path>/location.yaml'. Check the path against
   data/galaxy/ or data/ships/ directories."

3. Parse the location.yaml fields: `name`, `type`, `status`, `description`, `population`,
   `crew_capacity`, `established`, and any other fields relevant to the context. These are the
   primary data inputs even when external notes are also provided.

4. Check for an existing janus.yaml: call `read_file("<location-path>/janus.yaml")` — swallow
   any "not found" error (it may not exist yet). If a prior janus.yaml IS found, display its
   `generated` timestamp and a truncated preview of its `context` body, then ask the user:
   "Overwrite entirely, or merge with prior context?" Accept their choice before proceeding.

5. Synthesize the context body. Write in-character as a ship or station AI — terse, technical,
   slightly atmospheric. Follow the structure from the canonical veil-station example:
   - **Header line**: `LOCATION NAME — BRIEF TYPE/CLASS DESCRIPTION` (ALL CAPS)
   - **Status line**: operational status, population (if applicable), capacity (if applicable)
   - **Established line**: founding date if present in location.yaml
   - **Operational paragraph**: 1–3 short paragraphs covering current function, campaign
     relevance, and any notable details from the provided notes. Stay under 200 words total.
   Use the notes blob (if provided) to add specifics not present in location.yaml.

6. Generate the `generated` timestamp: current UTC time in ISO 8601 format,
   e.g., `"2026-05-19T14:00:00Z"`.

7. Build the janus.yaml content string:
   ```yaml
   # AI-generated JANUS context for this location.
   # Written by the campaign AI agent from campaign notes.
   # Update via MCP write_file: <location-path>/janus.yaml
   generated: "<ISO-8601-timestamp>"

   context: |
     <synthesized context body>
   ```
   The `context:` field must use YAML literal block scalar (`|`) so newlines are preserved.

8. Call `write_file("<location-path>/janus.yaml", content)` to save the file. The SSE broadcast
   fires automatically and refreshes the JANUS terminal in any connected player or GM session.

9. Confirm to the user: output path (`<location-path>/janus.yaml`), the `generated` timestamp,
   and the approximate word count of the context body.
</process>
