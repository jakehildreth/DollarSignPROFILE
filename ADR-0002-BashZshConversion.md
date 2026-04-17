# ADR-0002: Bash and Zsh Port of DollarSignPROFILE

**Date:** 2026-04-17
**Status:** Accepted

---

## Context

`DollarSignPROFILE.ps1` targets PowerShell on macOS and Windows. Users who primarily work in bash or zsh have no equivalent profile. A direct port should preserve all meaningful behavior — self-update, prompt, keybindings, utility functions — while adapting to shell idioms rather than bolting PowerShell constructs onto POSIX shells.

---

## Decisions

### 1. Two separate files over a shared polyglot file

**Decision:** Produce `dotbashrc` and `dotzshrc` as independent files.

**Rationale:** Bash and zsh differ enough in keybinding APIs (`bind` vs `bindkey`), prompt systems (`PROMPT_COMMAND`+`PS1` vs `precmd`+`PROMPT`), word-splitting semantics, and file-path introspection (`$BASH_SOURCE` vs `${ZDOTDIR:-$HOME}/.zshrc`) that a shared file with shell-detection conditionals would be harder to read and maintain than two clean files. Each file is sourced by a different rc file (`~/.bashrc` vs `~/.zshrc`), so there is no runtime benefit to sharing.

**Rejected:** Single `dotshrc` with `[[ -n $ZSH_VERSION ]]` / `[[ -n $BASH_VERSION ]]` guards throughout; three-file base+wrapper approach (unnecessary abstraction for two target shells).

---

### 2. Installer replaces ~/.bashrc / ~/.zshrc entirely

**Decision:** `install.sh` overwrites the target rc file in full, matching the behavior of the PowerShell installer which writes to `$PROFILE` directly.

**Rationale:** Appending a `source` line creates a dependency on the installed file's location and leaves the original rc file's content in place, potentially conflicting with settings in the profile. Full replacement mirrors the PowerShell installer's contract and keeps the installed state predictable.

**Safety:** A timestamped backup (`~/.bashrc.bak.<YYYYMMDDHHmmss>`) is written before any overwrite so the original is recoverable.

**Rejected:** Appending `source ~/dotbashrc` to the existing rc file; installing to `~/.config/DollarSignPROFILE/` and sourcing from there.

---

### 3. New-Credential ported; New-Function excluded

**Decision:** `New-Credential` is ported as `new_credential` (storing result in `__CREDENTIAL_USER` / `__CREDENTIAL_PASS`). `New-Function` is not ported.

**Rationale:** Credential prompting (`read -rsp`) has a direct POSIX equivalent and is useful cross-shell. `New-Function` scaffolds PowerShell function files with PowerShell-specific constructs (approved verbs, `CmdletBinding`, PS comment-based help). The output is not meaningful in a bash/zsh context, and the function would require a full redesign to produce shell function templates, which is out of scope.

**Rejected:** Porting `New-Function` to scaffold shell functions (different enough to be a net-new feature, not a port).

---

### 4. Credential result stored in env vars, not returned via stdout

**Decision:** `new_credential` stores the username and password in `__CREDENTIAL_USER` and `__CREDENTIAL_PASS` rather than printing them to stdout.

**Rationale:** Returning credentials via stdout (`echo "$user:$pass"`) risks exposing them in shell history, process lists, or command substitution logs. Named env vars with a double-underscore prefix are explicit, inspectable, and do not pass through any pipe or subshell where they could be intercepted or logged.

**Rejected:** `echo "user:pass"` for capture via `$(new_credential)`; writing to a temp file.

---

### 5. Linux support for bash; macOS-only for zsh

**Decision:** `DollarSignPROFILE.bash` supports macOS and Linux. `DollarSignPROFILE.zsh` targets macOS only.

**Rationale:** Bash is the default shell on most Linux distributions, making Linux support natural and valuable. Zsh is the macOS default since Catalina but is not standard on Linux server environments. The existing PowerShell profile already uses `/bin/zsh` as its macOS detection heuristic, implying zsh = macOS in this codebase's mental model.

**Rejected:** Linux zsh support (out of scope; low real-world demand given the macOS-zsh pairing).

---

### 6. PSDefaultParameterValues / $LastOutput not ported

**Decision:** The `$PSDefaultParameterValues = @{ 'Out-Default:OutVariable' = 'LastOutput' }` block is excluded from both shell ports.

**Rationale:** There is no POSIX shell equivalent. Bash and zsh do not have a standard output-variable hook that captures the result of the last command without wrapping every invocation. Any workaround (e.g. a DEBUG trap capturing stdout) would be fragile, performance-impacting, and meaningfully different from the original behavior.

**Rejected:** `history`-based last-output approximations; DEBUG trap capturing stdout.

---

### 7. Escape binding uses double-Escape in zsh to avoid breaking alt sequences

**Decision:** The zsh profile binds `^[^[` (double-Escape) to `kill-whole-line` instead of single `^[`.

**Rationale:** In zsh, `^[` (ESC) is the prefix byte for virtually every alt-key and arrow-key terminal sequence. Binding single ESC to any widget would intercept all alt sequences before zsh can complete them. Double-Escape does not conflict with any standard terminal sequence and produces the same ergonomic result for users who want to clear the current line.

**Rejected:** Binding single `^[` to `kill-whole-line` (breaks Alt+Left, Alt+Right, and all escape sequences); omitting the binding entirely.

---

### 8. Self-update file path hardcoded to rc file location

**Decision:** The self-update logic in both files references the installed location directly (`$HOME/.bashrc` for bash; `${ZDOTDIR:-$HOME}/.zshrc` for zsh) rather than attempting to resolve the path of the currently-executing file at runtime.

**Rationale:** In bash, `$BASH_SOURCE[0]` is empty when `.bashrc` is read by bash itself during shell startup (as opposed to explicitly sourced). In zsh, `$0` is the shell name (`zsh`), not the rc file path. The installed location is always known from the installer contract. Hardcoding it eliminates an entire class of path-resolution edge cases.

**Rejected:** `$BASH_SOURCE[0]` with realpath fallback (unreliable on macOS where `realpath` is not installed by default); `${(%):-%x}` in zsh (inconsistent in `.zshrc` startup context).
