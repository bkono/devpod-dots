#!/usr/bin/env bash

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

echo "Linking dotfiles..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

link_item() {
  local src="$1"
  local dst="$2"

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

for item in "$SCRIPT_DIR"/*; do
  name=$(basename "$item")
  # Skip self (the install script)
  [ "$name" = "install.sh" ] && continue

  target="$HOME/$name"

  link_item "$item" "$target"
done
