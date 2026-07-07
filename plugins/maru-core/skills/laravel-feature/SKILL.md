---
name: laravel-feature
description: Use when building or modifying any Laravel backend feature (module, model, action, controller, API endpoint). Enforces test-first discipline and the quality gate, with house-style module structure and DTO-at-boundaries that stand down on non-matching stacks (see the ladder inside).
---

# Building a Laravel backend feature

The spine of feature work. Follow it for any new model/action/controller/endpoint. Project-specific conventions live in `CLAUDE.md`; this skill is the workflow.

## Where code goes

Follow the project's module layout — typically `app/Modules/<Context>/` with `Data/ Actions/ Models/ Http/ Policies/ Services/ Events/ Tests/`, where the bounded contexts are listed in `CLAUDE.md`. Create folders per-feature — don't pre-stub empty ones. Cross-module calls go through events or service classes.

If the project has no modules-style layout at all (see the stack detection ladder below), skip this section and use standard Laravel structure instead: `app/Http/Controllers`, `app/Models`, `app/Actions` (or equivalent), etc.

## Module boundaries

Applies only to projects with a modules-style layout (`app/Modules/` or `app/Domain/`). No such layout → this whole section, including the phpat wiring, stands down; there are no cross-module internals to fence off.

A module's `Models`, `Actions`, and other internals are private. Other modules may only touch its **public surface**: domain events it emits, and explicitly public service classes / contracts (convention: `app/Modules/<Context>/Contracts/`, or Services meant for cross-module use). Never `use App\Modules\Other\Models\...` or `App\Modules\Other\Actions\...` from a foreign module — go through an event or a contract instead.

**Enforcement:** this is machine-checkable, not just convention. [phpat](https://www.phpat.dev/) runs as a PHPStan extension, so once it's installed, boundary violations fail automatically on every edit via maru's `php-quality` hook (which runs PHPStan per edited file), and again whenever PHPStan runs in the manually-run quality gate or CI. (The Stop-hook gate runs the test suite only, not PHPStan.) No extra tooling to wire in.

Install it (current package name is `phpat/phpat`; `carlosas/phpat` is the old, now-abandoned name):

```bash
composer require --dev phpat/phpat
```

Wire it into `phpstan.neon`: activate the extension (skip the `includes:` line if the project uses `phpstan/extension-installer` — it activates it automatically) and register each test class as a service tagged `phpat.test`. The architecture-test folder must be inside PHPStan's analysed `paths`. Without this registration PHPStan silently never runs the rules:

```neon
# phpstan.neon
includes:
    - vendor/phpat/phpat/extension.neon

services:
    -
        class: Tests\Architecture\ModuleBoundaryTest
        tags:
            - phpat.test
```

Then write the rule with `PHPat::rule()`. Verified against the phpat docs (`getting-started.md` + `selectors.md`, v0.12.x):

```php
<?php

use PHPat\Selector\Selector;
use PHPat\Test\Builder\Rule;
use PHPat\Test\PHPat;

final class ModuleBoundaryTest
{
    public function test_hiring_does_not_reach_into_scoring_internals(): Rule
    {
        return PHPat::rule()
            ->classes(Selector::inNamespace('App\Modules\Hiring'))
            ->shouldNot()
            ->dependOn()
            ->classes(
                Selector::inNamespace('App\Modules\Scoring\Models'),
                Selector::inNamespace('App\Modules\Scoring\Actions'),
            )
            ->because('cross-module access goes through Scoring\'s Contracts or its emitted domain events, not its internals');
    }
}
```

This example is one directed pair — a real module graph needs coverage for every pair. Either generate a rule method per (module, foreign-module) pair from the module list in `CLAUDE.md`, or use a regex selector for the target side (`Selector::inNamespace('/^App\\\\Modules\\\\.+\\\\(Models|Actions)/', true)` — regex selectors take `true` as the second argument per phpat's selectors doc) with one rule per source module, excluding that module's own namespace: a single all-modules-vs-all-internals rule would also forbid a module from using its *own* `Models`.

Honest limit: without phpat installed, the boundary is convention-only — nothing blocks a `use App\Modules\Other\Models\...` import. The `code-reviewer` agent flags foreign-module model/action imports as a fallback, but that's a review-time catch, not a per-edit gate.

**Already on [deptrac](https://github.com/qossmic/deptrac) or [PHPArkitect](https://github.com/phparkitect/arkitect)?** Keep them — they enforce the same boundaries and are fine choices. maru defaults to phpat only because, as a PHPStan extension, it rides the existing `php-quality` hook and fails **per-edit** with no extra step; deptrac/PHPArkitect run as their own binary, so they gate at CI or a manual run instead. Either is fine — just don't run two boundary checkers.

## The flow

1. **Plan** the files (or use the `laravel-planner` agent).
2. **Test first** (class-based PHPUnit house style — or the project's Pest style if it's Pest-native and hasn't opted into PHPUnit; see the stack detection ladder below): write the failing test, run `php artisan test --filter=...` (via Sail if the project uses it), confirm red.
3. **Implement minimally**: request → **DTO** (spatie/laravel-data) → **Action** (`__invoke`) → response — or, where the project doesn't use spatie/laravel-data and/or Actions (see the stack detection ladder below), its own established shape (e.g. FormRequest → controller → service/Resource). Controllers stay thin either way. Data classes are `final` (never `readonly`); VOs/events are `final readonly`. Domain states are backed enums. State changes dispatch a domain event.
4. **Green**, then refactor.
5. **Quality gate** before done: run the project's format + static analysis + full test suite commands from `CLAUDE.md`.
6. **Small commit** per behavior.

Related skills: `dto-openapi`, `prism-llm`, `disciplined-coding`, and — in multi-tenant projects — `rls-multitenancy`.

## Gotchas (read these)

- **Never return an Eloquent model from a controller** — wrap it in a Data object (or an API Resource, in a FormRequest project — see the ladder below).
- **House style is class-based PHPUnit** — `it()`/`expect()` are for Pest-native projects only (see the ladder below); don't hand-write Pest in a PHPUnit house-style project or vice versa.
- **Same DB engine in tests as production** — don't swap to sqlite for convenience; engine-specific features hide bugs.
- **No business logic in controllers or models** — it lives in Actions (or, absent an Actions convention, well-factored service classes — see the ladder).
- Validate invariants in Value Object constructors; a constructed VO is always valid.
- In multi-tenant RLS projects: every new tenant-scoped table needs RLS + a tenant policy in its migration AND an isolation test (`rls-multitenancy`).
- Every LLM call site needs a `Prism::fake()` test and an audit-table row (`prism-llm`).

## Stack detection ladder

This skill's specifics (DTOs, module layout, class-based PHPUnit) are house style for a project built to match it — check what the project actually has once per session, not per file, and stand down the specifics that don't apply. The underlying principles (thin controllers, no fat models, test-first, validated boundaries) stay universal regardless.

- **No `spatie/laravel-data` in `composer.json`** → the DTO-at-every-boundary rule stands down. FormRequests + API Resources are the convention: validate on the FormRequest, shape responses with a Resource, never leak a raw Eloquent model. Mention once (not a recurring nag) that spatie/laravel-data is available for typed boundaries if the project wants it later, then drop the subject.
- **No modules-style layout** (no `app/Modules/` or `app/Domain/` namespace) → the module-boundary and Actions-folder specifics stand down; standard Laravel structure (`app/Http/Controllers`, `app/Models`, …) applies. Thin controllers and no-fat-models remain universal principles, not module-specific ones.
- **Project's test suite is Pest, and the team hasn't opted into PHPUnit** → write new tests in the project's Pest style, consistent with the existing suite. Class-based PHPUnit is the house rule for greenfield projects and for teams that have deliberately opted into it — it is not license to fork a second test framework into an established Pest codebase. (This extends the pre-existing "don't auto-convert existing tests" rule to also cover brand-new tests.)
- **Established repository pattern already in the codebase** → consistency first: don't flag existing repositories as a violation. Flag only new, redundant repository layers introduced over what a plain Eloquent call would already do.

Where none of these apply — greenfield project, or a stack that already matches — the house style in this skill is the convention, including relative to Laravel Boost's own AI guidelines (e.g. Boost defaults to FormRequests; in a spatie/laravel-data project, this skill's DTO convention wins instead).
