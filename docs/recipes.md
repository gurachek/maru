# Recipes

End-to-end workflows once the plugins are installed.

## Bootstrap a new project

```
/plugin install maru-hooks@maru
/plugin install maru-core@maru
/maru-core:init
```

`init` scaffolds a `CLAUDE.md` from the template (never overwriting an existing one), fills in what it can detect (Sail vs. direct commands, PHPStan/ESLint presence), asks you for the one-paragraph project description, and offers to enable gate-on-green. From that point every session in the project inherits the conventions.

## Build a feature end-to-end

1. **Plan** — *"Use the laravel-planner agent to plan the invoicing feature."*
   You get a file-level plan — module placement, DTOs, Actions, migrations, and the exact tests required — with open questions listed instead of guessed at. The planner **cannot edit files**, so exploration never turns into premature implementation.
2. **Implement** — *"Implement task 1 of the plan with tdd-implementer."*
   One task at a time, red → green → refactor, quality gate before every "done".
3. **Harden** — *"Run test-writer over the new module"* to backfill edge cases, error paths, and side-effect assertions the happy-path tests missed.

## Review before a PR

Dispatch the reviewers that match the diff — each reports findings with `file:line` and a concrete fix, and **none of them can edit**:

| Diff touches | Reviewer |
|---|---|
| any backend change | `code-reviewer` (SOLID, thin controllers, enums, debug leftovers, god classes) |
| controllers / DTOs / API routes | `dto-api-reviewer` |
| Vue components or pages | `ui-ux-reviewer` |
| models / migrations / queries / auth in a multi-tenant app | `rls-security-reviewer` (maru-rls) |
| general security | Claude Code's built-in `/security-review` — maru adds the domain layers (tenant isolation via `maru-rls`, LLM prompt-injection via `prism-llm`) |

## Turn on the merge gate

```
touch .claude/gate-on-green
```

From then on Claude cannot end a turn in that project while `php artisan test` is red — *"it should pass now"* stops being an acceptable sign-off. The gate skips itself when another PHPUnit run is already in flight (see [docs/hooks.md](hooks.md#why-it-has-a-concurrency-guard)) and stays out of projects that haven't opted in.

## Ship an LLM-backed feature

Ask for the feature normally; `prism-llm` steers the shape: a dedicated service class, versioned DTOs in and out, an audit row per call, and a `Prism::fake()` test — so six months later you can still answer *"which prompt version produced this output, and what did it cost?"*

## Make a project multi-tenant safely

Install `maru-rls`, then build tables and queries as usual — `rls-multitenancy` injects the policy SQL and isolation-test requirements as you go, and `rls-security-reviewer` audits the diff for scope bypasses, mass-assignable tenant ids, and un-scoped commands/jobs before they reach production.

## Keep refactoring

AI-era codebases show collapsing refactoring rates: GitClear's 2025 analysis found refactored lines fell from ~24% to under 10% of changes while code duplication rose 8× — agents extend rather than restructure. Hooks can enforce tests and formatting on every edit, but they can't force a simplification pass; that takes deliberate cadence. Schedule one periodically — the built-in `/simplify` or the `code-reviewer` agent over a module — so structure debt doesn't silently accumulate between features.
