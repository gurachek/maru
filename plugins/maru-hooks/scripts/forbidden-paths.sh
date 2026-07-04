#!/bin/sh
# PreToolUse(Edit|Write): refuse edits to paths a coding agent must never touch.
command -v jq >/dev/null 2>&1 || { echo 'maru: jq is required by safety hooks and was not found — install jq' >&2; exit 2; }
f=$(jq -r '.tool_input.file_path // empty')
[ -z "$f" ] && exit 0
case "$f" in
  *.env.example|*.env.dist|.env.example|.env.dist) exit 0 ;;
esac
case "$f" in
  vendor/*|*/vendor/*|node_modules/*|*/node_modules/*|.env|.env.*|*/.env|*/.env.*|public/build/*|*/public/build/*|storage/api-docs/*|*/storage/api-docs/*|*resources/js/types/generated*)
    echo "Forbidden path: $f" >&2; exit 2 ;;
esac
exit 0
