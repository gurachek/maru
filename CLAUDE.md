# maru — working notes for agents

Claude Code plugin marketplace for Laravel: `maru-hooks` (stack-agnostic guard
rails), `maru-core` (opinionated agents/skills/init), `maru-rls` (Postgres RLS
add-on). Extracted from Vesna (https://tryvesna.ai) and publicly attributed —
never scrub that again; the provenance is a feature.

## Commands

- Test: `./tests/hooks_test.sh` (57 cases, dependency-free POSIX sh; must stay
  green — run before every commit that touches `plugins/maru-hooks/scripts/`)
- Validate manifests: `find . -name '*.json' -not -path './.git/*' -exec jq empty {} +`
  and `claude plugin validate .`

## Non-negotiables

- Hook scripts are POSIX sh (`#!/bin/sh`), executable, quoted against
  paths-with-spaces. **Safety hooks (forbidden-paths, destructive-commands)
  fail CLOSED** (missing `jq` → exit 2); quality hooks and gate-on-green fail
  open (missing tool → skip). Never invert this.
- The destructive-command guard's threat model is *accidental* commands, not
  a sandbox — keep the README honest about that; don't chase obfuscation
  classes (quoting, env indirection) that regexes can't close.
- TDD for script changes: add the failing harness case to
  `tests/hooks_test.sh` (before its final three summary lines, via
  `expect_exit`) first.
- Data classes are `final`, never `readonly` (spatie/laravel-data base class
  is non-readonly → readonly subclass is a PHP fatal). This was shipped wrong
  once; the "why" is inline in the skills — don't "fix" it back.
- Opinionated content must **detect-and-stand-down**: house style applies on
  matching stacks and greenfield; on Pest-native / FormRequest / no-modules
  projects the specifics yield (see laravel-feature's ladder). The greenfield
  CLAUDE.md template is the one place hard rules stay absolute.
- Laravel Boost is the designed companion, never bundled: don't re-vendor its
  guidelines; agents reference Boost MCP tools, and MCP tools must be named
  explicitly in agent `tools:` frontmatter or they're unreachable.
- Versioning: bump the affected plugin(s) + CHANGELOG entry per release; keep
  untouched plugins at their version (maru-rls lags deliberately).
- Genericization: no other private project names in shipped content;
  `vesna:*` in test fixtures is intentional (attributed provenance).

## Roadmap (v0.4 candidates, from the 2026-07 persona reviews)

1. Demo gif/asciinema: a hook blocking `migrate:fresh` live — top conversion
   asset for sharing.
2. GitHub Actions workflow running `tests/hooks_test.sh` (the repo preaches
   verification and has no CI — fix the irony).
3. Quality hooks: surface real PHPStan/ESLint output on failure instead of
   the generic "X failed" (currently `>/dev/null 2>&1`).
4. Per-hook enable/disable via project settings, not plugin-wide only.
5. LLM-cost guard: `init` could grep `app/Console/Commands` for `Prism::`
   usage and pre-seed `.claude/maru-blocklist` instead of relying on memory.
6. Sail-branch harness coverage (MARU_SAIL=1 path is only manually verified);
   interactive `/plugin install` end-to-end has still never been exercised.

## History note

v0.1.0 → v0.3.0 all shipped 2026-07-03: 0.2.0 was an adversarial-review
hardening pass (real force-push bypasses found and closed), 0.3.0 split
maru-hooks out and added the stand-down ladder after a three-persona
audience review. Full narrative in CHANGELOG.md; the spec that started it is
docs/specs/2026-07-02-maru-design.md.
