---
name: janus-upload-portrait
description: "Upload an NPC portrait from a local file. Saves to images_source/ and runs amber-gradient conversion by default."
argument-hint: "<path-to-image-file>"
allowed-tools:
  - mcp__JanusGM__get_django_url
  - Bash
---

@$HOME/.claude/janus-skills/resources/schema-campaign.md

# /janus-upload-portrait

<objective>
Upload a portrait image file for an NPC and save it to `data/campaign/NPCs/images_source/`. By
default this skill also runs the amber-gradient conversion pass — a 512x512 center crop with an
amber tint — which produces the display-ready portrait at `data/campaign/NPCs/images/<stem>.png`.
The raw source file is always preserved in `images_source/` regardless of whether conversion is
requested. Use `convert=false` only when you want to store a source image without producing a
display-ready version yet.
</objective>

<process>
1. Verify that `$ARGUMENTS` is a path to an existing local image file. If the file does not exist,
   stop and report the missing path to the user before continuing.

2. Extract the basename (no directory component) from the path — this becomes `<filename>`.
   For example, `C:\Users\gabe\Pictures\captain_harrow.jpg` yields `filename="captain_harrow.jpg"`.

3. Call `get_django_url()` to retrieve the Django base URL (e.g. `http://icarium.local:8000`).

4. Upload the file directly using curl — do NOT read the file or attempt base64 encoding
   under any circumstances. Binary data must never pass through the tool pipeline:

   ```
   curl.exe -s -X POST -F "file=@<path>" -F "filename=<filename>" -F "image_type=portrait" -F "convert=true" <django_url>/api/gm/upload-image/
   ```

   On Windows the command is identical — `curl` resolves to `curl.exe` automatically.
   File paths with spaces must be quoted: `-F "file=@\"C:\path with spaces\file.jpg\""`.

5. Parse the JSON response. Report to the user:
   - `saved_path` — source file location in `images_source/`
   - `converted_path` — display-ready portrait (e.g. `campaign/NPCs/images/captain_harrow.png`)
   - `original_size_bytes`
   If a `conversion_warning` key is present, surface it verbatim.
   On HTTP error, report the status code and response body.

6. Remind the user that the `portrait` field in the NPC YAML should reference the converted image
   path (e.g. `portrait: "NPCs/images/captain_harrow.png"`), NOT the `images_source` path. Use
   `/janus-add-npc` or edit the NPC YAML directly to set this field.
</process>

**Note:** To skip conversion and save the raw source only, pass `-F "convert=false"` in the curl
command. Conversion can be triggered later by re-running this skill with `convert=true` (the default).
