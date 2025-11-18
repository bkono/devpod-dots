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

echo "Ensuring node and npm is installed..."
if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  echo "node and/or npm not found. Installing Node.js..."
  $miseCmd use -g node@lts
  $miseCmd use -g pnpm@latest
fi

echo "Installing cli tools..."
$miseCmd use -g delta -y
$miseCmd use -g eza -y
$miseCmd use -g bat -y
$miseCmd use -g ripgrep -y
$miseCmd use -g fzf -y
$miseCmd use -g zoxide -y
$miseCmd use -g starship -y
$miseCmd use -g github-cli -y
$miseCmd use -g lazygit -y

echo "Installing coding agents..."
$miseCmd use -g claude -y
$miseCmd use -g codex -y
$miseCmd use -g gemini-cli -y

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
