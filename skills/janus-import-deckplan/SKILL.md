---
name: janus-import-deckplan
description: "Import an SVG deckplan for a ship or location. Converts the SVG via svg_to_map.py, then writes or appends a deck entry to deckplan.yaml. Use when adding one or more decks from Inkscape SVG files."
argument-hint: "<location-path> [deck-name] [grid-scale]"
allowed-tools:
  - mcp__JanusGM__upload_svg_map
  - mcp__JanusGM__read_file
  - mcp__JanusGM__write_file
  - mcp__JanusGM__list_files
---

@$HOME/.claude/janus-skills/resources/schema-encounters.md

# /janus-import-deckplan

<objective>
Convert an Inkscape SVG deckplan file into a JANUS deckplan entry and write it to the correct
`deckplan.yaml` under the target ship or location. Supports both creating a fresh `deckplan.yaml`
and appending a new deck to an existing one. The SVG is uploaded via the JANUS MCP server
(which runs `svg_to_map.py`), the generated legacy deck YAML is read back, and the result is
folded into the canonical `deckplan.yaml` format (a single file with a `decks:` list).

Always write the new `deckplan.yaml` format. Never write the legacy `map/manifest.yaml` format.
</objective>

<svg-requirements>
The SVG must be an Inkscape file with the following layer structure (layers identified by
`inkscape:label`, NOT the SVG `id` attribute):

- **Rooms** layer — one `<path>` per room; each path's `inkscape:label` = the room name
  (e.g. `"Engine Room"`). This becomes the room's display name and its slug id.
- **Corridors** layer — one `<path>` per corridor; `inkscape:label` is optional (auto-named
  `corridor_1`, `corridor_2`, … if absent).
- **Hull** layer — optional single path for the hull outline.

Label paths via **Object Properties → Label** in Inkscape (not the XML `id` field).
The label controls what appears in the JANUS map. An unlabelled room in the Rooms layer
gets a generic id and name — warn the user if this happens (visible in the conversion log).

Grid unit is read from the `inkscape:grid spacingx` attribute. The SVG must have a grid
configured (File → Document Properties → Grids → add a rectangular grid).
</svg-requirements>

<process>
## Step 1 — Gather inputs

Parse `$ARGUMENTS` for location path (first token), optional deck name (remaining tokens),
and optional `grid_scale` if the user wrote it as a number at the end.

Ask for anything not supplied:

1. **Location path** (relative to `data/`) — the directory of the ship or location:
   - Ship: `ships/<ship-slug>` (e.g. `ships/patrol_gunboat`)
   - Galaxy location: `galaxy/<system>/<body>/<slug>` (e.g. `galaxy/tau-ceti/tau-ceti-f/somnus`)
   - Player ship: `campaign/ship`

2. **Deck name** — human-readable display name (e.g. `"Main Deck"`, `"Lower Deck"`, `"Cargo Hold"`).
   Derive `deck_id` as snake_case: `"Main Deck"` → `main_deck`.

3. **Deck level** — integer sort key; 1 = lowest deck. If appending to an existing deckplan,
   suggest the next unused level (existing max + 1).

4. **SVG file path** — absolute or `~/`-prefixed path on the local machine.

5. **grid_scale** (default 1) — number of Inkscape grid cells to group into one output cell.
   Explain: start with 1; after seeing the conversion log, adjust if rooms are too large or small.
   Target: largest room should be roughly 8–12 cells wide.

6. **detect_doors** (default false) — whether to auto-detect doors from shared SVG edges.
   Mention: works best for clean polygon rooms with no overlapping geometry.

## Step 2 — Validate the location

Call `list_files("<parent-of-location-path>")` to verify the location directory exists.
For example, for `ships/patrol_gunboat` call `list_files("ships")` and confirm
`patrol_gunboat` is present.

If the location doesn't exist, stop and tell the user:
> "Location '<path>' not found. Run `/janus-add-ship` or `/janus-add-location` first,
> or check that the path is correct."

## Step 3 — Check for existing deckplan

Call `read_file("<location-path>/deckplan.yaml")`.

- **File not found → create mode**: a fresh `deckplan.yaml` will be written with this deck
  as the only entry. It will be marked `default: true`.
- **File found → append mode**: the new deck will be added to the existing `decks:` list.
  Read the current decks to find the next available level and confirm no `id` collision.
  If a deck with the same `deck_id` already exists, stop and ask the user to choose a
  different deck name.

## Step 4 — Read and base64-encode the SVG

Read the SVG file from the local path the user provided. Base64-encode its contents.
For files larger than ~500 KB, warn the user that the MCP upload may be slow and suggest
using curl directly:
```
curl -X POST http://<server>/api/gm/upload-svg-map/ \
  -F file=@<path-to-svg> \
  -F out_dir=<location-path> \
  -F deck=<deck_id> \
  -F grid_scale=<N>
```

## Step 5 — Upload and convert

Call `upload_svg_map` with:
- `filename`: the SVG filename (basename only, e.g. `patrol_gunboat.svg`)
- `content_base64`: the base64-encoded SVG bytes
- `out_dir`: the location path (e.g. `ships/patrol_gunboat`)
- `deck`: the `deck_id`
- `unit_size`: 30 (default — controls rendered pixel size, not cell counts)
- `grid_scale`: as specified
- `detect_doors`: as specified

Print the `log` field from the response so the user can see room dimensions.

## Step 6 — Evaluate the conversion log

Read the log output for lines like:
```
  Room 'engine room': 6 vertices  (8.0×5.5 cells)
```

Evaluate: find the widest room in the log.
- **Widest room > 20 cells**: grid_scale is too low. Suggest `grid_scale = ceil(widest / 10)`.
- **Widest room < 4 cells**: grid_scale may be too high, or the SVG grid is fine-grained.
- **Widest room 6–14 cells**: good range — proceed.

If adjustment is recommended, ask the user to confirm the new grid_scale, then re-run
`upload_svg_map` with the updated value before continuing. The re-upload overwrites the
previous intermediate files.

## Step 7 — Read the generated deck YAML

The conversion writes a legacy-format deck file at `<location-path>/map/<deck_id>.yaml`.
Call `read_file("<location-path>/map/<deck_id>.yaml")` to retrieve it.

Extract from it:
- `unit_size` — integer
- `rooms` — the full list of room entries
- `doors` — the list of door entries (may be absent or commented-out if `detect_doors` was false)

## Step 8 — Build the deckplan.yaml

Construct a deck entry in the new format:

```yaml
- id: <deck_id>
  name: "<Deck Name>"
  level: <level>
  default: <true if this is the only/first deck, else false>
  unit_size: <unit_size>
  rooms:
    <rooms from step 7>
  doors:
    <doors from step 7, omit key if empty>
```

**Create mode**: build a full `deckplan.yaml`:
```yaml
decks:
  - id: <deck_id>
    name: "<Deck Name>"
    level: 1
    default: true
    unit_size: <unit_size>
    rooms:
      ...
```

**Append mode**: parse the existing `deckplan.yaml`, add the new deck entry to the `decks:`
list (insert in ascending `level` order), and reconstruct the full file. Preserve all existing
deck entries exactly — only append, never modify existing decks.

## Step 9 — Write deckplan.yaml

Call `write_file("<location-path>/deckplan.yaml", <full yaml content>)`.

Use the canonical format from schema-encounters.md. Do not write to `map/` — that is the
legacy format and is never written by skills.

## Step 10 — Confirm

Report to the user:
- Written path: `<location-path>/deckplan.yaml`
- Deck added: `<deck_id>` — `<Deck Name>` (level <N>)
- Room count and corridor count
- Whether doors were auto-detected
- If more decks need to be imported: remind them to run `/janus-import-deckplan` again
  with the same location path and the next deck's SVG file

Note: The intermediate files in `<location-path>/map/` are conversion artifacts and can
be deleted, but leaving them is harmless — they are not loaded by EncounterMapDisplay.
</process>
