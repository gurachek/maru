---
description: Scaffold CLAUDE.md from the maru template and optionally enable the gate-on-green stop hook
---

Initialize this Laravel project for maru:

1. If the project root has no `CLAUDE.md`, copy `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md` there (Read the template, Write the new file). **Never overwrite an existing CLAUDE.md** — if one exists, show the user which template sections are missing from it instead, and offer to merge.
2. Inspect the project (composer.json, presence of `vendor/bin/sail`, `phpstan.neon*`, eslint config) and replace the template's `<angle-bracket>` placeholders and command examples with the project's real values. Ask the user for the one-paragraph project description rather than inventing it. Also detect and report:
   - `laravel/boost` in composer.json → if absent, recommend `composer require --dev laravel/boost && php artisan boost:install`.
   - `pestphp/pest` in composer.json → note maru's house rule is class-based PHPUnit, and point to the `laravel-feature` skill's precedence rule: don't auto-convert an existing Pest suite.
   - `inertiajs/inertia-laravel` vs `livewire/livewire` → note whether the `frontend-design` skill's stack specifics apply.
   - If you also installed `maru-hooks`, offer to seed `.claude/maru-blocklist` with project-specific destructive/costly command patterns (one case-insensitive regex per line; commands that trigger paid LLM calls belong here). This file has no effect without `maru-hooks`.
3. If you also installed `maru-hooks`, ask the user: "Enable gate-on-green? (runs the full test suite before Claude can finish a turn; skips when another test run is already active)". If yes, create the empty marker file `.claude/gate-on-green` in the project root.
4. Summarize what was created. maru-core itself ships no hooks — if you also installed `maru-hooks`, remind the user that its guard rails (Pint/PHPStan/Prettier/ESLint on edit, forbidden paths, destructive-command blocking) are active immediately. Otherwise recommend `/plugin install maru-hooks@maru` for those guard rails. Also mention that `maru-rls` exists for multi-tenant RLS projects.
