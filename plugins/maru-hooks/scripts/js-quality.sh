#!/bin/sh
# PostToolUse(Edit|Write): prettier + eslint on the edited frontend file, when installed.
. "$(dirname "$0")/runner.sh"
f=$(jq -r '.tool_input.file_path // empty')
[ -z "$f" ] && exit 0
rel=${f#${CLAUDE_PROJECT_DIR:-$PWD}/}
case "$rel" in
  *.vue|*.ts|*.tsx)
    [ -d node_modules ] || exit 0
    [ -f node_modules/.bin/prettier ] && maru_npx prettier --write "$rel" >/dev/null 2>&1
    if [ -f node_modules/.bin/eslint ]; then
      maru_npx eslint "$rel" >/dev/null 2>&1 || { echo "ESLint failed on $rel" >&2; exit 2; }
    fi
    ;;
esac
exit 0
