---
name: dto-openapi
description: Reference for spatie/laravel-data DTO patterns and an OpenAPI/TypeScript pipeline. Use when creating DTOs, request/response shapes, or API endpoints.
---

# DTOs, TypeScript, and the API contract

Reference for boundary data.

**Stack precondition:** the DTO law below assumes `spatie/laravel-data` is in the project's `composer.json`. If it isn't, this skill's DTO specifics stand down — the project's convention is FormRequests for validation and API Resources (or plain arrays) for responses; review and build on those terms rather than introducing Data objects unasked. The API conventions section (REST shape, `problem+json`, idempotency, pagination) is stack-agnostic and applies regardless.

## DTO law

Every value crossing a boundary is a spatie/laravel-data object — HTTP request input, Inertia props, event payloads, LLM service in/out. Choose:
- **`Data`** for boundary objects needing validation / TS / transformation.
- **`Dto`** for internal typed carriers (lighter, no resource machinery).
- **plain `final readonly` class** for pure Value Objects.

Data classes live with their module (e.g. `app/Modules/<Context>/Data`), are `final` (never `readonly` — the base `Data` class is not readonly, so a `final readonly` subclass is a PHP fatal), and — when the project generates TypeScript — annotated `#[TypeScript]`. Configure global snake↔camel mapping once — don't hand-map per property.

## Validation

Lives on the Data object: validation attributes first; `rules()` + `#[MergeValidationRules]` for dynamic rules; `authorize()` for gating. Don't duplicate as a separate FormRequest. Validation runs before construction — a constructed Data object is valid.

## TypeScript pipeline (when the frontend is typed)

`php artisan typescript:transform` → a generated `.d.ts` the frontend imports for typed Inertia props. Regenerate (and never hand-edit the generated file) whenever Data classes change; fail CI on drift; cache Data structures on deploy (`data:cache-structures`).

## LLM DTOs

Version them (`RankRequestV1`, `…V2`, or a `promptVersion` field) and persist the version alongside the logged call so audit logs stay decodable as prompts evolve.

## API conventions

Versioned prefix (`/api/v1`), plural kebab nouns, ≤1 nesting; errors as `application/problem+json` (RFC 9457) via the central handler; Sanctum PAT + abilities for machine endpoints; webhooks verify HMAC with `hash_equals`; bulk writes use Idempotency-Key + 202 + status URL; lists use spatie/laravel-query-builder (whitelisted) + cursor pagination. API docs can auto-generate via Scramble (gate the docs route in prod).

## When NOT to use a Data object

Large list endpoints (thousands of rows) — Data reflection is costly; return lean arrays/queries instead.
