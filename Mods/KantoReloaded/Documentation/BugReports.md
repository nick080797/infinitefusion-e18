# Kanto Reloaded Bug Reports

Kanto Reloaded provides a standalone `File A Bug Report` action at the bottom
of KR settings. About contains the framework version, author, and a direct
`Discord Link` action.

## Workflow

The action:

1. Rebuilds `KantoReloaded/Logging/LatestBugReport.txt`.
2. Uploads the sanitized bug report and current full `Log.txt` separately to
   `https://paste.rs/`.
3. Copies Discord-ready `Bug Report` and `Full Log` links together when
   clipboard access is available.
4. Opens the bug-report Discord thread when URL opening is supported.

Windows and Proton expose the complete clipboard and browser workflow. JoiPlay
copies the raw uploaded URL when its RPG Maker runtime exposes
`Input.clipboard=`. If clipboard or browser actions are unavailable, KR shows
the uploaded URL or the local report path instead.

The export runs behind a cancellable KR-styled progress popup. Cancelling the
upload does not delete the local report.

## Report Contents

Reports include KIF and KR versions, platform/runtime information, enabled mod
IDs and versions, KR registry counts, the current map and scene when available,
log severity totals, every error, critical, and fatal record, and the most
recent KR log lines.

`Log.txt` rotates to `Log.previous.txt` at 2 MiB. Bug-report collection streams
both bounded files once to calculate severity totals, retain all error records,
and retain the newest 300 lines without loading the complete logs into memory.

Reports do not include save contents or player identity. KR removes absolute
game, user, and temporary paths and redacts authorization values, access and
refresh tokens, API keys, passwords, secrets, sensitive URL parameters, and
Discord webhook credentials before writing or uploading the report.

## APIs

```ruby
KantoReloaded::Log.export_bug_report
KantoReloaded::BugReport.file
KantoReloaded::BugReport.publish_generated(options) { generated_file_path }
```

`publish_generated` gives KR-owned diagnostic exporters the same cancellable
progress popup, size and text validation, sanitized upload, and clipboard
workflow as `File A Bug Report`. Each exporter can choose whether to open the
Discord thread.
