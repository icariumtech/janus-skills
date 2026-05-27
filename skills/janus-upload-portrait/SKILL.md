---
name: janus-upload-portrait
description: "Upload an NPC portrait from a local file. Saves to images_source/ and runs amber-gradient conversion by default."
argument-hint: "<path-to-image-file>"
allowed-tools:
  - mcp__JanusGM__upload_image
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

2. Extract the basename (no directory component) from the path — this becomes the `filename`
   parameter. For example, `/home/user/captain_harrow.jpg` yields `filename="captain_harrow.jpg"`.

3. Read the file as binary and encode it to base64. Use the Python one-liner:
   `python3 -c "import base64, sys; print(base64.b64encode(open(sys.argv[1],'rb').read()).decode())" "$ARGUMENTS"`
   or the shell equivalent: `base64 "$ARGUMENTS"` (Linux/macOS). Capture the output as
   `content_base64`.

4. Call `upload_image(filename=<basename>, content_base64=<encoded>, image_type="portrait", convert=true)`.
   The `convert=true` default triggers the amber-gradient conversion pipeline. The tool returns
   `saved_path`, `converted_path` (present when conversion succeeds), and `original_size_bytes`.

5. Report the results to the user: the `saved_path` (source file location in `images_source/`),
   the `converted_path` (display-ready portrait, e.g. `data/campaign/NPCs/images/captain_harrow.png`),
   and `original_size_bytes`. If a `conversion_warning` key is present in the response, surface
   it verbatim so the user knows about any conversion issues.

6. Remind the user that the `portrait` field in the NPC YAML should reference the converted image
   path (e.g. `portrait: "NPCs/images/captain_harrow.png"`), NOT the `images_source` path. Use
   `/janus-add-npc` or edit the NPC YAML directly to set this field.
</process>

**Note:** To skip conversion and save the raw source only, call the tool with `convert=false`.
Conversion can be triggered later by running this skill again on the same file with `convert=true`
(or by omitting the `convert` argument, since `true` is the default).
