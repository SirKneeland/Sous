# Bug Triage

How in-app bug reports get from a phone into a backlog, and how we work through them.

## How a report is filed

In debug builds, tapping five times on the chat sheet (or the import error screen)
opens **Report a problem**. The operator writes what went wrong, and the app sends
that text plus the full diagnostic snapshot to the Sous backend. The old behaviour —
export the diagnostic as a Markdown file and hand it to the iOS share sheet — is
still there as **Share file…**, and is the fallback when a send fails.

The diagnostic is the same one `DebugDiagnosticExporter` has always produced:
metadata, preferences, memories, the system prompt, the chat transcript, recipe
state, and the last import attempt.

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
