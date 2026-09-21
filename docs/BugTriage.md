# Bug Triage

How in-app bug reports get from a phone into a backlog, and how we work through them.

## How a report is filed

In debug builds, tapping five times on the chat sheet (or the import error screen)
opens **Report a Problem**. The operator writes what went wrong, taps **Send to
Backlog**, and the app sends that text plus the full diagnostic snapshot to the Sous
backend; the sheet confirms with the short number (e.g. "Filed as BUG-17"). The old
behaviour — export the diagnostic as a Markdown file and hand it to the iOS share
sheet — is still there as **Share File…**, and is the fallback when a send fails.

The diagnostic is captured the moment the gesture fires, not when Send is tapped, so
nothing that happens while the report is being typed can change what gets recorded.

The diagnostic is the same one `DebugDiagnosticExporter` has always produced:
metadata, preferences, memories, the system prompt, the chat transcript, recipe
state, and the last import attempt.

## Reading a report — what is NOT a bug

A diagnostic has several honest quirks that read like defects on first look. Check
this list before you chase one. It applies to whoever is reading — a human, or an
agent asked to triage the backlog.

**"Reconstructed." above the system prompt.** The captured LLM request lives only in
memory, so it is gone after a relaunch. When it is missing, the exporter rebuilds an
equivalent request from the recipe, preferences, and transcript *as they stand at
capture time* and says so. The prompt template wording is exact; the recipe and
preference values in it may differ from those actually sent on the failing turn.
**Do not treat a mismatch between that prompt and the reported symptom as evidence** —
it usually just means the app was relaunched between the bug and the report. A report
filed immediately after a bad response carries the real captured request instead.

**Two timestamps that disagree.** `filed` is when the report reached the server.
The `Timestamp` inside the diagnostic is when the 5-tap fired on the device. The gap
is however long the person spent typing, and the device clock is the device's own.
Neither is the time the bug happened.

**The state shown is the state at the 5-tap, not at the bug.** The diagnostic is
captured the instant the gesture fires — deliberately, so nothing that happens while
the report is being typed can alter it. But anything the user did between hitting the
bug and reaching for the 5-tap is already baked in. A step marked done, a dismissed
patch, a new chat turn: all of that may post-date the problem.

**`(no LLM call this session, and no state to reconstruct one from)`** means there was
no canvas either — an exploration-state report. There is nothing missing.

**`[truncated — N characters total, first 20000 shown]`** is the exporter's own cap
(`DebugDiagnosticExporter.maxCapturedCharacters`), applied to long import inputs and
model responses. Nothing was lost in transit, and the 512k submission ceiling was not
involved. If the tail actually matters, raise the constant.

**`(the photo itself is not included)`** — a photo import records the image
*description* and the OCR text, never the image. A photo-import bug often cannot be
fully reproduced from the report alone; ask for the original picture.

**Mise en place says one of two different things.** `(not generated for this recipe)`
means it was never produced. `(generated, but empty — no prep steps were found)` means
it ran and found nothing. Those are different bugs, and the second is a real one.

**The reporter may be a dev account.** With the debug sign-in bypass, `user_id` points
at a `<handle>@example.test` account, not a real user. See `Debug/DebugSignIn.swift`.

**Personality mode shapes tone, not correctness.** A response that reads as rude,
chaotic, or sweary under `unhinged` is the spec working. See `PersonalityModes.md`
before filing an LLM-voice bug.

## Working the backlog

All commands run from `backend/`. The admin key and backend URL are read from
Railway automatically (`railway login` + `railway link` once per machine); they do
not need to be copied into `backend/.env`.

```bash
./scripts/bugs.sh list                  # open reports (status = new)
./scripts/bugs.sh list all              # everything, any status
./scripts/bugs.sh show 17               # full report BUG-17, diagnostic included
./scripts/bugs.sh triage 17 "Repro'd on build 142 — PatchApplier reorders steps"
./scripts/bugs.sh start 17              # picked it up
./scripts/bugs.sh resolve 17 "Fixed in PatchApplier.applyReorder; eval case added"
./scripts/bugs.sh wontfix 17 "Working as designed — see PRD §4"
./scripts/bugs.sh dupe 17 <uuid-of-original>
./scripts/bugs.sh tag 17 patching,import
```

`17` is the short number: BUG-17.

## Statuses

| Status | Meaning |
|---|---|
| `new` | Filed, nobody has looked yet |
| `triaged` | Understood and described; not being worked |
| `in_progress` | Someone is on it |
| `fixed` | Shipped a fix |
| `wont_fix` | Deliberately not fixing; the reason belongs in the resolution |
| `duplicate` | Same as another report; `duplicate_of` points at it |

## Rules

- **Reports are never deleted.** There is no delete route, by design. A fixed
  report is the cheapest source of regression tests we have.
- **When a bug is fixed, distil it before closing.** An LLM-behaviour bug becomes a
  case in `evals/cases/core-behaviors.json`; a state or patching bug becomes a Swift
  test. Then `resolve` it, naming the test in the resolution so the link survives.
- **Don't commit raw reports into the repo.** They contain full chat transcripts and
  recipe state. The database is the archive; the distilled test is what lands in git.

## Where it lives

| Piece | Path |
|---|---|
| Submission route | `backend/src/routes/bugs.ts` |
| Triage routes | `backend/src/routes/admin.ts` (`/admin/bugs*`) |
| Table | `bug_reports` in `backend/db/schema.sql` |
| CLI | `backend/scripts/bugs.sh` |
| iOS capture | `ios/SousApp/SousApp/Debug/` |

## Schema changes

`backend/scripts/sql.sh` runs SQL against Supabase via the Management API:

```bash
./scripts/sql.sh "select count(*) from bug_reports"
./scripts/sql.sh -f db/schema.sql
```

It needs `SUPABASE_ACCESS_TOKEN` in `backend/.env` — a scoped Supabase personal
access token (Database: Read-write on this project only). It expires; when `sql.sh`
starts returning 401, issue a new one from the Supabase dashboard.
