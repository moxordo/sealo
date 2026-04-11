# Rule — stay in sync with `docs/` on every iteration

**Status:** load-bearing. Every Claude Code iteration on this repo must
follow the protocol below. Skipping a step is a bug, not a shortcut.

An **iteration** is one unit of work handed off by the user — typically
one user message → one assistant response cycle. This rule fires at the
start of every iteration and again at the end.

---

## Source of truth

`docs/**` is the source of truth for *what* the project is, *why*, and
*where it stands*. Code follows `docs/`, never the other way around.

| File | Authoritative for |
|---|---|
| `docs/00-intentions.md` | What the user asked for, in their words |
| `docs/01-plan.md` | Architecture, milestones, target file tree, design invariants |
| `docs/02-progress.md` | What's done, in flight, blocked |
| `docs/03-confirmations.md` | Locked decisions (`D1..Dn`) |
| `docs/04-assumptions.md` | Unratified beliefs (`A1..An`) |
| `docs/05-feasibility-notes.md` | iOS platform facts and constraints |

If two sources disagree, `docs/` wins — but that's a signal, not an
excuse. Reconcile immediately per the **Drift protocol** below.

---

## Pre-iteration checklist — read before touching anything

At the start of every iteration, **before** calling any non-read tool
(no `Edit`, no `Write`, no `Bash` that mutates state):

1. **Read `CLAUDE.md`.** It's already in context via auto-load, but
   confirm the ground rules are fresh.
2. **Read `docs/02-progress.md`.** Know what milestone you are on,
   what's in flight, and what's blocked. This is the orienting read.
3. **Read `docs/03-confirmations.md`.** Re-ground on locked decisions.
   Any plan you form must be consistent with `D1..Dn`.
4. **Read `docs/04-assumptions.md`.** Know what beliefs are currently
   unratified — these are your stop-and-ask tripwires.
5. **If the task touches iOS APIs**, also read
   `docs/05-feasibility-notes.md`. Do not re-derive platform facts from
   memory; they are written down for a reason.
6. **If the task touches scope or direction**, also read
   `docs/00-intentions.md` and `docs/01-plan.md`.

Skipping a read because "I remember it from last session" is prohibited.
Memory across sessions is unreliable; the files are not.

---

## During iteration — the four tripwires

Stop and raise the question to the user, *before* writing code, if you
find yourself about to do any of these:

### Tripwire 1 — Contradicting a confirmation
You are about to write something that conflicts with a `D*` entry in
`docs/03-confirmations.md`. **Stop.** A confirmation cannot be silently
adjusted. Surface the conflict, explain why you want to change it, and
wait for explicit user approval before touching either the code or the
confirmation.

### Tripwire 2 — Making a new unratified assumption
You are about to make a judgment call that is not already covered by an
`A*` entry in `docs/04-assumptions.md`. **Stop.** Either:
- (a) Surface the assumption to the user and get it ratified (promote
  to `03`), **or**
- (b) Add it to `04` with a reason and a "what if this flips" note,
  then proceed.

Never make a silent judgment call in code that rewrites the project's
implicit belief set.

### Tripwire 3 — Drift between docs and code
You notice that code state disagrees with `docs/02-progress.md` — e.g.
a checkbox is unchecked but the work is clearly landed, or vice versa.
**Stop.** Reconcile `02` first. Fix-up edits are fine; silent drift is
not.

### Tripwire 4 — Drift between docs and platform reality
You notice that `docs/05-feasibility-notes.md` says something that iOS
does not actually do (API changed, new entitlement, etc.). **Stop.**
Update `05` with the corrected fact *before* writing code that depends
on it, so the correction survives into future sessions.

---

## Post-iteration checklist — update before handing back

At the end of every iteration, **before** the final assistant message:

1. **Update `docs/02-progress.md`.**
   - Check off any M-milestone checkbox that is now truly done.
   - Add a line to "In flight" for anything started but not landed.
   - Add a line to "Blocked" for anything that hit a real obstacle.
   - Summarise the iteration in one or two lines under "Notes and
     decisions captured during M*".

2. **If a gate was met**, announce it in the response and collapse the
   milestone's checklist into the "Completed milestones" section.

3. **If a new assumption surfaced during the work**, make sure it
   landed in `docs/04-assumptions.md` with an `An` ID.

4. **If a confirmation was ratified mid-iteration**, make sure it
   landed in `docs/03-confirmations.md` with a `Dn` ID and a
   `Ratified:` date.

5. **If `docs/01-plan.md` changed**, briefly state what and why in the
   response — plan drift should never be invisible.

An iteration that mutates code without mutating `docs/02-progress.md`
is incomplete. Do not hand it back.

---

## Drift protocol

If you detect drift between `docs/` and code (either direction), the
rule is: **stop forward progress, reconcile, then resume.**

- **Code ahead of docs** (work landed, checkbox still unchecked) →
  update `02-progress.md` to match reality, in the same iteration.
- **Docs ahead of code** (checkbox checked, work incomplete) → uncheck
  the checkbox, add a blocker note, and do not pretend the work is done.
- **Docs disagree internally** (e.g. a `D*` confirmation conflicts with
  an `A*` assumption) → surface the conflict to the user immediately.
  Do not silently pick a winner.
- **Docs disagree with platform reality** → update `05-feasibility-notes.md`
  first, then the code.

Drift is normal. Silent drift is the failure mode this rule exists to
prevent.

---

## What this rule does *not* require

- Reading every file on every iteration regardless of relevance.
  Read the files the task actually touches. If you are fixing a typo in
  a SwiftUI view, you do not need to re-read `05-feasibility-notes.md`.
  But you must at least re-read `02-progress.md` to know where we are.
- Exhaustive cross-referencing. Update the docs that the iteration
  actually affected, not every doc defensively.
- Writing new docs speculatively. Only write what the iteration's work
  actually justifies capturing.

---

## Enforcement

This rule is currently enforced by convention — by me reading and
following it. If it starts to slip, the next step is a
`UserPromptSubmit` hook that echoes a one-line reminder into every
turn. That is not wired up yet; do not wire it up without the user
asking.
