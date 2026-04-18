# ADR-0003: Centralize Update Logic in Installers

**Date:** 2026-04-18
**Status:** Accepted

---

## Context

The self-update logic originally lived inside each profile file (`DollarSignPROFILE.ps1`, `dotbashrc`, `dotzshrc`). Each profile contained a full implementation: download, compare, prompt, write. This created three separate codebases for the same behavior, which diverged over time and contained overlapping bugs (notably, all three had incorrect `profiles/` path segments in their remote URLs). A dedicated installer existed (`install.sh`, `Install-DollarSignPROFILE.ps1`) but was thin and did not share logic with the self-update blocks.

The goal is a single authoritative implementation of update logic in each installer, with profiles reduced to a thin bootstrap call.

---

## Decisions

### 1. All update logic lives in the installer; profiles are thin bootstraps

**Decision:** The self-update blocks in `dotbashrc`, `dotzshrc`, and `DollarSignPROFILE.ps1` are replaced with a single line that downloads and executes the corresponding installer.

- `dotbashrc` / `dotzshrc`: `bash <(curl -fsSL --connect-timeout 3 '...installers/install.sh')`
- `DollarSignPROFILE.ps1`: `Invoke-WebRequest ... | Invoke-Expression`

**Rationale:** Eliminates three parallel implementations of the same logic. Bug fixes and behavior changes only need to happen in one place. Profiles stay focused on their actual purpose: configuring the shell environment.

**Rejected:** Sharing a common sourced/dot-imported library file (adds a deployment and path-resolution dependency); keeping logic in profiles and syncing manually (demonstrated to diverge).

---

### 2. Shell detection uses `$PPID`, not `$SHELL`

**Decision:** `install.sh` detects the invoking shell via `ps -p $PPID -o comm=` rather than `$SHELL`.

**Rationale:** `$SHELL` is set at login and reflects the user's preferred login shell, not the currently running shell. A user running bash from within pwsh or zsh would have `$SHELL=/bin/zsh` while actually running bash. `$PPID` is the parent process of the script, which is the shell that invoked it. This is the correct signal for "what shell should I install for."

**Edge case:** The shebang is `#!/usr/bin/env bash`, so `$$` always returns `bash`. `$PPID` correctly reflects the calling shell.

**Rejected:** `$SHELL` (reflects login preference, not active shell); `$0` (always `bash` due to shebang); `ps -p $$ -o comm=` (same problem as `$0`).

---

### 3. AutoUpdate preference honored in `install.sh`

**Decision:** `install.sh` reads the `# DollarSignPROFILE:AutoUpdate=` sentinel from the rc file before doing any work, mirroring the PowerShell installer's behavior (ADR-0001 §2).

- `never`: prints a skip message with removal instructions; exits silently.
- `always`: skips the prompt; proceeds directly to backup and write.
- absent or other: compares content; if different, prompts with the 5-option menu.

**Rationale:** Consistent behavior across all three shell installers. Users who set `AutoUpdate=never` in their bash profile should not be prompted every time they open a shell.

---

### 4. Silent return when content is identical

**Decision:** Both installers return with no output when the local profile content matches the remote, after stripping the AutoUpdate sentinel line from both sides before comparison.

**Rationale:** The most common case on any given shell open is "nothing has changed." Printing anything in that case adds noise to every shell startup. Sentinel stripping prevents a preference change from being misidentified as a content difference.

---

### 5. 5-option interactive prompt in `install.sh` matches PowerShell installer

**Decision:** `install.sh` uses `select` with the same five options as `Install-DollarSignPROFILE.ps1`: Yes always / Yes just this time / No not this time / No never / More details.

- Options 1 and 2 proceed to install (1 writes the `AutoUpdate=always` header).
- Option 3 prints "Installation skipped." and returns.
- Option 4 writes `AutoUpdate=never` to the rc file, prints "Installation skipped. You will not be prompted again." and returns.
- Option 5 shows a colored diff (red for removed, green for added lines) then re-renders the menu via `break` out of `select` + `while true` loop.

**Rationale:** Consistent UX across shells. The `while true` + `break` pattern is required because bash's `select` only renders the numbered list on first entry; breaking and re-entering forces a re-render after the diff display.

---

### 6. `__ask` output helper added to `install.sh`

**Decision:** A `__ask()` helper is added alongside `__info`, `__success`, and `__error`, printing `[?]` in blue. Used for prompts that require a user decision.

**Rationale:** Semantic distinction between informational output (`[i]`) and a question requiring action (`[?]`). Blue is visually distinct from cyan (`[i]`), green (`[+]`), and red (`[x]`). Matches the `Write-Ask` helper added to `Install-DollarSignPROFILE.ps1`.

---

### 7. Backup created only when installation proceeds

**Decision:** The timestamped rc file backup is created immediately before the write, after the user has confirmed they want to install. It is not created on skip or no-action paths.

**Rationale:** Creating a backup when nothing will be written is misleading and pollutes the home directory with spurious `.bak` files. The backup serves as an undo mechanism for a write that is about to happen.

---

### 8. "Installing..." message deferred until confirmed

**Decision:** `[i] Installing <shell> profile → <path>` is printed only after the user has selected yes (or `AutoUpdate=always` is set), not at the start of the function.

**Rationale:** Printing the installing message before asking the user implies an action is already underway. If the user selects "No, not this time", no installation occurs and the message would have been misleading.

---

### 9. PS1 installer dot-sources `$PROFILE` after write

**Decision:** `Install-DollarSignPROFILE.ps1` dot-sources `$PROFILE` after a successful write.

**Rationale:** When invoked from the profile's self-update block via `Invoke-Expression`, the installer runs in the same session. Dot-sourcing after write means the new profile takes effect immediately without requiring a shell restart. The second load returns silently (content is now identical), preventing any recursive loop.

**Rejected:** Removing the dot-source to avoid recursive load (the recursive load is benign; not dot-sourcing means the new profile is not active until the next session, which is confusing after an update).
