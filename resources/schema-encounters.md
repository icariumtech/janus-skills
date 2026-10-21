# Encounter / Deckplan Schema Reference

All MCP paths are relative to `data/`. Slash convention: forward-slash only, no leading slash.

---

## Purpose

Deckplan YAML describes grid-based interior maps used by `EncounterMapDisplay`. Optional for
any location. When present, the GM Console renders a tactical encounter map with rooms, doors,
and POIs. A single `deckplan.yaml` holds all decks for a location.

---

## MCP Path Conventions

Deckplans live under the location they describe:

| Location type | MCP path |
|---|---|
| Mobile ship | `ships/<ship-slug>/deckplan.yaml` |
| Galaxy location | `galaxy/<system>/<body>/<slug>/deckplan.yaml` |
| Player ship | `campaign/ship/deckplan.yaml` |

The legacy `map/manifest.yaml` + per-deck `map/*.yaml` format was removed in Phase 29. All
locations must use `deckplan.yaml`. Skills should write `deckplan.yaml` only.

MCP write: `write_file("ships/patrol_gunboat/deckplan.yaml", content)`

### Editing a single element (preferred for small changes)

To change one room, corridor, or door — or to add/remove a POI — use the targeted tools instead
of rewriting the whole file. They edit server-side, so you never load the entire deckplan.

- `find_map_element(deckplan, query)` → candidate elements `[{id, kind, label, deck}]`. Use to
  disambiguate. `query` may be an id, a room/corridor name, or a glob (`coolant_tanks*`).
- `edit_map_element(deckplan, target, set | add_poi | remove_poi)` → edits the one element that
  `target` resolves to. Provide exactly one operation per call.

```text
edit_map_element(dp, "mess_hall", add_poi={icon: airlock, label: Airlock, position: {x: 1, y: 1}})
edit_map_element(dp, "coolant_tanks", set={label_offset: [0, 2]})   # 409 w/ candidates if >1 -> ask the GM
edit_map_element(dp, "mess_hall__main_corridor__0", set={status: LOCKED})   # a door
```

Element ids: rooms/corridors use their slug id (`mess_hall`, `main_corridor`); colliding names get
a numeric suffix (`coolant_tanks`, `coolant_tanks_2`). Doors are addressed by the derived id
`<roomA>__<roomB>__<index>` (or `<room>__exterior__<index>` for an exterior door) — the same id used
for door-status. POIs are reached through their room (`add_poi`/`remove_poi`), never targeted directly.

**P-edit — Do NOT `read_file` + `write_file` to change one element.** That reloads the whole
deckplan for a one-field edit. Use `edit_map_element`; if the reference is ambiguous it returns the
candidates so you can ask the GM which one.

---

## Top-level Fields

| Field | Type | Required | Note |
|---|---|---|---|
| `hull` | mapping | no | Shared/manifest hull outline — see **Hull fields** below |
| `decks` | list | yes | List of deck entries |
| `default_view` | mapping | no | Location-level initial map view applied when the GM loads this location - see the `default_view` table below |

### Hull fields

A hull mapping (top-level or per-deck, see below) accepts:

| Field | Type | Required | Note |
|---|---|---|---|
| `polygon` | list | no | Single outer polygon: `[[x,y],...]` in grid cells |
| `polygons` | list | no | Multiple disjoint outer polygons: `[[[x,y],...],...]` — pods, nacelles, detached modules |
| `holes` | list | no | Polygons subtracted from the hull fill via SVG fill-rule evenodd; not paired to any specific outer polygon |

`polygon` and `polygons` may both appear on the same hull — they combine into one polygon list
(shared silhouette + disjoint modules). At least one of `polygon`/`polygons` must be present for
the hull to render.

### Default view fields

Optional `default_view` mapping at the location root (next to `decks:`) sets the initial map view:

| Field | Type | Required | Note |
|---|---|---|---|
| `projection` | enum | no | `top-down` or `iso`. Default `top-down` |
| `rotation_offset` | integer | no | `0`, `90`, `180` or `270` degrees. Default `0`. A relative turn added on top of every deck's `rotation`; positive turns the ship clockwise on screen |

Applied once when the GM loads a different location; NOT re-applied on deck switches or when the GM
leaves and re-enters the same location. After that the GM controls the view live and every player
follows. An invalid value falls back to its default for that field only and is logged - it never
blocks the location from loading.

```yaml
default_view: {projection: iso, rotation_offset: 90}
decks:
  - id: main_deck
    ...
```

### Deck entry fields

| Field | Type | Required | Note |
|---|---|---|---|
| `id` | string | yes | Unique deck identifier |
| `name` | string | yes | Display name |
| `level` | integer | yes | Sort key — 1 = lowest deck |
| `default` | boolean | no | First deck shown on load |
| `rotation` | integer | no | Absolute authored orientation of this deck in degrees: 0 (default), 90, 180 or 270. Top-down: the drawing is rotated on screen. Isometric: folded into the grid angle so floors keep true 30-degree axes. Different from `default_view.rotation_offset` - see P3 |
| `unit_size` | integer | no | Pixels per grid cell. Renderer falls back to 40 when omitted; tools (svg_to_map.py, upload_svg_map, janus-skills) write 30 explicitly - keep writing it explicitly |
| `hull` | mapping | no | Deck-level hull (same shape as top-level, see **Hull fields**) — renders **in addition to** the top-level hull. The top-level hull is the shared silhouette drawn on every deck; a deck hull only adds geometry (pods, nacelles), it never replaces or shrinks the shared outline. |
| `rooms` | list | yes | List of room entries (see GridRoom fields) |
| `doors` | list | no | Top-level door definitions (see Door fields) |
| `vents` | list | no | Ventilation path definitions (see Vent fields) |
| `details` | list | no | Decorative detail linework (see Detail Fields) |

---

## GridRoom Fields

Each room entry in the `rooms:` list.

| Field | Type | Required | Note |
|---|---|---|---|
| `id` | string | yes | Unique within this deck |
| `name` | string | no | Display label — empty string suppresses label; `\n` (in a double-quoted YAML string, e.g. `"CAPTAIN'S\nQUARTERS"`) renders as a line break on the map |
| `type` | string | no | `"corridor"` skips label rendering |
| `rects` | list | shape | Rectangle(s) — see rect fields |
| `polygon` | list | shape | Freeform vertices: `[[x,y], ...]` in grid cells |
| `circle` | mapping | shape | Circular room: `{cx, cy, r}` in grid cells |
| `poi` | list | no | Points of interest (see POI fields) |

Exactly one of `rects`, `polygon`, or `circle` must be present (shape field).

### Rect entry fields

| Field | Type | Note |
|---|---|---|
| `x` | float | Top-left cell, 0-based |
| `y` | float | Top-left cell, 0-based |
| `w` | float | Width in grid cells |
| `h` | float | Height in grid cells |
| `chamfer` | float | Optional — diagonal corner cut in grid-cell units |

### Circle entry fields

| Field | Type | Note |
|---|---|---|
| `cx` | float | Center X in grid cells |
| `cy` | float | Center Y in grid cells |
| `r` | float | Radius in grid cells |

---

## Door Fields

Doors are a **top-level `doors:` array on the deck** (same indent level as `rooms:`).
Each door names the two rooms it connects.

Two authored forms are supported:

### B-rel (relational form — preferred)

| Field | Type | Required | Note |
|---|---|---|---|
| `rooms` | list | yes | Two room ids sharing an edge; one-element list = exterior door |
| `along` | float | no | Fraction 0..1 along shared edge (default 0.5 = centre) |
| `width` | float | no | Door width in grid cells (default 1) |
| `type` | enum | no | `standard \| blast_door \| airlock \| emergency \| open` |
| `status` | enum | no | `OPEN \| CLOSED \| LOCKED \| SEALED \| DAMAGED \| BROKEN` |
| `id` | string | no | Explicit stable id; auto-derived if omitted |

### B-pos (position-override form)

Use when two rooms share multiple disjoint edges, or for polygon/circle rooms where
the relational form is ambiguous.

| Field | Type | Required | Note |
|---|---|---|---|
| `rooms` | list | yes | Two room ids (or one for exterior) |
| `position` | mapping | yes | `{x, y, angle}` — door center in grid coords |
| `type` | enum | no | Same enum as B-rel |
| `status` | enum | no | Same enum as B-rel |

**Position fields:**

| Field | Note |
|---|---|
| `x` | Door center X in grid cells |
| `y` | Door center Y in grid cells |
| `angle` | `0` = horizontal slot (N/S wall), `90` = vertical slot (E/W wall) |

**Door id format:** Auto-derived as `${room.id}_door_${index}` when no explicit `id:` is given.
Explicit `id:` is recommended for stable runtime door-state references.

**Door status enum:** `OPEN | CLOSED | LOCKED | SEALED | DAMAGED | BROKEN`

> `BROKEN` is a legacy alias for `DAMAGED` preserved from pre-Phase 21 maps. Use `DAMAGED` for new maps.

---

## POI Fields

POIs are entries in a room's `poi:` list. The backend auto-generates `id`, `room`, and
`position` fields from the parent room, so only `icon` is required.

| Field | Type | Required | Note |
|---|---|---|---|
| `icon` | string | yes | Lowercase name matching SVG filename prefix (see icons below) |
| `label` | string | no | Display name — shown in hover popover |
| `type` | enum | no | Controls icon color; default `item` (see types below) |
| `position` | mapping | no | `{x, y}` grid coords; omit to center on room |
| `description` | string | no | Extra detail shown in hover popover |

**POI type values and colors:**

| Type | Color | Use for |
|---|---|---|
| `item` | teal | Equipment, fixtures, objects (default) |
| `objective` | amber | Mission targets, key locations |
| `hazard` | red | Dangers, environmental threats |
| `npc` | teal | NPC markers |
| `player` | teal | Player markers |

**P3 - deck rotation and default_view.rotation_offset are different things.** A deck's `rotation`
is the absolute authored orientation of that deck (for example 90 for a ship drawn sideways).
`default_view.rotation_offset` is a relative turn for the initial GM view. To re-orient a deck, edit
its `rotation`, not the offset. Both are clockwise-positive degrees.

**P2 — Do not create `map/manifest.yaml` or per-deck `map/*.yaml` files.** The legacy
`map/` directory format was removed in Phase 29. The loaders `load_map`,
`load_encounter_manifest`, and `load_deck_map` no longer exist. Write `deckplan.yaml`
only — all decks inline in a single file.

**P1 — Use plain ASCII in YAML string values.** Em-dashes (`—`), curly quotes (`""`), and
backslash-escaped quotes (`\"`) inside YAML double-quoted strings cause MCP `write_file`
to fail with `-32602`. Use hyphens (`-`) and straight quotes instead. Markdown bodies
(`.md` files) tolerate Unicode fine; this restriction applies to `.yaml` files only.

### Available POI icon names

`ai`, `airlock`, `armory`, `automed`, `cabin`, `cargo`, `command`, `cryo`, `docking bay`,
`door`, `door security level 1`, `door security level 2`, `door security level 3`,
`duct access`, `elevator`, `elevator to bottom`, `elevator to top`, `emergency capsule`,
`exit`, `factory`, `fuel`, `full`, `galley`, `intercom`, `jumpdrive`, `lab`, `ladder`,
`ladder bottom`, `ladder top`, `laser`, `medbay`, `ramp`, `reactor core`, `refinery`,
`sensors`, `shower`, `space colony`, `space ship`, `space station`, `supplies`, `terminal`,
`toilet`, `toilets 2`, `vac suit`, `vault`, `ventillation`, `weapon system`, `workshop`, `empty`, `0`

> Note: `ventillation` has double-L — matches the source SVG filename exactly.

---

## Vent Fields

Vents are entries in the deck-level `vents:` list. Each vent is a multi-segment
polyline (ventilation shaft route) that the GM can reveal or hide individually.
Hidden by default — players only see a vent after the GM right-clicks it and
chooses "Reveal to players."

| Field | Type | Required | Note |
|---|---|---|---|
| `id` | string | yes | Unique within this deck |
| `points` | list | yes | `[[x,y], ...]` polyline vertices in grid cell coords |
| `label` | string | no | Display name shown in the GM right-click menu |

**SVG layer:** `Vents` sublayer within each deck layer (multi-deck) or top-level
`Vents` layer (single-deck). Each path = one vent; `inkscape:label` → label + id.
Generated by `svg_to_map.py` automatically when the layer is present.

---

## Detail Fields

Details are entries in the deck-level `details:` list — decorative linework
(consoles, beds, furniture, machinery blocks, hull greebles) drawn in one fixed
blueprint-grade renderer style. Each entry is a polyline or a circle in grid-cell
units.

| Field | Type | Required | Note |
|---|---|---|---|
| `id` | string | no | Optional — only needed for future editor/AI targeting |
| `room` | string | no | When present the entry is INTERIOR: players see it only once that room is revealed by the GM. When absent the entry is EXTERIOR: always visible regardless of any room's reveal state |
| `points` | list | one of | `[[x,y], ...]` polyline vertices in grid cells |
| `closed` | boolean | no | Closes the polyline into a shape |
| `circle` | mapping | one of | `{cx, cy, r}` in grid cells |
| `filled` | boolean | no | Faint fill for closed shapes only (a `closed` polyline or a circle) |

Exactly one of `points` or `circle` must be present. There are no styling fields —
stroke color and width are fixed in the renderer for a consistent blueprint look;
`filled` is the only appearance flag the format accepts.

A `room:` value matching no room on the deck renders nothing for players (fail-safe)
and is shown only to the GM, with a console warning naming the unknown room id.

**SVG layer:** `Details` sublayer within each deck layer. Phase 32's `svg_to_map.py`
emits these entries from an Inkscape "Details" sublayer, flattening curves into
polyline segments.

A detail's room association uses its first vertex (or, for a circle detail, its
center) as the authored probe position, tested with the same smallest-containing-room
tie-break rule used for door-to-room adjacency. Details without an `inkscape:label`
get an auto-generated id (`detail_1`, `detail_2`, ...), matching the Vents convention.

---

## Corridor Fields

Corridors are rooms with `type: corridor`. Define them in the `rooms:` array:

| Field | Type | Note |
|---|---|---|
| `id` | string | Auto-generated `corridor_N` allowed (from svg_to_map.py output) |
| `rects` | list | Same rect format as GridRoom |
| `type` | string | Set to `"corridor"` to suppress label |

Doors connecting corridors to other rooms are defined in the top-level `doors:` array.

---

## Tooling Note

`tools/svg_to_map.py` (in the janus-console repo) generates deckplan YAML files from Inkscape SVGs.
Key flags: `--detect-doors` (outputs B-pos door entries from shared SVG edges),
`--grid-scale N` (groups N Inkscape grid cells into 1 output cell),
`--unit-size N` (pixels per output cell, default 30).

**SVG layer conventions:**

Single-deck (flat layers — backwards compatible):
- `Hull` — optional hull outline path
- `Rooms` — one `<path>` per room; `inkscape:label` = room name. A `<circle>`, a true
  `<ellipse>` (rx == ry), or an Inkscape-native `sodipodi:type="arc"` path inside
  Rooms/Corridors becomes a `circle` room/corridor. An ellipse that is not circular
  (rx != ry) is rejected with a stderr warning — never approximated; fix the shape in
  Inkscape. Circle rooms/corridors do not currently participate in polygon-based
  door-to-room adjacency (auto door-detection and doors-layer room association can only
  edge-test/contain-test polygons) — author doors touching a circle room manually via the
  Doors layer.
- `Corridors` — one `<path>` per corridor. A `<circle>`, a true `<ellipse>` (rx == ry), or an
  Inkscape-native `sodipodi:type="arc"` path inside Rooms/Corridors becomes a `circle`
  room/corridor. An ellipse that is not circular (rx != ry) is rejected with a stderr
  warning — never approximated; fix the shape in Inkscape. Circle rooms/corridors do not
  currently participate in polygon-based door-to-room adjacency (auto door-detection and
  doors-layer room association can only edge-test/contain-test polygons) — author doors
  touching a circle room manually via the Doors layer.
- `Vents` — optional; one `<path>` per vent route; `inkscape:label` = vent name

Multi-deck (nested layers — auto-detected):

Per-deck `Hull` and `Details` sublayers only apply in multi-deck mode — single-deck SVGs use
only the existing top-level Hull layer; there is no per-deck equivalent when there is only one
deck.

- `Hull` — optional hull outline path (top-level)
- `<Deck Label>` — one layer per deck (e.g. `"Main Deck"`, `"Engineering Deck"`)
  - `Rooms` — room paths within this deck. A `<circle>`, a true `<ellipse>` (rx == ry), or an
    Inkscape-native `sodipodi:type="arc"` path inside Rooms/Corridors becomes a `circle`
    room/corridor. An ellipse that is not circular (rx != ry) is rejected with a stderr
    warning — never approximated; fix the shape in Inkscape. Circle rooms/corridors do not
    currently participate in polygon-based door-to-room adjacency (auto door-detection and
    doors-layer room association can only edge-test/contain-test polygons) — author doors
    touching a circle room manually via the Doors layer.
  - `Corridors` — corridor paths within this deck. A `<circle>`, a true `<ellipse>` (rx ==
    ry), or an Inkscape-native `sodipodi:type="arc"` path inside Rooms/Corridors becomes a
    `circle` room/corridor. An ellipse that is not circular (rx != ry) is rejected with a
    stderr warning — never approximated; fix the shape in Inkscape. Circle rooms/corridors
    do not currently participate in polygon-based door-to-room adjacency (auto
    door-detection and doors-layer room association can only edge-test/contain-test
    polygons) — author doors
    touching a circle room manually via the Doors layer.
  - `Hull` — optional per-deck hull sublayer (pods, nacelles, detached modules); adds to,
    never replaces, the top-level hull
  - `Vents` — optional vent routes within this deck
  - Details — optional per-deck sublayer for decorative linework (consoles, beds, hull
    greebles); each item becomes interior (room-gated reveal) or exterior (always visible)
    based on geometric containment against the deck's rooms

Multi-deck is triggered automatically when any top-level layer contains `Rooms` or `Corridors`
sublayers. The deck layer label becomes the deck `id` (snake-cased) and `name`. All decks are
written to a single `deckplan.yaml` at the location root. The first deck gets `default: true`.
The `--deck` flag is only used in single-deck mode.

The MCP `upload_svg_map` tool and `/janus-import-deckplan` skill both support multi-deck SVGs —
a single upload/import can populate all decks at once. On upload, the original SVG is stored in
`campaign/images/sources/<filename>` (alongside portrait sources) for future re-conversion, while
the generated `deckplan.yaml` is written to the target location root.

Skills do NOT run this tool — it is a manual GM workflow for converting hand-drawn maps.

---

## Example

Two-room deckplan with one connecting door:

```yaml
decks:
  - id: main_deck
    name: Main Deck
    level: 1
    default: true
    unit_size: 30
    rooms:
      - id: bridge
        name: "BRIDGE"
        rects:
          - { x: 1, y: 0, w: 5, h: 3 }

      - id: airlock
        name: "AIRLOCK"
        rects:
          - { x: 6, y: 0, w: 2, h: 3 }
        poi:
          - icon: airlock
            label: "Tender Dock - Shepherd-7"
            type: objective
            description: "Docking clamp, currently sealed"

    doors:
      - rooms: [bridge, airlock]
        along: 0.5
        type: standard
        status: CLOSED
```
