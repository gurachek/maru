---
name: rls-multitenancy
description: Reference for Postgres row-level-security multi-tenancy in Laravel. Use when adding tenant-scoped tables/models, writing tenant-aware queries, or testing isolation.
---

# Multi-tenancy: roll-your-own + Postgres RLS

## The model

- Every tenant-owned row carries a tenant column (convention: `organization_id`).
- Request tenant context lives in a per-request singleton (`Tenant::currentId()`) AND is pushed to a Postgres session GUC (convention: **`app.current_organization_id`**) by middleware, via `set_config('app.current_organization_id', ?, false)`; `NULL` means default-deny.
- The login role is privileged; runtime queries `SET ROLE` to a least-privilege application role (NOSUPERUSER, NOBYPASSRLS) so RLS actually applies.
- Queue jobs carry the tenant id and restore context before handling. **CLI and queues are not auto-scoped by web middleware** — every command/job touching tenant data must set tenant context explicitly (per-tenant loop) or bypass deliberately (`Tenant::bypassRls()`-style explicit call). Never query tenant tables in a command/job without one of the two.

## Application layer

Apply a `BelongsToOrganization`-style trait to tenant models. It (a) auto-sets the tenant id on create from the current context, and (b) adds a global scope filtering by the current tenant.

## Database layer (the defensibility)

Every tenant table:
```sql
ALTER TABLE <table> ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON <table>
  -- match your tenant key type: ::uuid here; use ::bigint for integer keys
  USING (organization_id = current_setting('app.current_organization_id', true)::uuid);
```
Even if a buggy `withoutGlobalScopes()` slips through, Postgres refuses cross-tenant rows. Consider an asymmetric `WITH CHECK` when writes need stricter rules than reads.

## Testing (required for every tenant table)

- Provide `TestCase` helpers: `actingAsOrg($id)` sets the GUC; `forgetTenant()` clears it.
- Write an **isolation test**: create rows for tenant A and tenant B, act as A, assert only A's rows are visible AND a cross-tenant update affects 0 rows.
- **Canary**: the test DB role must NOT own the table or have `BYPASSRLS`, or RLS silently passes vacuously. Assert a known cross-tenant query returns nothing.

## Gotchas

- Don't let factories build cross-tenant graphs (orphaned, RLS-invisible rows → flaky tests). Use explicit `forOrg($org)`-style factory states.
- Raw `DB::` queries are not covered by the Eloquent global scope — they rely on RLS; make sure tenant context is set.
- Eager-shared Inertia props can resolve **before** the tenant middleware runs — use lazy closures and check middleware order, or tenant-table queries there leak across tenants.
