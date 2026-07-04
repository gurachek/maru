#!/bin/sh
# Shared runner detection: prefer Laravel Sail when the project ships it,
# fall back to direct binaries (Herd / Valet / plain PHP).
MARU_SAIL=0
[ -x ./vendor/bin/sail ] && MARU_SAIL=1

MARU_APP_SERVICE=laravel.test
if [ -f ./.env ]; then
  _maru_svc=$(grep -E '^APP_SERVICE=' ./.env | cut -d= -f2)
  [ -n "$_maru_svc" ] && MARU_APP_SERVICE=$_maru_svc
fi

maru_bin() { # maru_bin pint --dirty  → vendor/bin tool, through Sail when present
  _tool=$1; shift
  if [ "$MARU_SAIL" = 1 ]; then ./vendor/bin/sail bin "$_tool" "$@"; else "./vendor/bin/$_tool" "$@"; fi
}

maru_artisan() {
  if [ "$MARU_SAIL" = 1 ]; then ./vendor/bin/sail artisan "$@"; else php artisan "$@"; fi
}

maru_npx() {
  if [ "$MARU_SAIL" = 1 ]; then ./vendor/bin/sail npx "$@"; else npx "$@"; fi
}

maru_phpunit_running() { # exit 0 if a phpunit run for THIS project is already in flight
  if [ "$MARU_SAIL" = 1 ]; then
    ./vendor/bin/sail exec -T "$MARU_APP_SERVICE" sh -c 'ps ax | grep -q "[p]hpunit"' >/dev/null 2>&1
    return $?
  fi

  # Resolve our own cwd to its physical path: macOS puts $TMPDIR (and
  # therefore mktemp -d output) under /var/..., a symlink to /private/var/...
  # — lsof/readlink report the resolved physical path, so a naive
  # comparison against logical $PWD false-negatives on every macOS tmpdir.
  _root=$(pwd -P)

  _pids=$(pgrep -f phpunit 2>/dev/null) || return 1
  for _pid in $_pids; do
    if [ -d /proc ]; then
      _cwd=$(readlink "/proc/$_pid/cwd" 2>/dev/null)
    elif command -v lsof >/dev/null 2>&1; then
      _cwd=$(lsof -a -p "$_pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')
    else
      # Neither /proc nor lsof is available to scope the match by cwd. The
      # old behavior fell back to a machine-wide `pgrep -f phpunit`, which
      # false-SKIPs the gate whenever *any* phpunit is running anywhere on
      # the box — silently letting two unrelated suites collide on a
      # shared test database (the exact bug this guard exists to prevent).
      # Treat as NOT running instead: worst case here is a redundant
      # `test` run, not a corrupted database.
      _cwd=""
    fi
    [ -n "$_cwd" ] && [ "$_cwd" = "$_root" ] && return 0
  done
  return 1
}
