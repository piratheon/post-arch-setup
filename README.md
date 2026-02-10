# post-arch-setup

A simple, user-friendly Arch Linux post-install script to install common packages, set up paru (AUR helper), configure shell basics, and apply your trusted Sway dotfiles.

## Highlights
- Safe defaults and idempotent checks
- Builds paru from AUR as the normal user
- Installs curated package list (repo + AUR) via paru
- Installs oh-my-posh theme and nushell config 
- Installs Sway helpers and clones your sway dots
- Installs and enables ly display manager (disables existing DM if found)

## Quick start (one-liner)
Review before running:
```bash
curl -fsSL https://raw.githubusercontent.com/piratheon/post-arch-setup/main/setup-arch.sh | bash
```

## Requirements
- Arch Linux (or pacman-based)
- sudo privileges
- Internet connection

## Usage
1. (Optional) Clone the repo:
   ```bash
   git clone https://github.com/piratheon/post-arch-setup.git
   cd post-arch-setup
   ```
2. Make executable and run:
   ```bash
   chmod +x setup-arch.sh
   ./setup-arch.sh
   ```

Run as your normal user (the script will use sudo for privileged operations and run user-scoped steps with sudo -u).

## Configuration 
Edit variables at the top of `setup-arch.sh` before running:
- WORKDIR — temporary working dir (default: /tmp/.archstp)
- TARGET_USER — user to configure (defaults to the invoking user)
- pkgs — array of packages to install

## What the script does
1. Updates system and refreshes mirrors with reflector  
2. Installs base-devel and git  
3. Clones and builds paru as the target user  
4. Installs packages via paru (repo + AUR)  
5. Installs oh-my-posh theme and nushell config into target user's home 
6. Clones piratheon sway dots into ~/.config/sway and adjusts settings  
7. Installs/enables ly display manager (disables existing DM symlink if present)  
8. Prompts to remove the working directory

## Troubleshooting
- If a package fails, re-run after fixing names or resolving conflicts.
- Check systemd logs:
  ```bash
  sudo journalctl -u ly.service -trusted piratheon files)b
  ```
- For paru/makepkg builds ensure `base-devel` is installed and the build runs as a non-root user.

## Contributing
Open issues or PRs at: https://github.com/piratheon/post-arch-setup

## Author
piratheon — https://github.com/piratheon
