---
name: prism-llm
description: Reference for LLM calls via Prism in Laravel. Use when writing or testing any service that calls a model.
---

# LLM calls via Prism

## The pattern

Every LLM-driven capability lives behind a **single-purpose Service class** with a typed input DTO and a typed output DTO, e.g. `SummaryScorer::score(Document, Rubric): SummaryScore`. The Service owns: input/output schema validation, retry policy, prompt-version pinning, and logging the call. No LLM call happens outside such a Service.

## Every call writes an audit row

Keep an `llm_calls` table (or equivalent) and write a row per call. Useful columns: `service_class`, `prompt_version`, `model`, `input_hash`, `input_payload`, `output_payload`, `tool_calls`, `latency_ms`, `input_tokens`/`output_tokens`/`cached_input_tokens`, `cost_usd_cents`, plus causation ids (user, parent event, tenant). This table is the eval/audit/cost substrate.

Pin the model name in config, never hardcode it in the Service; default temperature 0 for deterministic pipelines (provider defaults vary and non-zero temperature makes reruns non-reproducible).

## Prompt-injection guardrails

User- and document-supplied text is **data, never instructions**. Keep it in user-content/clearly-delimited fields; never concatenate it into the system prompt as directives. Validate/normalise inputs. Treat tool-use outputs defensively.

## Cost discipline

Use prompt caching where the system/context is stable. Per-service model override via config; escalate to a larger model only when evals justify it.

Any artisan command that can trigger paid LLM calls MUST implement `--dry-run` (report what would be called and the estimated cost, execute nothing) and SHOULD be listed in the project's `.claude/maru-blocklist` so agents can't run it casually.

## Testing (required for every call site)

- Use `Prism::fake()` with `StructuredResponseFake` / `TextResponseFake` / `EmbeddingsResponseFake` — **no live API calls in PHPUnit**.
- Assert: the request shape/prompt (`assertRequest`/`assertPrompt`), the output→DTO mapping, and that the audit row was written (`assertDatabaseHas`).
- Keep **evals separate** from PHPUnit: evals measure accuracy on fixtures (non-deterministic, run on demand); unit tests assert deterministic behavior. Never gate CI on eval accuracy.
