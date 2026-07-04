# <Project Name>

<!-- This is the greenfield template: it establishes house style for a new
     project, so its rules below are intentionally absolute, not conditional.
     maru's skills/agents stand down these specifics on existing projects
     whose stack demonstrably differs (Pest, FormRequests, no modules,
     established repositories) — see laravel-feature's stack detection
     ladder. That calibration doesn't apply here, since there's no existing
     stack yet to detect. -->

<One paragraph: what the app does, who it serves, and the 2-3 non-negotiable
technical invariants (e.g. strict types everywhere, append-only audit events).>

## Commands

<!-- If the project uses Sail, prefix with ./vendor/bin/sail -->
- Test: `php artisan test` (single: `--filter=Name`)
- Format: `vendor/bin/pint --dirty`
- Static analysis: `vendor/bin/phpstan analyse`

## Architecture

- <Module layout, e.g. modular monolith: `app/Modules/<Context>/{Data,Actions,Models,Http,Policies,Services,Events,Tests}`. List the bounded contexts.>
- <Frontend stack, e.g. Inertia + Vue 3 + TypeScript.>
- <Anything cross-cutting: multi-tenancy model, audit spine, LLM gateway.>

## Conventions — YOU MUST

- `declare(strict_types=1)` in every PHP file (let Pint inject it).
- DTOs use spatie/laravel-data at every boundary (request, Inertia prop, event payload, LLM in/out). Never return Eloquent models from controllers.
- Value Objects / domain events are `final readonly`; VOs validate invariants in the constructor.
- Business logic lives in Actions (single `__invoke`). Controllers only: validate → DTO → Action → response.
- All domain states are backed enums with methods. No magic strings.
- `#[\Override]` on every override / interface implementation.
- TDD: write the failing PHPUnit test first, then implement (see the `disciplined-coding` skill).
- Before claiming done: format + static analysis + full test suite must pass.

## Do NOT

- No Pest — class-based PHPUnit only; never `it()`/`expect()`.
- No repository pattern over Eloquent. No god classes / fat controllers / fat models.
- No editing `vendor/`. No `migrate:fresh` on shared databases. No sqlite in tests when production is not sqlite.
