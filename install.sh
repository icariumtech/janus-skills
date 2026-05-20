#!/usr/bin/env bash
# install.sh — JANUS Skills installer
#
# Installs Claude Code skill directories and schema resources for JANUS GM tools.
# Resources always go to ~/.claude/janus-skills/resources/ so @$HOME/... @-includes
# in SKILL.md resolve correctly from any project working directory.
# Uses symlinks (not copies) — updating the repo auto-updates installed skills.
# Idempotent: ln -sfn replaces existing links without nesting.

set -euo pipefail

# Resolve repo root regardless of working directory from which this script is invoked
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --------------------------------------------------------------------------
# Usage / help
# --------------------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $(basename "$0") [--global | --project <path>] [--mcp-config] [--help]

Options:
  --global              Install skills to ~/.claude/skills/
  --project <path>      Install skills to <path>/.claude/skills/
  --mcp-config          Also merge JanusGM MCP server config into target .claude/settings.json
                        (prompts for homelab server IP)
  -h, --help            Show this help and exit

Examples:
  ./install.sh --global
  ./install.sh --global --mcp-config
  ./install.sh --project /path/to/my-campaign
  ./install.sh --project /path/to/my-campaign --mcp-config

Notes:
  - Resources are always installed to ~/.claude/janus-skills/resources/ (both modes)
  - Do not move this repo after installing — symlinks point to the original location
  - Rerunning is safe (idempotent)
EOF
}

# --------------------------------------------------------------------------
# Parse flags
# --------------------------------------------------------------------------
GLOBAL_MODE=false
PROJECT_PATH=""
MCP_CONFIG=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global)
      GLOBAL_MODE=true
      ;;
    --project)
      if [[ -z "${2:-}" ]]; then
        echo "ERROR: --project requires a path argument" >&2
        usage
        exit 1
      fi
      PROJECT_PATH="$2"
      shift
      ;;
    --mcp-config)
      MCP_CONFIG=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

# --------------------------------------------------------------------------
# Validate flag combinations
# --------------------------------------------------------------------------

# Reject conflicting flags
if $GLOBAL_MODE && [[ -n "$PROJECT_PATH" ]]; then
  echo "ERROR: --global and --project are mutually exclusive — choose one." >&2
  exit 1
fi

# Require at least one install mode
if ! $GLOBAL_MODE && [[ -z "$PROJECT_PATH" ]]; then
  echo "ERROR: Specify either --global or --project <path>." >&2
  usage
  exit 1
fi

# Validate project path if provided
if [[ -n "$PROJECT_PATH" ]]; then
  if [[ ! -d "$PROJECT_PATH" ]]; then
    echo "ERROR: Project path does not exist or is not a directory: $PROJECT_PATH" >&2
    exit 1
  fi
  # Resolve to absolute path
  PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"
fi

# --------------------------------------------------------------------------
# Compute directories
# --------------------------------------------------------------------------

# Skills destination depends on install mode
if $GLOBAL_MODE; then
  SKILLS_DIR="$HOME/.claude/skills"
else
  SKILLS_DIR="$PROJECT_PATH/.claude/skills"
fi

# Resources ALWAYS go to stable HOME-anchored path (Pitfall P3):
# @$HOME/.claude/janus-skills/resources/... resolves correctly from any project CWD
RESOURCES_DIR="$HOME/.claude/janus-skills/resources"

echo "JANUS Skills Installer"
echo "  Skills destination : $SKILLS_DIR"
echo "  Resources          : $RESOURCES_DIR"
echo ""

# --------------------------------------------------------------------------
# Create directories
# --------------------------------------------------------------------------
mkdir -p "$SKILLS_DIR"
mkdir -p "$RESOURCES_DIR"

# --------------------------------------------------------------------------
# Symlink resource files (schema-*.md)
# --------------------------------------------------------------------------
RESOURCE_COUNT=0
for f in "$REPO_DIR/resources/"*.md; do
  [[ -e "$f" ]] || continue  # skip if glob doesn't match (empty resources/)
  target="$RESOURCES_DIR/$(basename "$f")"
  ln -sfn "$f" "$target"
  RESOURCE_COUNT=$((RESOURCE_COUNT + 1))
done
echo "Resources installed: $RESOURCE_COUNT file(s) → $RESOURCES_DIR"

# --------------------------------------------------------------------------
# Symlink skill directories (skills/janus-*/)
# --------------------------------------------------------------------------
SKILL_COUNT=0
for skill_dir in "$REPO_DIR/skills/janus-"*/; do
  [[ -d "$skill_dir" ]] || continue  # skip if glob doesn't match (empty skills/)
  skill_name="$(basename "$skill_dir")"
  target="$SKILLS_DIR/$skill_name"
  link_target="${skill_dir%/}"
  ln -sfn "$link_target" "$target"
  SKILL_COUNT=$((SKILL_COUNT + 1))
done
echo "Skills installed   : $SKILL_COUNT skill(s) → $SKILLS_DIR"
echo ""

if [[ $SKILL_COUNT -eq 0 ]]; then
  echo "NOTE: No skill directories found in $REPO_DIR/skills/ (expected skills/janus-*/ subdirectories)."
fi

# --------------------------------------------------------------------------
# Optional: MCP config injection (--mcp-config)
# --------------------------------------------------------------------------
if $MCP_CONFIG; then

  # Pre-flight: require python3
  if ! command -v python3 > /dev/null 2>&1; then
    echo "ERROR: python3 required for --mcp-config (not found on PATH)." >&2
    exit 1
  fi

  # Prompt for homelab IP with retry
  HOMELAB_IP=""
  while [[ -z "$HOMELAB_IP" ]]; do
    read -r -p "Homelab server IP (e.g., 192.168.1.42): " HOMELAB_IP
    if [[ -z "$HOMELAB_IP" ]]; then
      echo "ERROR: IP address cannot be blank. Try again." >&2
    fi
  done

  # Determine target settings.json
  if $GLOBAL_MODE; then
    SETTINGS_FILE="$HOME/.claude/settings.json"
  else
    SETTINGS_FILE="$PROJECT_PATH/.claude/settings.json"
  fi

  # Ensure parent directory exists
  mkdir -p "$(dirname "$SETTINGS_FILE")"

  # Merge JanusGM block via Python (never overwrites other mcpServers entries)
  python3 - "$SETTINGS_FILE" "$REPO_DIR/mcp-config-template.json" "$HOMELAB_IP" <<'PYEOF'
import sys
import json
import os

settings_path = sys.argv[1]
template_path = sys.argv[2]
homelab_ip    = sys.argv[3]

# Load existing settings.json (or start fresh)
if os.path.exists(settings_path):
  with open(settings_path, "r") as fh:
    existing = json.load(fh)
else:
  existing = {}

# Ensure mcpServers key exists as a dict
if "mcpServers" not in existing or not isinstance(existing["mcpServers"], dict):
  existing["mcpServers"] = {}

# Load template and extract JanusGM block
with open(template_path, "r") as fh:
  template = json.load(fh)

janus_entry = template["mcpServers"]["JanusGM"]

# Replace HOMELAB_IP placeholder in the url field
janus_entry["url"] = janus_entry["url"].replace("HOMELAB_IP", homelab_ip)

# Merge: only the JanusGM key is set; all other mcpServers entries are preserved
existing["mcpServers"]["JanusGM"] = janus_entry

# Write back atomically (tempfile + rename — survives crash mid-write)
import tempfile
tmp_fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname(settings_path) or ".",
                                     prefix=".settings_tmp_")
try:
  with os.fdopen(tmp_fd, "w") as fh:
    json.dump(existing, fh, indent=2)
    fh.write("\n")
  os.replace(tmp_path, settings_path)
except Exception:
  try:
    os.unlink(tmp_path)
  except OSError:
    pass
  raise

print("MCP config written to {}".format(settings_path))
PYEOF

fi

# --------------------------------------------------------------------------
# Done
# --------------------------------------------------------------------------
echo ""
echo "Installed $SKILL_COUNT skill(s) + $RESOURCE_COUNT resource(s)."
if $MCP_CONFIG; then
  echo "MCP config merged into settings.json for server: JanusGM"
fi
echo ""
echo "Restart Claude Code for new skills to appear."
exit 0
