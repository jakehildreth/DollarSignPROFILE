#!/usr/bin/env bash
# Install-DollarSignPROFILE.sh
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
#   curl -fsSL https://raw.githubusercontent.com/jakehildreth/DollarSignPROFILE/refs/heads/main/Install-DollarSignPROFILE.sh | bash
#
# .NOTES
#   Source: https://github.com/jakehildreth/DollarSignPROFILE

readonly _BASH_PROFILE_URL='https://raw.githubusercontent.com/jakehildreth/DollarSignPROFILE/refs/heads/main/DollarSignPROFILE.bash'
readonly _ZSH_PROFILE_URL='https://raw.githubusercontent.com/jakehildreth/DollarSignPROFILE/refs/heads/main/DollarSignPROFILE.zsh'

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

    __info "Installing ${shell_name} profile → ${rc_file}"

    local content
    if ! content="$(curl -fsSL "$profile_url" 2>/dev/null)"; then
        __error "Download failed for ${shell_name} profile. Check network connectivity."
        return 1
    fi

    if [[ -f "$rc_file" ]]; then
        local backup="${rc_file}.bak.$(date +%Y%m%d%H%M%S)"
        if cp "$rc_file" "$backup"; then
            __info "Backup created: ${backup}"
        else
            __error "Could not create backup of ${rc_file}. Aborting."
            return 1
        fi
    fi

    if ! printf '%s\n' "$content" > "$rc_file"; then
        __error "Could not write to ${rc_file}."
        return 1
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
