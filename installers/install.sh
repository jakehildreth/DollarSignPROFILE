#!/usr/bin/env bash
# install.sh
# Installs DollarSignPROFILE to the current user's bash or zsh profile.
#
# .SYNOPSIS
#   Installs DollarSignPROFILE to the current user's bash or zsh rc file.
#
# .DESCRIPTION
#   Downloads DollarSignPROFILE.bash or DollarSignPROFILE.zsh from GitHub,
#   backs up the existing rc file, writes the new profile, and reports status.
#   Target shell is determined from $SHELL. If the shell is not bash or zsh,
#   both profiles are installed.
#
# .EXAMPLE
#   curl -fsSL https://raw.githubusercontent.com/jakehildreth/DollarSignPROFILE/refs/heads/main/installers/install.sh | bash
#
# .NOTES
#   Source: https://github.com/jakehildreth/DollarSignPROFILE

readonly _BASH_PROFILE_URL='https://raw.githubusercontent.com/jakehildreth/DollarSignPROFILE/refs/heads/main/profiles/dotbashrc'
readonly _ZSH_PROFILE_URL='https://raw.githubusercontent.com/jakehildreth/DollarSignPROFILE/refs/heads/main/profiles/dotzshrc'

readonly _CYAN='\033[0;36m'
readonly _GREEN='\033[0;32m'
readonly _RED='\033[0;31m'
readonly _NC='\033[0m'

__info()    { printf "${_CYAN}[i] %s${_NC}\n" "$*"; }
__success() { printf "${_GREEN}[+] %s${_NC}\n" "$*"; }
__error()   { printf "${_RED}[x] %s${_NC}\n" "$*" >&2; }

_install_for_shell() {
    local shell_name="$1"
    local profile_url="$2"
    local rc_file="$3"

    local content
    if ! content="$(curl -fsSL "$profile_url" 2>/dev/null)"; then
                __error "Download failed for ${shell_name} profile (${profile_url}). Verify the URL is reachable and the file exists."
        return 1
    fi

    if [[ -f "$rc_file" ]]; then
        local is_dollarsign=0
        grep -q 'DollarSignPROFILE' "$rc_file" 2>/dev/null && is_dollarsign=1

        local preference
        preference="$(sed -n 's/^# DollarSignPROFILE:AutoUpdate=//p' "$rc_file" | head -1)"

        if [[ "$preference" == 'never' ]]; then
            __info "New ${shell_name} profile available. Skipping."
            __info "To change this behavior, remove this line from your $(basename "$rc_file"):"
            printf '\n  # DollarSignPROFILE:AutoUpdate=never\n\n' 
            return 0
        fi

        __info "Installing ${shell_name} profile → ${rc_file}"

        local _write_header=''

        if [[ "$preference" == 'always' ]]; then
            _write_header='always'
        else
            if [[ "$is_dollarsign" -eq 1 ]]; then
                printf '\nDollarSignPROFILE is already installed in %s. Update it?\n' "$rc_file"
            else
                printf '\n%s already exists and does not appear to be a DollarSignPROFILE install. Overwrite it?\n' "$rc_file"
            fi

            local _choice
            PS3='Your choice: '
            while true; do
                select _choice in 'Yes, always' 'Yes, just this time' 'No, not this time' 'No, never' 'More details'; do
                    case "$REPLY" in
                    1) _write_header='always'; break 2 ;;
                    2) break 2 ;;
                    3) __info "Skipping ${shell_name} profile."; unset _choice _write_header; return 0 ;;
                    4)
                        local _stripped
                        _stripped="$(sed '/^# DollarSignPROFILE:AutoUpdate=/d' "$rc_file")"
                        printf '# DollarSignPROFILE:AutoUpdate=never\n%s\n' "$_stripped" > "$rc_file"
                        __info "AutoUpdate set to never for ${rc_file}. Skipping install."
                        unset _choice _write_header _stripped
                        return 0
                        ;;
                    5)
                        local local_stripped remote_stripped _diff_output
                        local_stripped="$(sed '/^# DollarSignPROFILE:AutoUpdate=/d' "$rc_file")"
                        remote_stripped="$(printf '%s\n' "$content" | sed '/^# DollarSignPROFILE:AutoUpdate=/d')"
                        _diff_output="$(diff <(printf '%s\n' "$local_stripped") <(printf '%s\n' "$remote_stripped"))"
                        if [[ -z "$_diff_output" ]]; then
                            __info "No differences between installed and remote profile."
                        else
                            printf '\n'
                            printf '%s\n' "$_diff_output" \
                                | while IFS= read -r line; do
                                    case "$line" in
                                        '<'*) printf '\033[31m%s\033[0m\n' "$line" ;;
                                        '>'*) printf '\033[32m%s\033[0m\n' "$line" ;;
                                        *)    printf '%s\n' "$line" ;;
                                    esac
                                done
                            printf '\n'
                        fi
                        unset _diff_output
                        break
                        ;;
                    *) printf '[!] Invalid choice. Enter 1-5.\n' ;;
                esac
            done
        done
        unset _choice
        fi  # end: preference != always

        local backup="${rc_file}.bak.$(date +%Y%m%d%H%M%S)"
        if cp "$rc_file" "$backup"; then
            __info "Backup created: ${backup}"
        else
            __error "Could not create backup of ${rc_file}. Aborting."
            return 1
        fi

        if [[ -n "$_write_header" ]]; then
            if ! printf '# DollarSignPROFILE:AutoUpdate=%s\n%s\n' "$_write_header" "$content" > "$rc_file"; then
                __error "Could not write to ${rc_file}."
                return 1
            fi
        else
            if ! printf '%s\n' "$content" > "$rc_file"; then
                __error "Could not write to ${rc_file}."
                return 1
            fi
        fi
        unset _write_header
    else
        __info "Installing ${shell_name} profile → ${rc_file}"
        if ! printf '%s\n' "$content" > "$rc_file"; then
            __error "Could not write to ${rc_file}."
            return 1
        fi
    fi

    __success "${shell_name} profile written to ${rc_file}."
    __info "Restart your ${shell_name} session or run: . ${rc_file}"
}

_detected_shell="$(basename "$SHELL")"

case "$_detected_shell" in
    bash)
        _install_for_shell 'bash' "$_BASH_PROFILE_URL" "$HOME/.bashrc"
        ;;
    zsh)
        _install_for_shell 'zsh' "$_ZSH_PROFILE_URL" "${ZDOTDIR:-$HOME}/.zshrc"
        ;;
    *)
        __info "Shell '${_detected_shell}' not directly targeted. Installing for bash and zsh."
        _install_for_shell 'bash' "$_BASH_PROFILE_URL" "$HOME/.bashrc"
        _install_for_shell 'zsh' "$_ZSH_PROFILE_URL" "${ZDOTDIR:-$HOME}/.zshrc"
        ;;
esac

unset _detected_shell
