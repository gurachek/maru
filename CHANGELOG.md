# Changelog

## 0.3.0 — 2026-07-03

Breaking restructure: split the hook layer out of maru-core into its own
installable plugin, `maru-hooks`. No external users yet, so this is free.

### Why
Audience research showed the hook layer — Pint/PHPStan/Prettier/ESLint on
edit, forbidden-path and destructive-command blocking, the project-extensible
blocklist, and opt-in gate-on-green — is the universally-wanted piece: it
works on any Laravel stack, with no opinion about DTOs, module boundaries, or
TDD workflow. maru-core's agents and skills are opinionated by design (they
assume spatie/laravel-data, Inertia+Vue, class-based PHPUnit). Bundling them
forced an all-or-nothing install; splitting them means a team can adopt the
guard rails alone and opt into the rest of maru's conventions later, or never.

### Changed
- **New plugin `maru-hooks`** (0.3.0): `hooks/` and `scripts/` moved out of
  `maru-core` unchanged — `${CLAUDE_PLUGIN_ROOT}`-relative paths inside
  `hooks.json` keep working with no edits. Installable standalone.
- **maru-core** (0.2.0 → 0.3.0): now TDD workflow agents, reviewers, skills,
  and `/maru-core:init` only — no bundled hooks. `/maru-core:init` still
  offers to seed the blocklist and enable gate-on-green, but only when
  `maru-hooks` is also installed.
- `.claude-plugin/marketplace.json`: `maru-hooks` listed first (broadest
  appeal), descriptions updated for both plugins' narrowed scope.
- README: tiered install instructions (hooks-only / full kit / +RLS), a new
  `maru-hooks` table in "What you get", "Hooks (maru-core)" renamed to
  "Hooks (maru-hooks)".
- `tests/hooks_test.sh` now points at `plugins/maru-hooks/scripts`; still
  57/57.
- `maru-rls` unchanged, stays at 0.2.0.

### Stack detect-and-stand-down
Further audience research: the mainstream Laravel senior uses Pest,
FormRequests, standard `app/Http`/`app/Models` (no modules), sometimes
repositories — maru-core's opinionated backend skills/agents previously
preached house style at them unconditionally, so reviewers nagged correct
code and implementers forked a Pest suite with PHPUnit tests. `laravel-feature`
now leads with a stack detection ladder; reviewers and implementers follow it
instead of an unconditional house style:
- No `spatie/laravel-data` in `composer.json` → DTO-at-every-boundary stands
  down; FormRequests + API Resources are the convention (suggested once, not
  nagged).
- No modules-style layout (no `app/Modules/`/`app/Domain/`) → module-boundary
  and Actions-folder specifics stand down; standard Laravel structure
  applies; thin-controllers/no-fat-models stay universal.
- Project's test suite is Pest and the team hasn't opted into PHPUnit → new
  tests follow the project's Pest style; class-based PHPUnit is the house
  rule for greenfield projects and teams that opt in.
- Established repository pattern in the codebase → consistency first; only
  new, redundant repositories over plain Eloquent get flagged.

`code-reviewer`, `dto-api-reviewer`, `tdd-implementer`, and `test-writer` all
carry the same calibration; `dto-openapi` gets a `frontend-design`-style
stack precondition. The greenfield `templates/CLAUDE.md` is unchanged by
design — it's the artifact that *establishes* house style for a new project,
so its hard rules stay absolute.

## 0.2.0 — 2026-07-03

Hardening + Laravel Boost integration pass, driven by an adversarial review
of v0.1.0.

### Safety hooks
- **Fail closed without `jq`**: `forbidden-paths` and `destructive-commands`
  now block (exit 2) with a clear message when `jq` is missing, instead of
  silently becoming no-ops. Quality hooks still fail open by design.
- **Laravel-aware destructive patterns**: `migrate:refresh`/`migrate:reset`
  join `migrate:fresh`; destructive `tinker` payloads (`Schema::drop`,
  `->truncate(`, `->forceDelete(`, raw drop/truncate/delete SQL); direct
  `psql`/`mysql` drop/truncate/unscoped-delete.
- **Force-push guard closed against real bypasses**: bundled short flags
  (`-uf`, `-fu`, `-4f`), and a decoy `--force-with-lease` no longer masks a
  genuine `--force` (the lease flag is stripped before detection);
  `--force-with-lease` alone remains allowed.
- **Project-extensible blocklist**: `.claude/maru-blocklist` (one
  case-insensitive ERE per line, `#` comments) — for project-specific
  destructive commands and anything that spends money on LLM calls.
- Documented threat model: the guard stops *accidental* destructive
  commands; deliberate obfuscation is out of scope — backups and a
  non-superuser DB role are the durable layer.

### gate-on-green
- Distinguishes "Sail/containers are down" from "test suite failing" and
  surfaces the last 15 lines of real output instead of a generic message.
- Concurrency guard is now project-scoped (process cwd match via
  /proc/lsof) — an unrelated repo's PHPUnit run can no longer make the gate
  silently skip; Sail service name read from `APP_SERVICE`.

### Laravel Boost integration
- Removed the bundled `laravel-best-practices` skill — it was Boost's own
  guidelines pack; install [Laravel Boost](https://github.com/laravel/boost)
  for the living version plus its MCP tools and docs search.
- Boost MCP tools added to agent allowlists and instructions:
  `laravel-planner` gets the read-only set (`search-docs`,
  `database-schema`, `application-info`); `tdd-implementer` additionally
  gets `database-query` and `tinker` for read-only verification (with an
  explicit no-mutations-via-tinker rule — that path bypasses the
  destructive-command guard).
- `/maru-core:init` detects Boost, Pest, and Inertia-vs-Livewire, and
  offers to seed the blocklist.

### Content corrections
- **Fixed a crash-producing rule**: Data classes are `final`, never
  `final readonly` (spatie/laravel-data's base class is non-readonly — a
  readonly subclass is a PHP fatal). `final readonly` is for plain value
  objects and domain events only. Was stated wrongly in five files.
- `frontend-design`/`ui-ux-reviewer` gained a stack precondition — the
  Inertia+Vue specifics stand down in Blade/Livewire projects.
- RLS policy cast parameterized (`::uuid` vs `::bigint` per tenant key
  type), with a matching reviewer checklist item.
- `disciplined-coding` origin-project claims rewritten as generic rules.
- `code-reviewer` re-centered on structural accumulation (AI-era codebases:
  duplication up, refactoring down) — its differentiated job next to the
  built-in `/code-review`.
- Precedence rules added (`laravel-feature`): greenfield → maru house
  style; brownfield → the codebase's pattern wins; Data objects supersede
  Boost's FormRequest guideline where spatie/laravel-data is installed;
  existing Pest suites are not auto-converted.

### Module boundaries (new)
- `laravel-feature` now defines the module public surface (events +
  Contracts) and shows machine-checked enforcement via
  [phpat](https://www.phpat.dev/) (`phpat/phpat`, a PHPStan extension the
  existing php-quality hook picks up automatically), including full
  phpstan.neon wiring and module-graph coverage guidance.

### Test harness
- 25 → 57 cases, covering every new pattern both ways, jq-absence,
  blocklist parsing edge cases, and decoy-PHPUnit concurrency scenarios.

## 0.1.0 — 2026-07-03

Initial release: maru-core (6 agents, 6 skills, 5 hooks, /maru-core:init)
and maru-rls (RLS reviewer + multitenancy skill).
