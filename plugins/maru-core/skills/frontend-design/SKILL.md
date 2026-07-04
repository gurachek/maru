---
name: frontend-design
description: Use when building or editing Vue/Inertia pages or components in a calm, dense, keyboard-first power-user app — NOT a flashy marketing site. Overrides any generic "make it distinctive/polished/impressive" guidance.
---

# Power-user frontend design

**Stack precondition:** this skill's component and tooling specifics assume Inertia + Vue. In Blade/Livewire/Filament projects, keep only the principles (density, keyboard-first, disclosure, calm visuals, accessibility) and defer to the project's own stack idioms — do not push Vue/shadcn specifics there.

The UI is a high-intensity tool for daily work (think Linear / Superhuman), not a marketing site. **Optimise for throughput and clarity, not visual impressiveness.** When this conflicts with generic design guidance, follow this.

## Stack assumptions

Inertia 2 + Vue 3 + TypeScript + Tailwind + shadcn-vue (Reka UI) + TanStack Table. Components live in `resources/js/{pages,layouts,components}`; shadcn ui in `resources/js/components/ui/` (owned source — edit freely). Use the `cn()` helper. Where the project differs, its `CLAUDE.md` wins.

## Rules

**Density & scannability**
- Compact rows (32–40px) in tables/lists; `tabular-nums` on numeric columns; right-align numbers, left-align text.
- First column of any table is a human-readable identifier (a name or title), never an opaque ID.
- Hierarchy via weight/size/color, not borders/boxes/heavy shadows. Minimal chrome.

**Keyboard-first**
- A command palette (Cmd/Ctrl-K) is reachable on every screen, same shortcut everywhere; show shortcut hints inline.
- Every primary action has a keyboard path. Arrow/Space/Enter for table row nav. Esc always closes.
- Shortcut handlers must ignore events from inputs/textareas/contenteditable.

**Disclosure & flow**
- Side panels (not modals) for primary workflows, so the list stays visible. Reserve modals for true interrupts.
- Bulk actions via a checkbox column + a sticky action bar that appears on selection.

**Perceived performance**
- Optimistic UI for low-risk frequent actions; roll back + toast on error.
- Skeletons sized to real content (no layout shift); spinners only for tiny inline waits.
- Use Inertia deferred props, partial reloads (`router.reload({ only: [...] })`), `prefetch`, and `usePoll` for heavy/live data. Forms use `useForm`; Cmd/Ctrl-Enter submits.

**Calm visuals**
- One restrained accent token. Status conveyed by a badge with **color + text/icon**, never color alone.
- Transitions ≤150ms, state/orientation only. No entrance/scroll animation. Dark mode is first-class.

**Accessibility**
- Use headless primitives (Reka UI) for dropdowns/dialogs/comboboxes/menus (ARIA + focus handled). Keep visible focus rings.

**Design tokens**
- Define semantic tokens in CSS (`--color-bg/-subtle`, `--color-fg/-muted`, `--color-border`, one accent, and status `--color-{success,warning,danger,info,neutral}-{fg,bg}`); use a mono font for IDs/scores/shortcuts. Keep an in-app base size around 13–14px.

## Avoid

Marketing-site patterns (hero sections, decorative gradients, scroll/entrance animations, carousels); modals for primary workflows; over-padding / generous whitespace; spinners where skeletons belong; non-virtualized lists over ~200 rows (use TanStack virtual); status conveyed by color only; hand-rolled dropdowns/dialogs.
