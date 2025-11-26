#!/usr/bin/env bash
set -euo pipefail

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

install_zsh_if_needed() {
  if command -v zsh >/dev/null 2>&1; then
    echo "zsh already present"
    return
  fi

  echo "zsh not found, installing…"
  if command -v apt-get >/dev/null 2>&1; then
    run_as_root apt-get update
    run_as_root DEBIAN_FRONTEND=noninteractive apt-get install -y zsh
  elif command -v apk >/dev/null 2>&1; then
    run_as_root apk add --no-cache zsh
  elif command -v dnf >/dev/null 2>&1; then
    run_as_root dnf install -y zsh
  elif command -v yum >/dev/null 2>&1; then
    run_as_root yum install -y zsh
  elif command -v pacman >/dev/null 2>&1; then
    run_as_root pacman -Sy --noconfirm zsh
  else
    echo "No supported package manager found for automatic zsh install" >&2
    exit 1
  fi
}

set_default_shell() {
  local zsh_path
  zsh_path="$(command -v zsh)"
  [ -n "$zsh_path" ] || return 1

  if ! grep -qx "$zsh_path" /etc/shells; then
    echo "Adding $zsh_path to /etc/shells"
    printf "%s\n" "$zsh_path" | run_as_root tee -a /etc/shells >/dev/null
  fi

  local target_user="${SUDO_USER:-$USER}"
  local current_shell
  current_shell="$(getent passwd "$target_user" | cut -d: -f7)"

  if [ "$current_shell" != "$zsh_path" ]; then
    echo "Setting $target_user default shell to $zsh_path"
    run_as_root chsh -s "$zsh_path" "$target_user"
  fi
}

install_zsh_if_needed
set_default_shell

echo "Ensuring zgenom is installed"
if [ ! -d "${HOME}/.zgenom" ]; then
  echo "Installing zgenom"
  git clone https://github.com/jandamm/zgenom.git "${HOME}/.zgenom"
fi

miseCmd="$HOME/.local/bin/mise"

echo "Ensuring mise is installed"
if ! command -v $miseCmd &>/dev/null; then
  echo "Installing mise"
  curl https://mise.run | sh
  $miseCmd settings set experimental true
fi

$miseCmd trust
eval "$($miseCmd activate bash)"

echo "Ensuring node and npm is installed..."
if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  echo "node and/or npm not found. Installing Node.js..."
  mise use -g node@lts
  mise use -g pnpm@latest
fi

echo "Installing cli tools..."
mise use -g delta -y
mise use -g eza -y
mise use -g bat -y
mise use -g ripgrep -y
mise use -g fzf -y
mise use -g zoxide -y
mise use -g starship -y
mise use -g github-cli -y
mise use -g lazygit -y

echo "Installing coding agents..."
mise use -g claude -y
mise use -g codex -y
mise use -g gemini-cli -y
mise use -g code -y
# mise use -g opencode -y

echo "Linking dotfiles..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "DEBUG: SCRIPT_DIR is: $SCRIPT_DIR"

# Merge credential section from existing gitconfig into source gitconfig
merge_gitconfig_credentials() {
  local src="$1"
  local dst="$2"

  # Only process if both files exist and destination is not a symlink
  if [ ! -f "$src" ] || [ ! -f "$dst" ] || [ -L "$dst" ]; then
    return 0
  fi

  # Check if existing gitconfig has a credential section
  if ! git config -f "$dst" --get-regexp "^credential\." >/dev/null 2>&1 && \
     ! grep -q "^\[credential" "$dst" 2>/dev/null; then
    return 0
  fi

  echo "Found existing [credential] section in $dst, merging into $src..."

  # Create temp file for credential section
  local temp_cred_file
  temp_cred_file=$(mktemp /tmp/gitconfig_credential_XXXXXX) || {
    echo "Error: Failed to create temporary file for credential section" >&2
    return 1
  }

  # Extract the credential section from existing file
  # This awk script extracts from [credential] to the next [section] or end of file
  if ! awk '
    /^\[credential/ { in_credential=1; print; next }
    in_credential && /^\[/ { in_credential=0 }
    in_credential { print }
    END { if (in_credential) print "" }
  ' "$dst" > "$temp_cred_file" 2>/dev/null; then
    echo "Warning: Failed to extract credential section from $dst" >&2
    rm -f "$temp_cred_file"
    return 0  # Continue with normal linking despite the warning
  fi

  # Only proceed if we extracted something
  if [ ! -s "$temp_cred_file" ]; then
    rm -f "$temp_cred_file"
    return 0
  fi

  # Only append if source doesn't already have credential section
  if grep -q "^\[credential" "$src" 2>/dev/null; then
    echo "Source file already has [credential] section, skipping merge"
    rm -f "$temp_cred_file"
    return 0
  fi

  # Append credential section to source file
  if ! { echo "" >> "$src" && cat "$temp_cred_file" >> "$src"; } 2>/dev/null; then
    echo "Error: Failed to append credential section to $src" >&2
    rm -f "$temp_cred_file"
    return 1
  fi

  echo "Merged [credential] section into $src"
  rm -f "$temp_cred_file"
  return 0
}

link_item() {
  local src="$1"
  local dst="$2"

  # Special handling for .gitconfig
  if [ "$(basename "$src")" = ".gitconfig" ]; then
    if ! merge_gitconfig_credentials "$src" "$dst"; then
      return 1
    fi
  fi

  # Check if already linked
  if [ -L "$dst" ]; then
    local currentSrc="$(readlink -f "$dst")"
    local absSrc="$(readlink -f "$src")"
    if [ "$currentSrc" == "$absSrc" ]; then
      echo "$(basename "$src") is already linked. Skipping"
      return
    fi
  fi

  if [ -d "$src" ]; then
    # If the target exists and is a directory, we descend one level
    if [ -d "$dst" ] && [ ! -L "$dst" ]; then
      for child in "$src"/*; do
        [ -e "$child" ] || continue # skip empty dir
        child_name=$(basename "$child")
        link_item "$child" "$dst/$child_name"
      done
    else
      # Handle the case where dst doesn't exist or is a file/symlink
      if [ -e "$dst" ] || [ -L "$dst" ]; then
        backup="$dst.backup.$(date +%Y%m%d%H%M%S)"
        echo "Moving existing $dst to $backup..."
        mv "$dst" "$backup"
      fi
      ln -s "$src" "$dst"
      echo "Linked $(basename "$src") → $dst"
    fi
  else
    # Regular file or symlink
    if [ -e "$dst" ] || [ -L "$dst" ]; then
      backup="$dst.backup.$(date +%Y%m%d%H%M%S)"
      echo "Moving existing $dst to $backup..."
      mv "$dst" "$backup"
    fi
    ln -s "$src" "$dst"
    echo "Linked $(basename "$src") → $dst"
  fi
}

shopt -s dotglob
for item in "$SCRIPT_DIR"/*; do
  name=$(basename "$item")
  # Skip self (the install script) and .git directory
  [ "$name" = "install.sh" ] && continue
  [ "$name" = ".git" ] && continue

  target="$HOME/$name"

  link_item "$item" "$target"
done
