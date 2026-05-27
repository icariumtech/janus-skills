---
name: janus-upload-image
description: "Upload a logo, map, or miscellaneous image asset to the campaign data directory. image_type required: logo | map | misc."
argument-hint: "<path-to-image-file> <image_type>"
allowed-tools:
  - mcp__JanusGM__upload_image
---

@$HOME/.claude/janus-skills/resources/schema-campaign.md

# /janus-upload-image

<objective>
Upload a non-portrait image asset — such as a faction logo, a handout map, or miscellaneous
artwork — to the campaign data directory. The `image_type` parameter determines the destination:
`logo` → `data/campaign/images/logos/`, `map` → `data/campaign/images/maps/`, `misc` →
`data/campaign/images/misc/`. Files are stored as-is; no pixel conversion is performed for these
types. For NPC portraits (amber-gradient conversion), use `/janus-upload-portrait` instead.
</objective>

<process>
1. Parse `$ARGUMENTS` for two values: the local file path (first argument) and the `image_type`
   (second argument). `image_type` must be one of: `logo`, `map`, `misc`. If either value is
   missing or `image_type` is not one of those three, ask the user to supply the missing
   information before continuing.

2. Verify the file exists at the given path. If it does not exist, stop and report the path to
   the user. Extract the basename (no directory component) — this becomes the `filename`
   parameter. For example, `/home/user/icarium_logo.png` yields `filename="icarium_logo.png"`.

3. Read the file as binary and encode it to base64. Use the Python one-liner:
   `python3 -c "import base64, sys; print(base64.b64encode(open(sys.argv[1],'rb').read()).decode())" "<file-path>"`
   or the shell equivalent: `base64 "<file-path>"` (Linux/macOS). Capture the output as
   `content_base64`.

4. Call `upload_image(filename=<basename>, content_base64=<encoded>, image_type=<type>)` where
   `<type>` is the `logo`, `map`, or `misc` value from step 1. The `convert` parameter has no
   effect for these types — conversion is portrait-only and is always skipped server-side
   regardless of the flag value, so there is no need to pass it.

5. Report the results to the user: the `saved_path` (full path where the file was written) and
   `original_size_bytes` from the response.
</process>

**Note:** The `convert` parameter only has an effect for `image_type="portrait"`. For `logo`,
`map`, and `misc` types, no conversion is ever performed regardless of the `convert` flag value.
To upload NPC portraits with amber-gradient conversion, use `/janus-upload-portrait` instead.
