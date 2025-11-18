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

for item in "$SCRIPT_DIR"/*; do
  name=$(basename "$item")
  # Skip self (the install script)
  [ "$name" = "install.sh" ] && continue

  target="$HOME/$name"

  # If there's already something at the target, move it aside
  if [ -e "$target" ] || [ -L "$target" ]; then
    backup="$target.backup.$(date +%Y%m%d%H%M%S)"
    echo "Moving existing $target to $backup..."
    mv "$target" "$backup"
  fi

  ln -s "$item" "$target"
  echo "Linked $name → $target"
done
