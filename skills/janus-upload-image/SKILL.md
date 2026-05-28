---
name: janus-upload-image
description: "Upload a logo, map, or miscellaneous image asset to the campaign data directory. image_type required: logo | map | misc."
argument-hint: "<path-to-image-file> <image_type>"
allowed-tools:
  - mcp__JanusGM__get_django_url
  - mcp__JanusGM__upload_image
  - Bash
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
   the user. Extract the basename (no directory component) — this becomes `<filename>`.
   For example, `C:\Users\gabe\Downloads\icarium_logo.png` yields `filename="icarium_logo.png"`.

3. Call `get_django_url()` to retrieve the Django base URL (e.g. `http://192.168.1.42:8000`).

4. Upload the file directly using curl — no base64 encoding, no MCP tool pipeline:

   ```
   curl -s -X POST -F "file=@<path>" -F "filename=<filename>" -F "image_type=<image_type>" <django_url>/api/gm/upload-image/
   ```

   On Windows the command is identical — `curl` resolves to `curl.exe` automatically.
   File paths with spaces must be quoted: `-F "file=@\"C:\path with spaces\file.png\""`.

5. Parse the JSON response. Report the `saved_path` and `original_size_bytes` to the user.
   On HTTP error, report the status code and response body.
</process>

**Note:** The `convert` parameter only has an effect for `image_type="portrait"`. For `logo`,
`map`, and `misc` types, no conversion is ever performed. To upload NPC portraits with
amber-gradient conversion, use `/janus-upload-portrait` instead.
