# maru — Claude Code plugin kit for Laravel

**Date:** 2026-07-02
**Status:** approved (brainstorm with Valerii, 2026-07-02)

## Goal

Extract the AI tooling built inside the source app (`.claude/` agents, skills, hooks,
CLAUDE.md conventions) into a standalone GitHub repo that any Laravel project can adopt
with two commands:

```
/plugin marketplace add <user>/maru
/plugin install maru-core@maru
```

Primary audience: the author's future Laravel projects. Public visibility is welcome but
not the driver — keep the opinionated defaults, write the README so a stranger can still
use it.

## Non-goals

- Not a Composer package, not a copy-in template. Distribution is a Claude Code plugin
  marketplace only (updates propagate; no per-project file drift).
- No vendoring of third-party skills that live upstream (`shadcn-vue` is excluded; the
  README points to its upstream install).
- No support matrix beyond Laravel 11+ with Pint; hooks degrade gracefully when a tool
  (Larastan, ESLint) is absent.

## Naming

- Repo / marketplace: **maru**
- Plugins: **maru-core** (generic Laravel discipline) and **maru-rls** (Postgres RLS
  multi-tenancy — split out because future projects may be single-tenant, and its
  reviewer produces false findings in single-tenant apps).

## Repo structure

```
maru/
├── .claude-plugin/marketplace.json      # lists maru-core, maru-rls
├── plugins/
│   ├── maru-core/
│   │   ├── .claude-plugin/plugin.json
│   │   ├── agents/
│   │   │   ├── laravel-planner.md
│   │   │   ├── tdd-implementer.md
│   │   │   ├── test-writer.md
│   │   │   ├── code-reviewer.md
│   │   │   ├── dto-api-reviewer.md
│   │   │   └── ui-ux-reviewer.md
│   │   ├── skills/
│   │   │   ├── laravel-best-practices/  # verbatim; MIT, author: laravel (attribution kept)
│   │   │   ├── laravel-feature/
│   │   │   ├── dto-openapi/
│   │   │   ├── prism-llm/
│   │   │   ├── frontend-design/
│   │   │   └── disciplined-coding/      # promoted from ~/.claude/skills
│   │   ├── commands/init.md             # /maru-core:init — scaffolds CLAUDE.md, offers gate-on-green
│   │   ├── hooks/hooks.json
│   │   └── scripts/                     # runner.sh + one script per hook
│   └── maru-rls/
│       ├── .claude-plugin/plugin.json
│       ├── agents/rls-security-reviewer.md
│       └── skills/rls-multitenancy/
├── templates/CLAUDE.md                  # starter project conventions file
├── docs/specs/                          # this spec
├── README.md
└── LICENSE                              # MIT (laravel-best-practices keeps its own MIT header)
```

## Genericization rules

Applied to every agent/skill copied from the source app:

1. Strip the project name, internal docs paths, module lists, and pinned stack
   versions ("Laravel 13 / PHP 8.5" → "the project's pinned versions").
2. Replace source-app-specific identifiers with conventions: role `app_runtime` → "your
   least-privilege app role", `llm_calls` → "your LLM audit table", source-app pages/tokens in
   frontend guidance → "your project's design tokens".
3. Keep the opinions: thin controllers → Actions, `final readonly` VOs, spatie/laravel-data
   DTOs at boundaries, backed enums, `#[\Override]`, TDD-first, calm/dense/keyboard-first
   UI default.
4. `disciplined-coding` keeps its rules, drops the source app's war story.
5. `laravel-best-practices` ships byte-identical to upstream (MIT, `author: laravel`).

## Hooks (maru-core)

All hooks are defined in `hooks/hooks.json` and call scripts via
`${CLAUDE_PLUGIN_ROOT}/scripts/…`. A shared `runner.sh` is sourced first and decides the
execution prefix once per invocation:

- `vendor/bin/sail` exists and is executable → prefix commands with `./vendor/bin/sail`
  (`sail pint`, `sail artisan test`, `sail npx …`).
- Otherwise run directly: `vendor/bin/pint`, `php artisan`, `npx`.

So the same hooks work on Sail, Herd, and Valet with zero configuration.

| Hook | Event | Behavior | Default |
|---|---|---|---|
| php-quality | PostToolUse (Edit\|Write, `*.php`) | Pint the file; then Larastan **iff** available (composer `lint` script or `vendor/bin/phpstan`); exit 2 on Larastan failure | on |
| js-quality | PostToolUse (Edit\|Write, `*.vue`/`*.ts`) | Prettier write; ESLint **iff** a config exists; exit 2 on ESLint failure | on |
| forbidden-paths | PreToolUse (Edit\|Write) | Block `vendor/`, `.env`, generated files (`storage/api-docs`, generated TS types) | on |
| destructive-commands | PreToolUse (Bash) | Block `rm -rf /`, `migrate:fresh`, `git push --force`, `drop database` | on |
| gate-on-green | Stop | Run the full test suite; exit 2 with "fix before finishing" on red | **opt-in** |

### gate-on-green details

- **Opt-in per project:** fires only when the project contains a `.claude/gate-on-green`
  marker file (created by `/maru-core:init` on request). New projects get the fast hooks
  by default.
- **Concurrency guard (lesson learned 2026-07-02):** before running, check whether a
  PHPUnit process is already running (in the Sail container via
  `sail exec -T laravel.test sh -c 'ps ax | grep -q "[p]hpunit"'`, or `pgrep -f phpunit`
  on the host in non-Sail mode) and **skip (exit 0)** if so. Without this, back-to-back
  turn ends overlap ~50 s suite runs against the shared test database, and
  `RefreshDatabase`'s `migrate:fresh` in one run drops tables under the other —
  producing phantom failures (`relation does not exist`, `25P02` aborted-transaction
  cascades, deadlocks). Reproduced and diagnosed on the source app.
- Timeout 600 s.

## `/maru-core:init` command

A small slash command that:

1. Copies `templates/CLAUDE.md` into the project root if no CLAUDE.md exists (never
   overwrites), then tells the user which placeholders to fill (project name, test
   runner, domain notes).
2. Asks whether to enable gate-on-green; if yes, creates `.claude/gate-on-green`.

## maru-rls plugin

- `agents/rls-security-reviewer.md` — reviews diffs for tenant-isolation regressions.
- `skills/rls-multitenancy/` — the RLS pattern reference: GUC-based tenant GUC +
  `SET ROLE` least-privilege runtime role, asymmetric `WITH CHECK`, fail-open CLI/queue
  warning (explicit `Tenant::set()` / `bypassRls()`), RLS isolation test per tenant table.
- Genericized per the rules above; the pattern's moving parts (role name, GUC name,
  facade name) are presented as conventions with the source app's defaults as examples.

## README outline

1. What this is (one paragraph) + install (two commands).
2. Table: what each plugin ships (agents / skills / hooks / commands).
3. `/maru-core:init` and the CLAUDE.md template.
4. gate-on-green: what it does, how to enable, the concurrency guard.
5. When to install maru-rls.
6. shadcn-vue: install from upstream.
7. Customization notes (hooks degrade gracefully; how to disable one).
8. License: MIT; `laravel-best-practices` skill © Laravel, MIT.

## Verification plan

1. `claude plugin validate` (or manual JSON check) on marketplace + both plugin manifests.
2. Add the marketplace from the local path in a scratch session; install both plugins;
   confirm agents and skills appear and commands resolve.
3. Hook smoke tests in two environments:
   - the source app (Sail present) — edit a PHP file with a deliberate Larastan error →
     hook exits 2; forbidden path blocked; destructive command blocked.
   - a scratch non-Sail Laravel app — same checks via the direct-runner path.
4. gate-on-green: with marker absent → no suite run on Stop; with marker present and a
   failing test → Stop blocked; with a concurrent phpunit running → skipped.

## Risks / open items

- Plugin-shipped hooks apply wherever the plugin is enabled; a project that wants
  different forbidden paths must override in its own settings. Documented in README.
- `laravel-best-practices` drifts from upstream over time; note the upstream source in
  the README for manual refresh.
- Repo name "maru" is a placeholder-grade decision; rename is cheap before first push.
