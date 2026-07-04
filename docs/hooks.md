# Hooks in depth (`maru-hooks`)

Deterministic shell guards — the layer the model can't rationalize past. They need `jq` on the host and degrade gracefully: a tool that isn't installed is skipped, never blocking. The two **safety** hooks are the exception — they **fail closed**.

## Fail-open vs. fail-closed

| Hook | Type | Missing tool → |
|---|---|---|
| `php-quality`, `js-quality`, `gate-on-green` | quality / gate | **skip** (fail open) — a missing linter never blocks work |
| `forbidden-paths`, `destructive-commands` | safety | **exit 2, refuse** (fail closed) — no `jq`, no run |

Safety hooks refusing to run without `jq` is deliberate: they'd rather block than silently let an irreversible command through.

## Runner detection

If `vendor/bin/sail` exists, commands go through Sail (`sail bin pint`, `sail artisan test`); otherwise they run directly (`vendor/bin/pint`, `php artisan test`). No configuration.

## The hooks

### `php-quality` (PostToolUse)
Pint formats every edited PHP file; PHPStan (when installed with a config) blocks on errors.

### `js-quality` (PostToolUse)
Prettier + ESLint on edited `.vue`/`.ts`/`.tsx` files.

### `forbidden-paths` (PreToolUse)
Blocks edits to `vendor/`, `node_modules/`, `.env*`, build artifacts, and generated types.

### `destructive-commands` (PreToolUse)
Blocks, before execution:

- `migrate:(fresh|refresh|reset)`, `db:wipe`, `drop database`, `rm -rf /`
- git force-push (`-f` / `--force`) — but `--force-with-lease` is allowed
- destructive `tinker` payloads (`Schema::drop`, `->truncate(`, `->forceDelete(`, raw SQL)
- direct `psql` / `mysql` drop / truncate / unscoped-delete

Projects extend the blocklist with a `.claude/maru-blocklist` file — one case-insensitive ERE pattern per line, `#` comments allowed.

**Threat model (be honest about it):** this guards against *accidental* destructive commands, not a malicious sandbox. Deliberately obfuscated forms (quoted flags, env indirection, heredocs) can evade any command-string pattern, and MCP tools (e.g. Boost's `tinker`) are a separate channel the Bash guard never sees. The durable protections underneath are **database backups** and a **non-superuser DB role**.

### `gate-on-green` (Stop, **opt-in**)
Refuses to let Claude finish a turn while `php artisan test` is red. Enable per project by creating `.claude/gate-on-green` (or saying yes in `/maru-core:init`). If the suite can't run at all (Sail/Docker down) it says so explicitly instead of reporting a test failure — "it should pass now" stops being an acceptable sign-off.

#### Why it has a concurrency guard
The hook skips when another PHPUnit run *for this project* is already in flight. Without that, two overlapping runs against a shared test database destroy each other: `RefreshDatabase` starts with `migrate:fresh`, so run B drops tables under run A mid-suite — phantom "relation does not exist" / aborted-transaction failures. Found the hard way.

The guard is project-scoped: in Sail mode it reads `APP_SERVICE` from `.env` (defaulting to `laravel.test`); outside Sail it matches `phpunit` processes by cwd (via `/proc` on Linux, `lsof` on macOS) so an unrelated phpunit run elsewhere on the machine doesn't cause a false skip.

## Customization

Projects can add their own forbidden paths or destructive patterns via their own `.claude/settings.json` hooks — plugin hooks and project hooks compose. To disable a maru hook entirely, disable the plugin or override it in project settings.

## Verify them yourself

The hook layer is covered by 57 dependency-free shell tests:

```
sh tests/hooks_test.sh
```
