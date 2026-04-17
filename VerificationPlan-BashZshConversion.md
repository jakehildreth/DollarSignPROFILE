# Verification Plan: Bash/Zsh Conversion

Features: `DollarSignPROFILE.bash`, `DollarSignPROFILE.zsh`, `Install-DollarSignPROFILE.sh`

---

## 1. Prompt format
**Setup:** Source `DollarSignPROFILE.bash` in a fresh bash session; source `DollarSignPROFILE.zsh` in a fresh zsh session.
**Expected:** Prompt renders as:
```
[80×24] ~/path [branch]
bash>
```
Blank line precedes each prompt. `[branch]` appears only inside a git repo; omitted outside one.

---

## 2. Prompt — git branch detection
**Setup (inside git repo):** `cd` into a git repository. Check prompt.
**Expected:** `[branch-name]` appears on the first prompt line.

**Setup (outside git repo):** `cd $HOME`. Check prompt.
**Expected:** No `[...]` segment on the first prompt line.

---

## 3. Prompt — terminal resize
**Setup:** Source the profile, then resize the terminal window.
**Expected:** Width and height in prompt update on the very next command (`PROMPT_COMMAND` / `precmd` re-evaluates each time).

---

## 4. get_ip_address — macOS
**Setup:** Run `get_ip_address` on macOS with at least one active non-loopback interface.
**Expected:** One or more lines in format `interface: 10.x.x.x`. `lo0` does not appear in output.

---

## 5. get_ip_address — Linux
**Setup:** Run `get_ip_address` in an Ubuntu Docker container with an active interface.
**Expected:** One or more lines in format `eth0: 172.x.x.x`. `lo` does not appear in output.

---

## 6. get_ip_address — no suitable tool available
**Setup:** Run in a minimal Alpine container where neither `ifconfig` nor `ip` is present.
**Expected:** Warning message printed to stderr; function exits with code 0; no unhandled error.

---

## 7. new_credential — happy path
**Setup:** Run `new_credential` in an interactive session.
**Action:** Enter a username and a password at the prompts.
**Expected:**
- Password input is hidden (no echo to terminal)
- `$__CREDENTIAL_USER` is set to the entered username
- `$__CREDENTIAL_PASS` is set to the entered password
- No credentials printed to stdout

---

## 8. new_credential — empty username
**Setup:** Run `new_credential` and press Enter with no input at the username prompt.
**Expected:** `$__CREDENTIAL_USER` is empty string; `$__CREDENTIAL_PASS` prompt still appears; function completes without error.

---

## 9. gai — macOS clipboard
**Setup:** Run `gai` on macOS; then run `pbpaste`.
**Expected:** Clipboard contains all three URLs (personal Copilot instructions, PS best practices, Pester v5 best practices), one block of text.

---

## 10. gai — Linux with xclip
**Setup:** Run `gai` on Linux with `xclip` installed.
**Expected:** All three URLs copied to clipboard; no error output.

---

## 11. gai — Linux fallback (no clipboard tool)
**Setup:** Run `gai` on Linux with neither `xclip` nor `xsel` installed.
**Expected:** URLs printed to stdout with a manual-copy notice; no error thrown.

---

## 12. Keybindings — bash (interactive)
**Setup:** Source `DollarSignPROFILE.bash` in an interactive bash session (iTerm2 or GNOME Terminal).
**Expected:** All ten bindings fire correctly:
- Ctrl+U clears from cursor to line start
- Escape (or double-Escape) reverts/clears line
- Alt+Left / Alt+Right jump by word
- Ctrl+Left / Ctrl+Right jump by word
- Alt+Backspace / Ctrl+Backspace delete word backward
- Ctrl+Delete / Alt+Delete delete word forward

---

## 13. Keybindings — zsh (interactive)
**Setup:** Source `DollarSignPROFILE.zsh` in an interactive zsh session.
**Expected:** Same ten bindings fire correctly via `bindkey`. Double-Escape clears line without breaking alt-key sequences.

---

## 14. Keybindings — non-interactive bash
**Setup:** `bash -c '. DollarSignPROFILE.bash'`
**Expected:** No errors; `bind` calls skipped via `[[ $- == *i* ]]` guard.

---

## 15. Self-update — preference: never
**Setup:** Add `# DollarSignPROFILE:AutoUpdate=never` as first line of the file. Disable network (or point URL at an invalid host).
**Expected:** No network request made; no prompt; shell loads normally.

---

## 16. Self-update — preference: always, content differs
**Setup:** Set preference to `always`; manually alter one character in the local file.
**Expected:**
- No prompt
- Remote content written to file with sentinel re-prepended
- Shell reloads silently via `exec $SHELL -l` (bash) or `exec zsh -l` (zsh)
- Old execution context terminates

---

## 17. Self-update — preference: always, content identical
**Setup:** Set preference to `always`; local content matches remote after stripping sentinel.
**Expected:** No write, no reload; shell loads normally.

---

## 18. Self-update — no preference, content differs
**Setup:** Remove sentinel; alter one character locally.
**Expected:** 5-option interactive menu appears with: Yes always / Yes once / No once / No never / More details.

---

## 19. Self-update — menu choice: Yes, always
**Action:** Choose option 1 (`Yes, always`).
**Expected:**
- `# DollarSignPROFILE:AutoUpdate=always` written as first line of file
- Remote content written
- Shell reloads; old context terminates
- On next load with matching content: no prompt, no write

---

## 20. Self-update — menu choice: More details
**Action:** Choose option 5 (`More details`).
**Expected:**
- Colored diff displayed (removed lines in red, added lines in green)
- Menu re-presents afterward without re-downloading

---

## 21. Self-update — network unavailable
**Setup:** Disable network or point update URL at an invalid host. Any preference value (or none).
**Expected:** `curl` failure caught silently; no error output; shell loads fully as-is.

---

## 22. Self-update — sentinel stripped before comparison
**Setup:** Set preference to `always`; content is otherwise identical to remote.
**Expected:** Sentinel not counted as a diff; no update triggered.

---

## 23. Installer — bash, no existing ~/.bashrc
**Setup:** Remove `~/.bashrc`; run `Install-DollarSignPROFILE.sh` with `$SHELL=/bin/bash`.
**Expected:** `~/.bashrc` created with downloaded content; no backup attempted; success message printed in green.

---

## 24. Installer — bash, existing ~/.bashrc
**Setup:** Ensure `~/.bashrc` exists; run installer with `$SHELL=/bin/bash`.
**Expected:** `~/.bashrc.bak.<timestamp>` created with original content; `~/.bashrc` overwritten; success and restart message printed.

---

## 25. Installer — zsh, existing ~/.zshrc
**Setup:** Ensure `~/.zshrc` exists; run installer with `$SHELL=/bin/zsh`.
**Expected:** `~/.zshrc.bak.<timestamp>` created; `~/.zshrc` overwritten; restart message printed.

---

## 26. Installer — network failure
**Setup:** Run installer with network disabled.
**Expected:** Error message printed in red; no rc file written or overwritten; backup (if created) preserved; installer exits with non-zero status.

---

## 27. Installer — unknown shell
**Setup:** Run installer with `SHELL=/bin/fish` (or any non-bash/zsh value).
**Expected:** Installer falls through to the `*` case; installs both bash and zsh profiles; informational message printed.

---

## 28. Installer — one-liner invocation
**Setup:** `curl -fsSL <raw-install-url> | bash`
**Expected:** Installer runs end-to-end; profile written; restart instruction visible in output.
