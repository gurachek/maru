# Skills in depth (`maru-core`, `maru-rls`)

Skills activate **automatically** when Claude works in their domain — you don't invoke them; they shape how the agent writes code.

## Detect-and-stand-down

maru's backend opinions detect the stack and stand down rather than apply unconditionally. On a project that differs from the house style — Pest instead of PHPUnit, FormRequests instead of `spatie/laravel-data`, a standard `app/` layout instead of modules, an established repository pattern — the relevant skills and reviewers **keep the universal principles** (thin controllers, test-first, validated boundaries) and **drop the house-style specifics**.

This is the same rule `frontend-design` always applied to non-Inertia/Vue stacks, now extended to `laravel-feature` and the reviewer agents. The one place hard rules stay absolute is the greenfield `CLAUDE.md` template that `/maru-core:init` scaffolds.

---

## `laravel-feature` (maru-core)

The spine of backend feature work:

> module placement → failing test → minimal `request → DTO → Action → response` → quality gate (format + static analysis + full suite) → small commit.

Carries the hard gotchas: never return Eloquent models from controllers; house-style class-based PHPUnit; no logic in controllers or models; same DB engine in tests as production. Includes the stack-detection ladder — on a project without `spatie/laravel-data`, modules, or PHPUnit, the matching specifics stand down and the project's own convention (FormRequests, standard `app/` layout, Pest) applies instead.

**Machine-checkable module boundaries:** a module's `Models`/`Actions` are private; other modules reach it only through its emitted events or public `Contracts`. Install [phpat](https://www.phpat.dev/) and the existing PHPStan hook enforces this on every edit — no extra tooling. (Already on [deptrac](https://github.com/qossmic/deptrac) or [PHPArkitect](https://github.com/phparkitect/arkitect)? Keep them — maru defaults to phpat only because, as a PHPStan extension, it fails per-edit through the hook; the others gate at CI or a manual run. Don't run two.)

*Triggers when building or modifying any backend feature.*

## `dto-openapi` (maru-core)

The boundary-data contract: every value crossing a boundary (request input, Inertia prop, event payload, LLM in/out) is a `spatie/laravel-data` object. When to pick `Data` vs. `Dto` vs. a plain value object; validation lives on the Data class, not a duplicate FormRequest; TypeScript generation for typed frontend props; REST conventions (versioned prefix, RFC 9457 `problem+json` errors, HMAC-verified webhooks, idempotent bulk writes, cursor pagination).

*Triggers when creating DTOs, request/response shapes, or API endpoints.*

## `prism-llm` (maru-core)

The LLM discipline for [Prism](https://prismphp.com): every model call lives behind a single-purpose service class with typed input/output DTOs; every call writes an audit row (`llm_calls` convention — prompt version, model, tokens, cost, latency, causation ids); temperature 0 for deterministic pipelines; user-supplied text is data, never instructions (prompt-injection guardrails); `Prism::fake()` tests are mandatory per call site, and accuracy evals stay out of CI.

*Triggers when writing or testing anything that calls a model.*

## `frontend-design` (maru-core)

Rules for calm, dense, keyboard-first power-user UIs (think Linear / Superhuman, not a marketing site): 32–40px table rows, human-readable first columns, command palette on every screen, side panels over modals, optimistic UI with rollback, skeletons sized to real content, one restrained accent color, headless-primitive accessibility, and a hard "avoid" list (heroes, gradients, scroll animation, spinner abuse).

*Triggers when building or editing Vue/Inertia pages in that idiom.*

## `disciplined-coding` (maru-core)

The working agreement that keeps autonomous sessions honest: test-first always, small commits per behavior, file-size limits with named smells, and a hard stop on cascading fixes — if two attempts haven't fixed it, stop and reassess rather than piling a third change on top.

*Triggers before any implementation work.*

## `rls-multitenancy` (maru-rls)

The roll-your-own Postgres RLS pattern: tenant id on every row + a session GUC set by middleware + `SET ROLE` to a least-privilege database role so policies actually apply; the `USING` / `WITH CHECK` policy shapes; the fail-open trap (CLI and queue workers bypass web middleware — every command/job must set tenant context explicitly); and the testing law — every tenant table gets an isolation test, with a canary proving RLS is active (a table-owner role passes vacuously).

*Triggers when adding tenant-scoped tables or writing tenant-aware queries.*
