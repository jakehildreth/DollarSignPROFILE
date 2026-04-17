Supported environments for initial release:
  - Windows 10/Server 2016+
  - macOS Sonoma+

Check for installed packages:
  - oh-my-posh
  - git
  - VS Code
  - latest version of $PROFILE
If all required packages are installed, exit. Otherwise, continue on.

Check for installed package manager:
  - winget (Windows)
  - brew (macOS, WSL?)
If no package manager, attempt to install the correct one for the OS.

If package manager installs, install any missing packages.

Windows-only: check for pwsh and Windows Terminal. If not found, ask user if they want to install each.

If package manager does not install (Windows, probably), install packages manually.
  - oh-my-posh via PowerShell 
  - git Portable
  - VS Code per-user installer: https://go.microsoft.com/fwlink/?LinkID=534107
  - pwsh via MSI
  


