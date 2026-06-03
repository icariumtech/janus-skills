---
name: janus-import-deckplan
description: "Import an SVG deckplan for a ship or location. Converts the SVG via svg_to_map.py, then writes or appends deck entries to deckplan.yaml. A single multi-deck SVG can populate all decks at once."
argument-hint: "<location-path> [grid-scale]"
allowed-tools:
  - mcp__JanusGM__upload_svg_map
  - mcp__JanusGM__read_file
  - mcp__JanusGM__write_file
  - mcp__JanusGM__list_files
---

@$HOME/.claude/janus-skills/resources/schema-encounters.md

# /janus-import-deckplan

<objective>
Convert an Inkscape SVG deckplan file into JANUS deckplan entries and write them to the correct
`deckplan.yaml` under the target ship or location. Supports both creating a fresh `deckplan.yaml`
and appending new decks to an existing one. The SVG is uploaded via the JANUS MCP server
(which runs `svg_to_map.py`), the generated deck YAML(s) are read back, and the result is
folded into the canonical `deckplan.yaml` format (a single file with a `decks:` list).

A single SVG may produce one deck (single-deck mode) or multiple decks (multi-deck mode) —
the mode is auto-detected from the SVG layer structure. Always write the new `deckplan.yaml`
format. Never write the legacy `map/manifest.yaml` format.
</objective>

<svg-requirements>
The SVG must be an Inkscape file. Layers are identified by `inkscape:label` (set via
**Object Properties → Label** in Inkscape — NOT the XML `id` field).

The SVG must have a rectangular grid configured (File → Document Properties → Grids).

**Single-deck SVG** (flat layers):
- **Rooms** layer — one `<path>` per room; `inkscape:label` = room name (e.g. `"Engine Room"`)
- **Corridors** layer — one `<path>` per corridor; label optional (auto-named `corridor_1`, …)
- **Hull** layer — optional single path for the hull outline

**Multi-deck SVG** (nested layers — auto-detected):
- **Hull** layer — optional top-level hull outline
- **`<Deck Label>`** layer — one per deck (e.g. `"Main Deck"`, `"Engineering Deck"`, `"Bridge"`)
  - **Rooms** sublayer — room paths within this deck
  - **Corridors** sublayer — corridor paths within this deck
- Additional deck layers follow the same pattern

Multi-deck mode is triggered automatically when any top-level layer contains `Rooms` or
`Corridors` sublayers. Deck IDs and names are derived from the layer labels (snake-cased).
The first deck layer in document order becomes the default deck.

Warn the user if any room path lacks a label — it will get a generic id/name in the output.
</svg-requirements>

<process>
## Step 1 — Gather inputs

Parse `$ARGUMENTS` for location path (first token) and optional `grid_scale` (a number).

Ask for anything not supplied:

1. **Location path** (relative to `data/`) — the directory of the ship or location:
   - Ship: `ships/<ship-slug>` (e.g. `ships/patrol_gunboat`)
   - Galaxy location: `galaxy/<system>/<body>/<slug>` (e.g. `galaxy/tau-ceti/tau-ceti-f/somnus`)
   - Player ship: `campaign/ship`

2. **SVG file path** — absolute or `~/`-prefixed path on the local machine.

3. **grid_scale** (default 1) — number of Inkscape grid cells to group into one output cell.
   Explain: start with 1; after seeing the conversion log, adjust if rooms are too large or small.
   Target: largest room should be roughly 8–12 cells wide.

4. **detect_doors** (default false) — whether to auto-detect doors from shared SVG edges.
   Mention: works best for clean polygon rooms with no overlapping geometry.

For **single-deck SVGs only**, also ask:
5. **Deck name** — human-readable display name (e.g. `"Main Deck"`, `"Lower Deck"`).
   Derive `deck_id` as snake_case. If the user doesn't know their SVG type yet, skip this
   for now — you can determine the deck name from the manifest after conversion.

6. **Deck level** — integer sort key; 1 = lowest deck. If appending to an existing deckplan,
   suggest the next unused level (existing max + 1). Skip for multi-deck SVGs (levels are
   assigned automatically by document order, starting after any existing decks).

## Step 2 — Validate the location

Call `list_files("<parent-of-location-path>")` to verify the location directory exists.
For example, for `ships/patrol_gunboat` call `list_files("ships")` and confirm
`patrol_gunboat` is present.

If the location doesn't exist, stop and tell the user:
> "Location '<path>' not found. Run `/janus-add-ship` or `/janus-add-location` first,
> or check that the path is correct."

## Step 3 — Check for existing deckplan

Call `read_file("<location-path>/deckplan.yaml")`.

- **File not found → create mode**: a fresh `deckplan.yaml` will be written.
  The first deck (or the only deck) will be marked `default: true` and assigned `level: 1`.
- **File found → append mode**: new decks will be added to the existing `decks:` list.
  Read the current decks to find the next available level. Confirm no `id` collisions —
  if any incoming deck id already exists, stop and ask the user to resolve it (rename the
  SVG layer or choose a different location path).

## Step 4 — Read and base64-encode the SVG

Read the SVG file from the local path the user provided. Base64-encode its contents.
For files larger than ~500 KB, warn the user that the MCP upload may be slow and suggest
using curl directly:
```
curl -X POST http://<server>/api/gm/upload-svg-map/ \
  -F file=@<path-to-svg> \
  -F out_dir=<location-path> \
  -F grid_scale=<N>
```

## Step 5 — Upload and convert

Call `upload_svg_map` with:
- `filename`: the SVG filename (basename only, e.g. `patrol_gunboat.svg`)
- `content_base64`: the base64-encoded SVG bytes
- `out_dir`: the location path (e.g. `ships/patrol_gunboat`)
- `deck`: the `deck_id` (used only in single-deck mode; ignored for multi-deck SVGs)
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

## Step 7 — Read the generated deckplan

Call `read_file("<location-path>/deckplan.yaml")`.

The conversion always writes a complete `deckplan.yaml` in canonical format — one file
containing all decks regardless of single- or multi-deck mode. Extract the full `decks:`
list from it. Deck ids and names for multi-deck SVGs come from the SVG layer labels and
are already in the file; no additional input is needed from the user.

## Step 8 — Build the deckplan.yaml

For each deck (in manifest order for multi-deck; the single deck otherwise), construct an entry:

```yaml
- id: <deck_id>
  name: "<Deck Name>"
  level: <level>
  default: <true for first/only deck, false otherwise>
  unit_size: <unit_size>
  rooms:
    <rooms from step 7>
  doors:
    <doors from step 7, omit key if empty>
```

**Level assignment:**
- Create mode: start at 1 and increment per deck (in manifest order).
- Append mode: start at (existing max level + 1) and increment.

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

**Append mode**: parse the existing `deckplan.yaml`, add the new deck entry (or entries)
to the `decks:` list in ascending `level` order, and reconstruct the full file.
Preserve all existing deck entries exactly — only append, never modify existing decks.

## Step 9 — Write deckplan.yaml

Call `write_file("<location-path>/deckplan.yaml", <full yaml content>)`.

Use the canonical format from schema-encounters.md. Do not write to `map/` — that is the
legacy format and is never written by skills.

## Step 10 — Confirm

Report to the user:
- Written path: `<location-path>/deckplan.yaml`
- For each deck added: `<deck_id>` — `<Deck Name>` (level <N>), room count, corridor count
- Whether doors were auto-detected
- The SVG file saved at `<location-path>/<filename>.svg` is kept for future re-conversion
</process>
