#!/bin/sh
# PostToolUse(Edit|Write): format the edited PHP file, then static-analyse it.
# Each tool runs only when the project actually ships it.
. "$(dirname "$0")/runner.sh"
f=$(jq -r '.tool_input.file_path // empty')
[ -z "$f" ] && exit 0
rel=${f#${CLAUDE_PROJECT_DIR:-$PWD}/}
case "$rel" in
  *.php)
    [ -f ./vendor/bin/pint ] && maru_bin pint "$rel" >/dev/null 2>&1
    if [ -f ./vendor/bin/phpstan ] && { [ -f phpstan.neon ] || [ -f phpstan.neon.dist ] || [ -f phpstan.dist.neon ]; }; then
      maru_bin phpstan analyse "$rel" >/dev/null 2>&1 || { echo "PHPStan failed on $rel" >&2; exit 2; }
    fi
    ;;
esac
exit 0
