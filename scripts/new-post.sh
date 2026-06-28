#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <YYYY-MM-DD> <slug> <\"Title\"> [image1 image2 ...]"
  echo "       Body text read from stdin or --body <file>"
  echo ""
  echo "Example:"
  echo "  $0 2026-06-28 jahreshauptversammlung \"Jahreshauptversammlung 2026\" ~/Desktop/IMG_*.jpg < body.txt"
  exit 1
}

BODY_FILE=""
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --body) BODY_FILE="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done

[[ ${#POSITIONAL[@]} -lt 3 ]] && usage

DATE="${POSITIONAL[0]}"
SLUG="${POSITIONAL[1]}"
TITLE="${POSITIONAL[2]}"
IMAGES=("${POSITIONAL[@]:3}")

# Validate date format
if ! [[ "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Error: date must be YYYY-MM-DD, got: $DATE" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
POST_DIR="$REPO_ROOT/content/aktuelles/${DATE}-${SLUG}"

if [[ -d "$POST_DIR" ]]; then
  echo "Error: post directory already exists: $POST_DIR" >&2
  exit 1
fi

mkdir -p "$POST_DIR"
echo "Created: $POST_DIR"

# Read body text
if [[ -n "$BODY_FILE" ]]; then
  BODY=$(cat "$BODY_FILE")
elif ! [ -t 0 ]; then
  BODY=$(cat)
else
  BODY=""
fi

# Convert images to webp
WEBP_NAMES=()
for img in "${IMAGES[@]}"; do
  if [[ ! -f "$img" ]]; then
    echo "Warning: image not found, skipping: $img" >&2
    continue
  fi
  basename_no_ext="$(basename "${img%.*}")"
  out_name="${basename_no_ext}.webp"
  out_path="$POST_DIR/$out_name"

  echo "Converting: $(basename "$img") → $out_name"
  cwebp -q 82 -mt "$img" -o "$out_path" 2>/dev/null
  WEBP_NAMES+=("$out_name")
done

# Build image frontmatter
if [[ ${#WEBP_NAMES[@]} -eq 0 ]]; then
  IMAGE_YAML='image: ""'
elif [[ ${#WEBP_NAMES[@]} -eq 1 ]]; then
  IMAGE_YAML="image: \"${WEBP_NAMES[0]}\""
else
  IMAGE_YAML="image:"
  for name in "${WEBP_NAMES[@]}"; do
    IMAGE_YAML+=$'\n'"  - $name"
  done
fi

# Write index.md
cat > "$POST_DIR/index.md" <<EOF
---
date: ${DATE}T00:00:00
draft: false
params:
  author: Johannes Sappl
title: ${TITLE}
${IMAGE_YAML}
---

<!-- ltex: language=de-AT -->

${BODY}
EOF

echo "Written: $POST_DIR/index.md"
echo ""
echo "Done. Edit date/time in frontmatter if needed:"
echo "  $POST_DIR/index.md"
