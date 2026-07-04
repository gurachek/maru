#!/bin/sh
# PreToolUse(Bash): block irreversible commands outright.
command -v jq >/dev/null 2>&1 || { echo 'maru: jq is required by safety hooks and was not found — install jq' >&2; exit 2; }
c=$(jq -r '.tool_input.command // empty')

block() { echo "$1" >&2; exit 2; }

# 1. Core irreversible commands (rm -rf /, db:wipe, drop database, and any
#    destructive migrate variant: fresh/refresh/reset all drop+recreate).
echo "$c" | grep -Eiq 'rm -rf /|db:wipe|drop database|migrate:(fresh|refresh|reset)' \
  && block 'Destructive command blocked'

# 2. git force push — block -f/--force, including bundled short-flag clusters
#    (-uf, -fu, ...), but allow a bare --force-with-lease. A stray --force
#    still counts even alongside --force-with-lease (git: bare --force
#    disables the lease check), so strip only the lease flag before running
#    the force-detection patterns — no exemption logic beyond that.
if echo "$c" | grep -Eiq 'git push'; then
  stripped=$(printf '%s' "$c" | sed -E 's/--force-with-lease(=[^ ]*)?//g')
  echo "$stripped" | grep -Eiq -- ' -f( |$)|--force([^-]|$)| -[a-zA-Z0-9]*f[a-zA-Z0-9]*( |$)' \
    && block 'Destructive command blocked'
fi

# 3. tinker with a destructive payload (schema drops, truncates, raw deletes).
if echo "$c" | grep -Eiq 'tinker' \
  && echo "$c" | grep -Eiq 'schema::drop|->truncate\(|->forcedelete\(|drop table|truncate table|delete from'; then
  block 'Destructive command blocked'
fi

# 4. Direct SQL clients running a drop/truncate/delete (any DELETE FROM is
#    treated as unscoped-risk — deliberately over-blocks scoped deletes,
#    since ad-hoc SQL-client mutation is exactly what this guard exists to
#    make deliberate).
if echo "$c" | grep -Eiq '(psql|mysql)' \
  && echo "$c" | grep -Eiq 'drop table|drop schema|truncate table|delete from'; then
  block 'Destructive command blocked'
fi

# 5. Project-extensible blocklist: .claude/maru-blocklist in cwd, one ERE
#    pattern per line, case-insensitive, blank lines and #-comments ignored.
if [ -f .claude/maru-blocklist ]; then
  while IFS= read -r pattern || [ -n "$pattern" ]; do
    trimmed=${pattern#"${pattern%%[![:space:]]*}"}
    [ -z "$trimmed" ] && continue
    case "$trimmed" in
      '#'*) continue ;;
    esac
    echo "$c" | grep -Eiq -- "$pattern" \
      && { echo "Blocked by project blocklist: $pattern" >&2; exit 2; }
  done < .claude/maru-blocklist
fi

exit 0
