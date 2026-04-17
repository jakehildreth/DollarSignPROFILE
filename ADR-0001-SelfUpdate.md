# ADR-0001: Self-Update Mechanism for DollarSignPROFILE

**Date:** 2026-04-16
**Status:** Accepted

---

## Context

`DollarSignPROFILE.ps1` is a shared PowerShell profile distributed via a one-liner installer (`iwr profile.jakehildreth.com | iex`). Once installed, there is no built-in mechanism to keep the local copy in sync with the upstream source. Users may run a stale profile indefinitely without knowing an update exists.

The goal is a self-update mechanism that runs on every `$PROFILE` load, requires no separate tooling, and respects user preferences about whether and how updates are applied.

---

## Decisions

### 1. String comparison over hash comparison

**Decision:** Normalize both strings (`.Trim() -replace '\r\n','\n'`) and compare directly.

**Rationale:** `Set-Content -Encoding UTF8` in PS5.1 writes a BOM; PS7+ does not. Hashing raw bytes would produce false-positive diffs on cross-version installs. String normalization eliminates this class of false positive entirely.

**Rejected:** `Get-FileHash` / SHA-256 of file bytes.

---

### 2. Preference stored in `$PROFILE` as a sentinel comment

**Decision:** Store the user's update preference as `# DollarSignPROFILE:AutoUpdate=<value>` on the first line of `$PROFILE`.

**Rationale:** Eliminates any external config file dependency. The preference travels with the profile itself, survives across machines if `$PROFILE` is synced (e.g. via iCloud or OneDrive), and requires no separate read/write path. The sentinel is stripped before comparison to prevent it from being a permanent diff driver.

**Format:** `# DollarSignPROFILE:AutoUpdate=always` or `# DollarSignPROFILE:AutoUpdate=never`

**Rejected:** JSON config at `$HOME/.config/DollarSignPROFILE/config.json`; registry; environment variable (non-persistent).

---

### 3. `$Host.UI.PromptForChoice()` over `Read-Host`

**Decision:** Use `$Host.UI.PromptForChoice()` for the 4-option update prompt.

**Rationale:** Idiomatic PowerShell. Renders natively in all host environments (console, VS Code terminal, ISE). Supports keyboard accelerators. Gracefully handles non-interactive hosts (throws a catchable exception rather than hanging). `Read-Host` has none of these properties and is explicitly excluded from this project's coding standards.

**Rejected:** `Read-Host` with a numbered list.

---

### 4. Silent `catch` block (offline resilience)

**Decision:** The entire self-update block is wrapped in `try/catch`; the catch block is a no-op comment.

**Rationale:** Network availability cannot be guaranteed. A profile that errors on load due to a failed web request would be worse than a stale profile. The profile's primary purpose — configuring the shell environment — must never be gated on network access.

**Rejected:** Re-throwing the error; `Write-Warning` on failure (too noisy for a routine startup operation).

---

### 5. `return` after `. $PROFILE` on update

**Decision:** After writing and dot-sourcing the updated profile, immediately `return`.

**Rationale:** Without `return`, the remainder of the stale file's execution context continues running after the fresh profile has already loaded. This produces double-execution of all profile content below the self-update block. `return` terminates the stale context cleanly.

**Rejected:** Relying on the dot-source alone without `return`.

---

### 6. `Invoke-WebRequest -UseBasicParsing`

**Decision:** Use `-UseBasicParsing` on all `Invoke-WebRequest` calls.

**Rationale:** PS5.1 on Windows requires Internet Explorer's COM engine for full HTML parsing; `-UseBasicParsing` bypasses this dependency and is the only reliable cross-platform flag. The flag is a no-op in PS7+ but causes no harm.

**Rejected:** `Invoke-RestMethod` (returns a parsed object, not raw content string); `[System.Net.WebClient]` (deprecated).
