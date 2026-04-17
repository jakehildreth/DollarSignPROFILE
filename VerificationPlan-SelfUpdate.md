# Verification Plan: Self-Update Block

Feature: `#region Self-Update` in `DollarSignPROFILE.ps1`

---

## Test Cases

### 1. No preference + content identical (no-op)
**Setup:** `$PROFILE` has no sentinel line; local content matches remote exactly.
**Expected:** No prompt, no file write, no reload. Profile loads normally.

### 2. No preference + content differs (prompt appears)
**Setup:** `$PROFILE` has no sentinel line; manually alter one character in the local file.
**Expected:** `PromptForChoice` appears with all 4 options.

### 3. Prompt choice: Yes, always
**Setup:** No sentinel, content differs.
**Action:** Choose `Yes, always`.
**Expected:**
- `# DollarSignPROFILE:AutoUpdate=always` written as first line of `$PROFILE`
- Remote content written to `$PROFILE`
- Profile reloads via `. $PROFILE`
- Old execution context stops (`return`)
- On next load with matching content: no prompt, no write

### 4. Prompt choice: Yes, just this time
**Setup:** No sentinel, content differs.
**Action:** Choose `Yes, just this time`.
**Expected:**
- No sentinel line written
- Remote content written to `$PROFILE`
- Profile reloads via `. $PROFILE`
- Old execution context stops (`return`)
- On next load with matching content: no prompt, no write
- On next load with differing content: prompt appears again

### 5. Prompt choice: No, not this time
**Setup:** No sentinel, content differs.
**Action:** Choose `No, not this time`.
**Expected:**
- No file write
- No reload
- No sentinel written
- Profile continues loading existing content
- On next load with same diff: prompt appears again

### 6. Prompt choice: No, never
**Setup:** No sentinel, content differs.
**Action:** Choose `No, never`.
**Expected:**
- `# DollarSignPROFILE:AutoUpdate=never` written as first line of `$PROFILE`
- Remote content NOT applied
- No reload
- On next load: no network request, no prompt, profile loads normally

### 7. Preference: always + content differs
**Setup:** `$PROFILE` has `# DollarSignPROFILE:AutoUpdate=always` as first line; content differs.
**Expected:**
- No prompt
- Remote content written to `$PROFILE` with sentinel re-prepended
- Profile reloads silently
- Old execution context stops (`return`)

### 8. Preference: always + content identical
**Setup:** `$PROFILE` has `# DollarSignPROFILE:AutoUpdate=always`; content matches remote (after stripping sentinel).
**Expected:** No write, no reload, profile loads normally.

### 9. Preference: never
**Setup:** `$PROFILE` has `# DollarSignPROFILE:AutoUpdate=never`.
**Expected:** No network request made, no prompt, profile loads normally.

### 10. Network unavailable
**Setup:** Disconnect from network (or point `$selfUpdateUrl` at an invalid host).
**Expected:** `catch` block fires silently; no error output; profile loads fully as-is regardless of preference.

### 11. Sentinel stripped before comparison
**Setup:** `$PROFILE` has `# DollarSignPROFILE:AutoUpdate=always`; content otherwise matches remote.
**Expected:** No update triggered (sentinel not treated as a diff driver).

### 12. Fresh install — no sentinel, content matches
**Setup:** Install via `iwr profile.jakehildreth.com | iex`; no edits made.
**Expected:** No prompt on first load; local and remote content match immediately after install.
