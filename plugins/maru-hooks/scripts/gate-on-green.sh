#!/bin/sh
# Stop hook: refuse to finish a turn while the test suite is red.
# Opt-in per project (.claude/gate-on-green marker). Skips when another
# phpunit run for this project is already in flight — overlapping suite
# runs on a shared test database wreck each other (migrate:fresh drops
# tables mid-run).
. "$(dirname "$0")/runner.sh"
[ -f .claude/gate-on-green ] || exit 0
maru_phpunit_running && exit 0

out=$(maru_artisan test 2>&1)
if [ $? -ne 0 ]; then
  if echo "$out" | grep -Eiq 'Sail is not running|no configuration file provided|Cannot connect to the Docker daemon|docker daemon is not running|is the docker daemon running'; then
    echo 'maru gate: cannot run tests — Sail/containers are not running (start them or check infrastructure); this is NOT a test failure.' >&2
    exit 2
  fi
  echo 'Test suite failing — fix before finishing.' >&2
  echo "$out" | tail -15 >&2
  exit 2
fi
exit 0
