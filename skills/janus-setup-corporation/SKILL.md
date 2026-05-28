---
name: janus-setup-corporation
description: "Create or update campaign/corporation.yaml (the campaign's primary faction record) and optionally upload a faction logo in one operation."
argument-hint: "<corporation-name> [logo-path]"
allowed-tools:
  - mcp__JanusGM__get_django_url
  - mcp__JanusGM__write_file
  - Bash
---

@$HOME/.claude/janus-skills/resources/schema-campaign.md

# /janus-setup-corporation

<objective>
Create or overwrite `data/campaign/corporation.yaml` — the single record describing the campaign's
primary faction. Optionally upload a logo image in the same operation; the uploaded path is written
into the `logo` field automatically. All file writes go through the JANUS MCP server.

Corporation config path: `campaign/corporation.yaml` (single file — NOT a directory).
</objective>

<process>
1. Parse `$ARGUMENTS`: corporation name (first argument, required), optional local logo file path
   (second argument). If corporation name is missing, prompt the user before continuing.

2. Collect any additional fields not supplied in arguments. Prompt only for fields the user wants
   to set — all are optional except `name`:
   - `motto` (optional string)
   - `version` (optional string, e.g. `"4.1"`)
   - `firmware` (optional string, e.g. `"2.0518"`)
   - `logo` will be set automatically if a logo is uploaded (step 3); skip this prompt if a
     logo path was supplied as an argument.

3. **If a logo file path was supplied:**
   a. Call `get_django_url()` to retrieve the Django base URL.
   b. Extract the basename from the path (e.g. `korova-stahl-logo.png`).
   c. Upload using curl — do NOT read the file or attempt base64 encoding under any circumstances:

      ```
      curl.exe -s -X POST -F "file=@<path>" -F "filename=<basename>" -F "image_type=logo" <django_url>/api/gm/upload-image/
      ```

      On Windows paths with spaces: `-F "file=@\"C:\path with spaces\logo.png\""`.
   d. Parse the JSON response. On HTTP error, report it and ask the user whether to continue
      without the logo or abort.
   e. Set `logo` to `campaign/images/logos/<basename>` (matches the `saved_path` from the response).

4. Build the YAML content for `campaign/corporation.yaml`. Include only fields that have values —
   omit any field the user did not supply:

   ```yaml
   name: "<name>"
   motto: "<motto>"        # omit if not provided
   logo: <logo-path>       # omit if no logo uploaded or supplied
   version: "<version>"    # omit if not provided
   firmware: "<firmware>"  # omit if not provided
   ```

   Use double-quoted strings for free-text fields (`name`, `motto`).

5. Call `write_file("campaign/corporation.yaml", content)`.

6. Report what was written: corporation name, which optional fields were set, and the logo upload
   result (saved path + size) if applicable.
</process>
