# ADR-0005: install.sh Robustness and Cross-Platform Bash Targeting

**Date:** 2026-04-18
**Status:** Accepted

---

## Context

After a second parity audit (`installer-comparison-2026-04-18.md`), eight gaps were
identified and accepted. Implementation surfaced additional runtime bugs on macOS that
required further fixes. This ADR covers the second-pass suggestions plus all subsequent
bug fixes.

---

## Decisions

### 1. Unsupported shell exits with error instead of installing both

**Decision:** The `*)` fallback case now calls `__error` and `exit 1` instead of
installing both bash and zsh.

**Rationale:** The previous "install both" behavior was broken: `_install_for_shell`
ends with `exec "$shell_name" -l`, which replaces the current process. The bash install
would run, `exec bash` would fire, and the zsh install would never execute. Erroring
out is honest about the limitation. The tool is explicitly scoped to bash and zsh.

---

### 2. `set -euo pipefail` and locale exports added

**Decision:** `set -euo pipefail` is added after the shebang. `LANG` and `LC_ALL` are
exported with `en_US.UTF-8` as defaults if not already set.

**Rationale:** Unguarded command failures previously continued silently. `set -e`
makes unhandled failures immediately visible. `set -u` catches undefined variable
references. `set -o pipefail` catches failures in pipeline left-hand sides. Locale
exports ensure writes use UTF-8 regardless of system configuration.

**Consequence:** Several existing patterns were incompatible with `set -e` and required
fixes (see §5, §6, §7).

---

### 3. `.Trim()` equivalent added to bash content comparison

**Decision:** Both `local_stripped` and `remote_stripped` are piped through
`sed '/./,$!d'` after `tr -d '\r'`. This is applied at both the initial comparison
site and the option-5 diff re-render.

**Rationale:** `sed '/^# DollarSignPROFILE:AutoUpdate=/d'` removes the sentinel line
but leaves its trailing newline, producing a leading blank line. PS1 uses `.Trim()`
to absorb this. Without trimming, files that are semantically identical produce a
false diff and prompt the user unnecessarily. `sed '/./,$!d'` deletes all leading
blank lines (reads "from the first line containing any character, to end of file").

---

### 4. `Write-Fail` replaced with proper `ErrorRecord` in PS1 installer

**Decision:** `Write-Fail` is rewritten to construct a
`System.Management.Automation.ErrorRecord` with caller-supplied `Category` and
`TargetObject`, then emit it via `Write-Error -ErrorRecord`. All three call sites
supply appropriate categories (`ConnectionError`, `WriteError`).

**Rationale:** The previous `Write-Host "[x] ..."` wrote to stdout, indistinguishable
from normal output when the installer is consumed via `Invoke-Expression`. A proper
`ErrorRecord` writes to the error stream and carries structured metadata (category,
target, exception) usable by callers and logging infrastructure.

---

### 5. `$sourceUri` made read-only in PS1 installer

**Decision:** `$sourceUri` is declared via `Set-Variable -Option ReadOnly` instead of
plain assignment.

**Rationale:** Matches the `readonly` convention already used for URL constants in
`install.sh`. Prevents accidental reassignment in the script body.

---

### 6. `select` replaced with manual `read` loop in `install.sh`

**Decision:** The `select` + `while true` prompt is replaced with a `while true` +
`read -r REPLY` loop that prints the menu manually.

**Rationale:** `select` in bash/zsh does not execute its body when the user presses
Enter on an empty line — it simply re-renders the menu. This made the default-choice
hint (`[1-5, default 2]`) non-functional. A manual `read` loop handles empty input
explicitly (`if [[ -z "$REPLY" ]]; then REPLY=2; fi`) before the `case` statement.

**Additional fix:** `[[ -z "$REPLY" ]] && REPLY=2` was changed to the `if` form.
The `&&` short-circuit form exits 1 when `$REPLY` is non-empty, which `set -e` treats
as a failure and kills the script.

---

### 7. `diff` assignment protected with `|| true`

**Decision:** The `diff` call in option 5 gets `|| true`.

**Rationale:** `diff` exits 1 when differences are found — its normal, expected
success case. Without `|| true`, `set -e` kills the script whenever the user asks
to see the diff and differences exist.

---

### 8. Shell detection changed from `basename` + `ps` to pure `sed`

**Decision:** `_invoking_shell` detection changed from
`basename "$(ps -p $PPID -o comm=)"` to
`ps -p $PPID -o comm= | sed 's|.*/||; s/^-//'`.

**Rationale:** macOS prefixes login shell process names with `-` (e.g. `-zsh`,
`-bash`). `basename -zsh` treats the value as a flag and errors:
`basename: illegal option -- z`. Using `sed` to strip the path prefix and leading
dash avoids `basename` entirely and handles the macOS login shell case correctly.

---

### 9. `exec bash -l` changed to `exec bash -i`; `.bash_profile` bootstrap added

**Decision:** `exec "$shell_name" -i` replaces `exec "$shell_name" -l`. For bash,
`_ensure_bash_profile_sources_bashrc` runs before `exec`, ensuring `~/.bash_profile`
contains `[[ -f ~/.bashrc ]] && source ~/.bashrc`.

**Rationale:** `exec bash -l` starts a login shell, which on macOS reads
`.bash_profile`, not `.bashrc`. DollarSignPROFILE is written to `.bashrc`, so a
login shell would not load it — producing the symptom of "customizations visible
after `exec bash -i` but not in new Terminal tabs."

The correct cross-platform target is `.bashrc`: it is read by interactive non-login
shells on Linux (the default) and by `exec bash -i`. On macOS, new Terminal tabs open
login shells that read `.bash_profile`. `_ensure_bash_profile_sources_bashrc` bridges
this by ensuring `.bash_profile` delegates to `.bashrc`, making the setup correct on
both platforms without writing to two files. The function is idempotent: it checks for
any existing reference to `.bashrc` before modifying `.bash_profile`.
