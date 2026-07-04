#!/bin/sh
# Dependency-free test harness for maru hook scripts. Run from repo root.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SCRIPTS="$ROOT/plugins/maru-hooks/scripts"
PASS=0; FAIL=0

expect_exit() { # expect_exit <code> <label> <stdin-json> <script> [env...]
  code=$1; label=$2; json=$3; script=$4
  printf '%s' "$json" | "$SCRIPTS/$script" >/dev/null 2>&1
  got=$?
  if [ "$got" -eq "$code" ]; then PASS=$((PASS+1)); echo "ok - $label"
  else FAIL=$((FAIL+1)); echo "FAIL - $label (want $code got $got)"; fi
}

expect_msg() { # expect_msg <substring> <label> <stdin-json> <script>
  needle=$1; label=$2; json=$3; script=$4
  err=$(printf '%s' "$json" | "$SCRIPTS/$script" 2>&1 >/dev/null)
  if printf '%s' "$err" | grep -qF "$needle"; then PASS=$((PASS+1)); echo "ok - $label"
  else FAIL=$((FAIL+1)); echo "FAIL - $label (stderr lacked '$needle')"; fi
}

# --- forbidden-paths ---
expect_exit 2 "blocks vendor"            '{"tool_input":{"file_path":"vendor/foo/Bar.php"}}' forbidden-paths.sh
expect_exit 2 "blocks nested vendor"     '{"tool_input":{"file_path":"/x/app/vendor/foo.php"}}' forbidden-paths.sh
expect_exit 2 "blocks .env"              '{"tool_input":{"file_path":".env"}}' forbidden-paths.sh
expect_exit 2 "blocks .env.production"   '{"tool_input":{"file_path":"/proj/.env.production"}}' forbidden-paths.sh
expect_exit 2 "blocks node_modules"      '{"tool_input":{"file_path":"node_modules/x/i.js"}}' forbidden-paths.sh
expect_exit 2 "blocks public/build"      '{"tool_input":{"file_path":"public/build/app.js"}}' forbidden-paths.sh
expect_exit 0 "allows app code"          '{"tool_input":{"file_path":"app/Models/User.php"}}' forbidden-paths.sh
expect_exit 0 "allows missing path"      '{"tool_input":{}}' forbidden-paths.sh

# --- destructive-commands ---
expect_exit 2 "blocks migrate:fresh"     '{"tool_input":{"command":"php artisan migrate:fresh"}}' destructive-commands.sh
expect_exit 2 "blocks db:wipe"           '{"tool_input":{"command":"php artisan db:wipe"}}' destructive-commands.sh
expect_exit 2 "blocks force push"        '{"tool_input":{"command":"git push origin main --force"}}' destructive-commands.sh
expect_exit 2 "blocks rm -rf /"          '{"tool_input":{"command":"rm -rf /"}}' destructive-commands.sh
expect_exit 2 "blocks drop database"     '{"tool_input":{"command":"psql -c \"drop database x\""}}' destructive-commands.sh
expect_exit 0 "allows plain artisan"     '{"tool_input":{"command":"php artisan migrate"}}' destructive-commands.sh
expect_exit 0 "allows normal git push"   '{"tool_input":{"command":"git push origin main"}}' destructive-commands.sh

# --- quality hooks: graceful degradation (run in a bare tmp project) ---
TMPPROJ=$(mktemp -d)
( cd "$TMPPROJ" && printf '%s' '{"tool_input":{"file_path":"'"$TMPPROJ"'/app/Foo.php"}}' | "$SCRIPTS/php-quality.sh" >/dev/null 2>&1 )
[ $? -eq 0 ] && { PASS=$((PASS+1)); echo "ok - php-quality skips when no pint/phpstan"; } || { FAIL=$((FAIL+1)); echo "FAIL - php-quality bare project"; }
( cd "$TMPPROJ" && printf '%s' '{"tool_input":{"file_path":"'"$TMPPROJ"'/resources/js/App.vue"}}' | "$SCRIPTS/js-quality.sh" >/dev/null 2>&1 )
[ $? -eq 0 ] && { PASS=$((PASS+1)); echo "ok - js-quality skips when no node_modules"; } || { FAIL=$((FAIL+1)); echo "FAIL - js-quality bare project"; }
( cd "$TMPPROJ" && printf '%s' '{"tool_input":{"file_path":"'"$TMPPROJ"'/README.md"}}' | "$SCRIPTS/php-quality.sh" >/dev/null 2>&1 )
[ $? -eq 0 ] && { PASS=$((PASS+1)); echo "ok - php-quality ignores non-php"; } || { FAIL=$((FAIL+1)); echo "FAIL - php-quality non-php"; }
rm -rf "$TMPPROJ"

# --- gate-on-green ---
GTMP=$(mktemp -d)
mkdir -p "$GTMP/bin" "$GTMP/.claude"

( cd "$GTMP" && rm -f .claude/gate-on-green && printf '{}' | "$SCRIPTS/gate-on-green.sh" >/dev/null 2>&1 )
[ $? -eq 0 ] && { PASS=$((PASS+1)); echo "ok - gate skips without marker"; } || { FAIL=$((FAIL+1)); echo "FAIL - gate no-marker"; }

printf '#!/bin/sh\nexit 0\n' > "$GTMP/bin/php"; chmod +x "$GTMP/bin/php"
( cd "$GTMP" && touch .claude/gate-on-green && PATH="$GTMP/bin:$PATH" printf '{}' | PATH="$GTMP/bin:$PATH" "$SCRIPTS/gate-on-green.sh" >/dev/null 2>&1 )
[ $? -eq 0 ] && { PASS=$((PASS+1)); echo "ok - gate passes on green suite"; } || { FAIL=$((FAIL+1)); echo "FAIL - gate green"; }

printf '#!/bin/sh\nexit 1\n' > "$GTMP/bin/php"; chmod +x "$GTMP/bin/php"
( cd "$GTMP" && printf '{}' | PATH="$GTMP/bin:$PATH" "$SCRIPTS/gate-on-green.sh" >/dev/null 2>&1 )
[ $? -eq 2 ] && { PASS=$((PASS+1)); echo "ok - gate blocks on red suite"; } || { FAIL=$((FAIL+1)); echo "FAIL - gate red"; }
rm -rf "$GTMP"

# --- new: case-insensitive destructive patterns + .env template allowlist ---
expect_exit 2 "blocks uppercase DROP DATABASE"  '{"tool_input":{"command":"psql -c \"DROP DATABASE prod\""}}' destructive-commands.sh
expect_exit 2 "blocks uppercase MIGRATE:FRESH"  '{"tool_input":{"command":"php artisan MIGRATE:FRESH"}}' destructive-commands.sh
expect_exit 0 "allows .env.example"             '{"tool_input":{"file_path":".env.example"}}' forbidden-paths.sh
expect_exit 0 "allows nested .env.example"      '{"tool_input":{"file_path":"/proj/.env.example"}}' forbidden-paths.sh

# --- A1: safety hooks fail closed without jq ---
EMPTYDIR=$(mktemp -d)
( printf '{}' | env -i PATH="$EMPTYDIR" "$SCRIPTS/forbidden-paths.sh" >/dev/null 2>&1 )
[ $? -eq 2 ] && { PASS=$((PASS+1)); echo "ok - forbidden-paths fails closed without jq"; } || { FAIL=$((FAIL+1)); echo "FAIL - forbidden-paths fails closed without jq"; }
( printf '{}' | env -i PATH="$EMPTYDIR" "$SCRIPTS/destructive-commands.sh" >/dev/null 2>&1 )
[ $? -eq 2 ] && { PASS=$((PASS+1)); echo "ok - destructive-commands fails closed without jq"; } || { FAIL=$((FAIL+1)); echo "FAIL - destructive-commands fails closed without jq"; }
rm -rf "$EMPTYDIR"

# --- A2: extended destructive-commands patterns ---
expect_exit 2 "blocks migrate:refresh"          '{"tool_input":{"command":"php artisan migrate:refresh"}}' destructive-commands.sh
expect_exit 2 "blocks migrate:reset"            '{"tool_input":{"command":"php artisan migrate:reset"}}' destructive-commands.sh
expect_exit 0 "allows plain migrate (recheck)"  '{"tool_input":{"command":"php artisan migrate"}}' destructive-commands.sh

expect_exit 2 "blocks git push -f"              '{"tool_input":{"command":"git push -f"}}' destructive-commands.sh
expect_exit 2 "blocks git push --force"         '{"tool_input":{"command":"git push origin main --force"}}' destructive-commands.sh
expect_exit 0 "allows git push --force-with-lease" '{"tool_input":{"command":"git push --force-with-lease origin main"}}' destructive-commands.sh
expect_exit 0 "allows git push feature branch"  '{"tool_input":{"command":"git push origin feature"}}' destructive-commands.sh

expect_exit 2 "blocks tinker Schema::drop"      '{"tool_input":{"command":"php artisan tinker --execute=\"Schema::drop(\\\"users\\\")\""}}' destructive-commands.sh
expect_exit 2 "blocks tinker truncate"          '{"tool_input":{"command":"php artisan tinker --execute=\"DB::table(\\\"users\\\")->truncate()\""}}' destructive-commands.sh
expect_exit 2 "blocks tinker forceDelete"       '{"tool_input":{"command":"php artisan tinker --execute=\"User::first()->forceDelete()\""}}' destructive-commands.sh
expect_exit 0 "allows plain tinker"             '{"tool_input":{"command":"php artisan tinker"}}' destructive-commands.sh

expect_exit 2 "blocks psql drop table"          '{"tool_input":{"command":"psql -c \"drop table users\""}}' destructive-commands.sh
expect_exit 2 "blocks mysql truncate table"     '{"tool_input":{"command":"mysql -e \"truncate table users\""}}' destructive-commands.sh
expect_exit 0 "allows plain psql select"        '{"tool_input":{"command":"psql -c \"select 1\""}}' destructive-commands.sh

# --- A3: project-extensible blocklist ---
BLTMP=$(mktemp -d)
mkdir -p "$BLTMP/.claude"
printf '# comment line\n\nacme:demo:(seed|calibrate)\n' > "$BLTMP/.claude/maru-blocklist"
( cd "$BLTMP" && printf '%s' '{"tool_input":{"command":"php artisan acme:demo:seed"}}' | "$SCRIPTS/destructive-commands.sh" >/dev/null 2>&1 )
[ $? -eq 2 ] && { PASS=$((PASS+1)); echo "ok - blocklist blocks matching command"; } || { FAIL=$((FAIL+1)); echo "FAIL - blocklist blocks matching command"; }
( cd "$BLTMP" && printf '%s' '{"tool_input":{"command":"php artisan acme:demo:status"}}' | "$SCRIPTS/destructive-commands.sh" >/dev/null 2>&1 )
[ $? -eq 0 ] && { PASS=$((PASS+1)); echo "ok - blocklist allows non-matching command"; } || { FAIL=$((FAIL+1)); echo "FAIL - blocklist allows non-matching command"; }
rm -rf "$BLTMP"

NOBLTMP=$(mktemp -d)
( cd "$NOBLTMP" && printf '%s' '{"tool_input":{"command":"php artisan acme:demo:seed"}}' | "$SCRIPTS/destructive-commands.sh" >/dev/null 2>&1 )
[ $? -eq 0 ] && { PASS=$((PASS+1)); echo "ok - no blocklist file leaves behavior unchanged"; } || { FAIL=$((FAIL+1)); echo "FAIL - no blocklist file leaves behavior unchanged"; }
rm -rf "$NOBLTMP"

# --- A4: gate-on-green diagnostics + project-scoped concurrency guard ---
SAILDOWN=$(mktemp -d)
mkdir -p "$SAILDOWN/bin" "$SAILDOWN/.claude"
touch "$SAILDOWN/.claude/gate-on-green"
printf '#!/bin/sh\necho "Sail is not running."\nexit 1\n' > "$SAILDOWN/bin/php"; chmod +x "$SAILDOWN/bin/php"
( cd "$SAILDOWN" && printf '{}' | PATH="$SAILDOWN/bin:$PATH" "$SCRIPTS/gate-on-green.sh" >/dev/null 2>"$SAILDOWN/stderr.txt" )
got=$?
if [ "$got" -eq 2 ] && grep -q "NOT a test failure" "$SAILDOWN/stderr.txt"; then
  PASS=$((PASS+1)); echo "ok - gate emits Sail-down diagnostic distinct from test failure"
else
  FAIL=$((FAIL+1)); echo "FAIL - gate Sail-down diagnostic (exit=$got)"
fi
rm -rf "$SAILDOWN"

# decoy phpunit in a DIFFERENT cwd must not cause a false-skip.
DECOY1=$(mktemp -d)
printf '#!/bin/sh\nsleep 8\n' > "$DECOY1/phpunit"; chmod +x "$DECOY1/phpunit"
( cd "$DECOY1" && exec ./phpunit ) &
DECOY1_PID=$!
sleep 1

G1=$(mktemp -d)
mkdir -p "$G1/bin" "$G1/.claude"
touch "$G1/.claude/gate-on-green"
printf '#!/bin/sh\ntouch "%s/php-invoked"\nexit 0\n' "$G1" > "$G1/bin/php"; chmod +x "$G1/bin/php"
( cd "$G1" && printf '{}' | PATH="$G1/bin:$PATH" "$SCRIPTS/gate-on-green.sh" >/dev/null 2>&1 )
got=$?
if [ "$got" -eq 0 ] && [ -f "$G1/php-invoked" ]; then
  PASS=$((PASS+1)); echo "ok - gate runs (not false-skip) when decoy phpunit is in a different cwd"
else
  FAIL=$((FAIL+1)); echo "FAIL - gate false-skip on decoy phpunit in different cwd (exit=$got)"
fi
kill "$DECOY1_PID" 2>/dev/null; wait "$DECOY1_PID" 2>/dev/null
rm -rf "$DECOY1" "$G1"

# decoy phpunit in the SAME cwd as the gate must still trigger a skip.
DECOY2=$(mktemp -d)
mkdir -p "$DECOY2/bin" "$DECOY2/.claude"
touch "$DECOY2/.claude/gate-on-green"
printf '#!/bin/sh\nsleep 8\n' > "$DECOY2/phpunit"; chmod +x "$DECOY2/phpunit"
( cd "$DECOY2" && exec ./phpunit ) &
DECOY2_PID=$!
sleep 1

printf '#!/bin/sh\ntouch "%s/php-invoked"\nexit 1\n' "$DECOY2" > "$DECOY2/bin/php"; chmod +x "$DECOY2/bin/php"
( cd "$DECOY2" && printf '{}' | PATH="$DECOY2/bin:$PATH" "$SCRIPTS/gate-on-green.sh" >/dev/null 2>&1 )
got=$?
if [ "$got" -eq 0 ] && [ ! -f "$DECOY2/php-invoked" ]; then
  PASS=$((PASS+1)); echo "ok - gate skips when decoy phpunit shares this cwd"
else
  FAIL=$((FAIL+1)); echo "FAIL - gate did not skip for same-cwd phpunit (exit=$got)"
fi
kill "$DECOY2_PID" 2>/dev/null; wait "$DECOY2_PID" 2>/dev/null
rm -rf "$DECOY2"

# --- A5: force-push bypasses, force-with-lease decoy, unscoped SQL delete ---
expect_exit 2 "blocks git push -uf (bundled short flags)"       '{"tool_input":{"command":"git push -uf origin main"}}' destructive-commands.sh
expect_exit 2 "blocks git push -fu (bundled short flags)"       '{"tool_input":{"command":"git push -fu origin main"}}' destructive-commands.sh
expect_exit 2 "blocks git push -4f (digit short-flag cluster)"  '{"tool_input":{"command":"git push -4f origin main"}}' destructive-commands.sh
expect_exit 0 "allows git push --follow-tags"                   '{"tool_input":{"command":"git push --follow-tags origin main"}}' destructive-commands.sh
expect_exit 2 "blocks --force alongside --force-with-lease decoy" '{"tool_input":{"command":"git push --force --force-with-lease origin main"}}' destructive-commands.sh
expect_exit 0 "allows --force-with-lease alone"                 '{"tool_input":{"command":"git push --force-with-lease origin main"}}' destructive-commands.sh

expect_exit 2 "blocks unscoped psql DELETE FROM"                '{"tool_input":{"command":"psql -c \"DELETE FROM users\""}}' destructive-commands.sh

# --- A6: blocklist parsing edge cases ---
BLNL=$(mktemp -d)
mkdir -p "$BLNL/.claude"
printf 'acme:demo:(seed|calibrate)' > "$BLNL/.claude/maru-blocklist"
( cd "$BLNL" && printf '%s' '{"tool_input":{"command":"php artisan acme:demo:seed"}}' | "$SCRIPTS/destructive-commands.sh" >/dev/null 2>&1 )
[ $? -eq 2 ] && { PASS=$((PASS+1)); echo "ok - blocklist matches last line with no trailing newline"; } || { FAIL=$((FAIL+1)); echo "FAIL - blocklist matches last line with no trailing newline"; }
rm -rf "$BLNL"

BLIC=$(mktemp -d)
mkdir -p "$BLIC/.claude"
printf '   # indented comment\n' > "$BLIC/.claude/maru-blocklist"
( cd "$BLIC" && printf '%s' '{"tool_input":{"command":"run stuff   # indented comment done"}}' | "$SCRIPTS/destructive-commands.sh" >/dev/null 2>&1 )
[ $? -eq 0 ] && { PASS=$((PASS+1)); echo "ok - blocklist ignores indented comment line"; } || { FAIL=$((FAIL+1)); echo "FAIL - blocklist ignores indented comment line"; }
rm -rf "$BLIC"

BLWS=$(mktemp -d)
mkdir -p "$BLWS/.claude"
printf '   \nacme:demo:(seed|calibrate)\n' > "$BLWS/.claude/maru-blocklist"
( cd "$BLWS" && printf '%s' '{"tool_input":{"command":"php artisan acme:demo:status   details"}}' | "$SCRIPTS/destructive-commands.sh" >/dev/null 2>&1 )
[ $? -eq 0 ] && { PASS=$((PASS+1)); echo "ok - blocklist ignores whitespace-only line"; } || { FAIL=$((FAIL+1)); echo "FAIL - blocklist ignores whitespace-only line"; }
rm -rf "$BLWS"

# --- A7: block messages are contextual, not a generic string ---
expect_msg "maru:"         "block message is maru-branded"           '{"tool_input":{"command":"php artisan db:wipe"}}' destructive-commands.sh
expect_msg "migrate:fresh" "block message names the offending command" '{"tool_input":{"command":"php artisan migrate:fresh"}}' destructive-commands.sh
expect_msg "force-push"    "force-push block message is contextual"   '{"tool_input":{"command":"git push --force origin main"}}' destructive-commands.sh
expect_msg "tinker"        "tinker block message is contextual"       '{"tool_input":{"command":"php artisan tinker --execute=\"Schema::drop(\\\"users\\\")\""}}' destructive-commands.sh

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
