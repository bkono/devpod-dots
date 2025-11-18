#!/usr/bin/env bash

echo "Ensuring zgenom is installed"
if [ ! -d "${HOME}/.zgenom" ]; then
  echo "Installing zgenom"
  git clone https://github.com/jandamm/zgenom.git "${HOME}/.zgenom"
fi

echo "Installing lazygit..."
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | \grep -Po '"tag_name": *"v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
install lazygit -D -t /usr/local/bin/

# This allows for better git diffs in git cli and lazygit
echo "Installing cargo..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
echo "export CARGO_HOME='$HOME/.cargo'" >>~/.zshrc
echo "export PATH='$CARGO_HOME/bin:$PATH'" >>~/.zshrc
. "$CARGO_HOME/env"
. "$HOME/.cargo/env"

echo "Installing git-delta, eza, bat, ripgrep.."
cargo install git-delta
cargo install eza
cargo install bat
cargo install ripgrep

echo "Installing fzf..."
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install --all

echo "Installing zoxide..."
cargo install zoxide

echo "Installing starship..."
curl -sS https://starship.rs/install.sh | sh

echo "Installing coding agents..."
echo "Ensuring node and npm is installed..."
if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  echo "node and/or npm not found. Installing Node.js..."

  ARCH=$(uname -m)
  OS=$(uname -s)

  # Set platform string for Node.js binary
  if [ "$OS" = "Linux" ]; then
    PLATFORM="linux"
  elif [ "$OS" = "Darwin" ]; then
    PLATFORM="darwin"
  else
    echo "OS $OS is not supported for automatic Node.js install."
    exit 1
  fi

  # Map architecture
  if [ "$ARCH" = "x86_64" ]; then
    NODE_ARCH="x64"
  elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    NODE_ARCH="arm64"
  else
    echo "Architecture $ARCH is not supported for automatic Node.js install."
    exit 1
  fi

  # Get latest LTS version number
  NODE_VERSION=$(curl -s https://nodejs.org/dist/index.tab | awk '/lts/ {print $1; exit}')
  NODE_DIST="node-v${NODE_VERSION}-${PLATFORM}-${NODE_ARCH}"
  NODE_TAR="${NODE_DIST}.tar.xz"
  NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/${NODE_TAR}"

  echo "Downloading Node.js $NODE_VERSION for $PLATFORM-$NODE_ARCH..."
  curl -fsSL -O "$NODE_URL"

  echo "Extracting Node.js..."
  tar -xf "$NODE_TAR"

  echo "Installing Node.js to /usr/local..."
  sudo cp -r "$NODE_DIST"/{bin,include,lib,share} /usr/local/

  echo "Cleaning up..."
  rm -rf "$NODE_TAR" "$NODE_DIST"
else
  echo "node and npm already installed."
fi

npm install -g @anthropic-ai/claude-code@latest
npm install -g @openai/codex
npm install -g @google/gemini-cli

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
