# ADR-0004: Installer Hardening (Parity Pass)

**Date:** 2026-04-18
**Status:** Accepted

---

## Context

After an initial parity audit (`installer-comparison.md`) comparing `install.sh` and
`Install-DollarSignPROFILE.ps1`, eight gaps were identified. All eight were accepted for
remediation. One suggestion (aligning diff output format between `diff(1)` and
`Compare-Object`) was explicitly deferred as low-value noise.

---

## Decisions

### 1. Connect timeout added to `install.sh` download

**Decision:** `curl` in `_install_for_shell` gains `--connect-timeout 5`.

**Rationale:** Without a timeout, a hung or unreachable remote stalls the script and therefore the shell startup indefinitely. Five seconds is long enough for a healthy connection and short enough to fail fast on a dead one.

**Rejected:** No timeout (status quo — hangs forever); `--max-time` only (limits total transfer, not initial connect).

---

### 2. Profile parent directory created on fresh install in `install.sh`

**Decision:** `mkdir -p "$(dirname "$rc_file")"` is executed before the fresh-install write in `_install_for_shell`.

**Rationale:** `$ZDOTDIR` may point to a non-standard directory that does not exist yet. Without this, a fresh zsh install to a custom `$ZDOTDIR` silently fails the write. Matches the behavior of `Install-DollarSignPROFILE.ps1` which calls `New-Item -ItemType Directory` on fresh install.

---

### 3. CRLF normalization added to `install.sh` content comparison

**Decision:** Both `local_stripped` and `remote_stripped` are piped through `tr -d '\r'` after header stripping.

**Rationale:** A profile written by the PS1 installer on Windows uses CRLF line endings. On macOS/Linux, `diff` treats CRLF and LF as distinct, so the file would appear perpetually modified even when semantically identical. Normalization eliminates false-positive diffs. The PS1 installer already normalizes via `-replace '\r\n', "\`n"`.

---

### 4. Truncated `.DESCRIPTION` in `install.sh` completed

**Decision:** The `.DESCRIPTION` comment block was truncated mid-sentence at "If the shell is not bash or zsh,". The missing conclusion "both bash and zsh profiles are installed." is added.

**Rationale:** Documentation correctness. Truncation was an authoring oversight with no functional impact.

---

### 5. `exec "$shell_name" -l` replaces reload hint in `install.sh`

**Decision:** After a successful profile write, `install.sh` calls `exec "$shell_name" -l` instead of printing a reload hint.

**Rationale:** Printing "restart your session or run: . ~/.bashrc" leaves the new profile inactive until the user manually acts. `exec` replaces the current process with a fresh login shell, loading the new profile immediately. Behavior by invocation context:

- `bash install.sh` in terminal: replaces current shell with new login shell. New profile active. ✓
- `curl | bash`: replaces the pipe subshell (harmless; exits cleanly). ✓
- `bash <(curl ...)` (self-update bootstrap): replaces the subshell (harmless). ✓

**Caveat:** On macOS, `exec bash -l` starts a login shell which sources `.bash_profile`, not `.bashrc` directly, unless `.bash_profile` itself sources `.bashrc`. This is a known macOS/bash quirk and the user's responsibility. `exec zsh -l` reliably sources `.zshrc` (zsh login + interactive sources `.zshrc`).

**Rejected:** `exec bash --rcfile ~/.bashrc` (non-portable); conditional on `-t 0` (adds complexity for minimal gain; pipe subshell replacement is harmless).

---

### 6. `Set-Content` wrapped in try/catch in `Install-DollarSignPROFILE.ps1`

**Decision:** Both `Set-Content` calls (fresh install and update paths) are wrapped in a `try/catch` block. On failure, `Write-Fail` is called and the function returns.

**Rationale:** `Set-Content` can fail (permissions, disk full, locked file). Without a catch, `$ErrorActionPreference = 'Stop'` causes an unhandled terminating error with a raw exception message. Explicit handling mirrors `install.sh`'s `if ! printf ... > "$rc_file"` pattern and gives the user a clean `[x]` message.

---

### 7. `TimeoutSec` added to `Invoke-WebRequest` in `Install-DollarSignPROFILE.ps1`

**Decision:** `Invoke-WebRequest -Uri $sourceUri` gains `-TimeoutSec 10`.

**Rationale:** The profile's self-update bootstrap uses `TimeoutSec 3` when downloading the installer. The installer itself had no timeout when downloading the profile content. A hung download during shell startup would block indefinitely. Ten seconds allows for slow but functional connections while still failing fast on dead ones.

**Note:** 10s (not 3s) is used here because the installer download is larger than the bootstrapper invocation, and is also less latency-sensitive (it runs once, not on every shell open).

---

### 8. Diff format alignment deferred

**Decision:** No change. `install.sh` continues to use `diff(1)` output; `Install-DollarSignPROFILE.ps1` continues to use `Compare-Object`. This suggestion from `installer-comparison.md` was explicitly declined.

**Rationale:** The outputs are functionally equivalent for users reading a diff. The cosmetic difference does not affect behavior, correctness, or user decisions. Standardizing would require either reimplementing context diff in PowerShell or installing `diff` in PS1 (a portability dependency).
