---
name: disciplined-coding
description: >
  MANDATORY before any implementation work — writing code, fixing bugs, refactoring, modifying
  services, adding features, changing PHP/Vue/JS files, editing controllers/jobs/services.
  Enforces test-first development, small commits, file size limits, and prevents cascading fixes.
  TRIGGER: any user request that will result in Edit or Write to code files.
  If you are about to use Edit or Write on a .php, .vue, .js, or .ts file, this skill applies.
  Do NOT skip. Do NOT rationalize skipping.
---

# Disciplined Coding

You are about to write or modify code. Before you touch a single file, read and internalize these rules. They exist because undisciplined AI coding sessions turn working systems into bug factories: many commits, zero tests, cascading fixes. That stops here.

## The Iron Law

```
NO CODE WITHOUT A FAILING TEST.
NO COMMIT WITHOUT PASSING TESTS.
NO THIRD ATTEMPT AT THE SAME FIX.
```

This is non-negotiable. There are no exceptions. Not for "simple changes." Not for "just a one-liner." Not for "I'll add tests later." Skipping it reliably produces downstream bugs — assume every violation costs you 2-3 more, not zero.

---

## Phase 0: Pre-Flight Check (MANDATORY)

Before writing ANY code, answer these questions. If you cannot answer them, STOP and investigate.

1. **What exactly is broken or missing?** (Not "it doesn't work" — the specific failure, with evidence)
2. **What is the root cause?** (Not the symptom — trace the actual code path)
3. **What is the minimal change?** (Not "refactor the service" — the fewest lines that fix the root cause)
4. **What test will prove the fix works?** (The exact assertion, not "I'll test it")
5. **What could this change break?** (List every caller, every consumer of the modified code)

Skipping this phase is how cascading fix loops start.

---

## Phase 1: Write the Test FIRST

Before touching any production code:

1. Create or identify the test file
2. Write a test that **fails right now** because the bug exists or the feature is missing
3. Run the test. Confirm it fails. Show the failure output.
4. Only THEN proceed to Phase 2.

**What counts as a test:**
- PHPUnit test method with concrete assertions
- NOT "I verified manually in the browser"
- NOT "I checked the database"
- NOT "I'll add the test after"

**If you cannot write a test:**
- Explain WHY to the human
- Get explicit permission to proceed without one
- Document what manual verification will substitute
- This is the ONLY escape hatch, and it requires human approval

---

## Phase 2: Make the Minimal Change

Write the smallest possible code change that makes the failing test pass.

**Hard limits:**
- If your change touches more than 3 files, STOP. Explain the scope to the human and get approval.
- If the file you're editing is over 500 lines, STOP. Consider whether you should extract a service first.
- If your change adds more than 50 lines to a single file, STOP. Explain why the change is that large.

**Banned patterns:**
- Adding 200+ lines to a file that's already 3000+ lines
- "While I'm in here, let me also..." — NO. One change per cycle.
- Refactoring adjacent code that isn't related to the fix
- Adding features that weren't requested

---

## Phase 3: Run All Tests

After your change:

1. Run the specific test you wrote in Phase 1. It must pass.
2. Run the full related test suite (`php artisan test --filter=Invoice` or equivalent).
3. If ANY test fails that wasn't failing before your change, your change broke something. REVERT and rethink.

---

## Phase 4: Commit (If and Only If Asked)

Only commit when the human asks. When you do:

- One logical change per commit
- Tests must be passing
- Commit message explains WHY, not WHAT

---

## The Three Strikes Rule

If you attempt to fix the same test failure or bug 3 times and it still fails:

1. **STOP.** Do not try a 4th variation.
2. Tell the human: "I've attempted this fix 3 times. Here's what I tried and why each failed."
3. Propose a **fundamentally different approach** (not a variation of the same approach).
4. Wait for the human's decision before proceeding.

The reason: 3 failed attempts means the mental model is wrong. More attempts with the wrong model produce more bugs. Stop, reassess, get human input.

---

## The Cascading Fix Detector

You are in a cascading fix loop if ANY of these are true:

- You're making a 3rd commit to fix issues introduced by your earlier commits in this session
- You're editing a file you already edited twice this session to fix something your edits broke
- A test that was passing before your changes is now failing
- You're adding try/catch or null checks to paper over a root cause you don't understand

If you detect this pattern: **STOP IMMEDIATELY.** Tell the human:
> "I'm in a cascading fix loop. My changes are introducing new bugs. I need to revert to the last known-good state and take a different approach."

---

## File Size Awareness

| File Size | Action Required |
|-----------|----------------|
| < 200 lines | Proceed normally |
| 200-500 lines | Be cautious. Check if extraction is needed before adding code. |
| 500+ lines | **Do NOT add code.** Extract a smaller service/component first, THEN make your change in the extracted code. |
| 1000+ lines | **God Object.** Refuse to add code. The file MUST be split before any new work. |

A 3,000+ line service class should be 5-6 separate services. Adding more fixes to it without refactoring makes everything worse.

---

## Rationalization Prevention

If you catch yourself thinking any of these, you are about to violate the Iron Law:

| Your Thought | The Reality |
|-------------|-------------|
| "This is too simple to need a test" | Simple changes in coupled code cause cascading failures. Test it. |
| "I'll add tests after" | You won't. And untested code ships bugs. |
| "Just a quick fix" | Quick fixes without tests are where regressions breed. |
| "The existing tests will catch it" | Assume coverage is worse than it looks until you've verified it. |
| "I need to fix this first, then test" | No. Test first, then fix. That IS the process. |
| "The user wants this done fast" | The user wants this done RIGHT. Speed without tests is slower — you'll be back fixing bugs tomorrow. |
| "I can't test this because [reason]" | Then explain the reason to the human and get explicit permission. |
| "Let me just refactor while I'm here" | NO. One change per cycle. Refactor is a separate task with separate tests. |
| "This file is already a mess, one more change won't hurt" | That thinking created the mess. Stop contributing to it. |

---

## Session Discipline

- **Maximum 5 commits per session** without human review. If you're approaching 5, stop and ask: "I've made several changes. Want to review before I continue?"
- **Never edit the same file more than 3 times** in one session. If you need a 4th edit, your approach is wrong.
- **After every 2 commits**, run the full test suite. Not just your new tests — ALL tests.

---

## What Good Looks Like

A good session:
1. Reads the code to understand the problem (10-20 min)
2. Writes 1-3 focused tests (10 min)
3. Makes 1 minimal change that passes all tests (10 min)
4. Commits when asked (1 min)

A bad session:
1. Starts coding immediately
2. Makes 10 changes across 8 files
3. Tests nothing
4. Commits 30 times
5. Spends the next session fixing the bugs this session created

**Be the good session.**
