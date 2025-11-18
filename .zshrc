# load zgenom
source "$HOME/.zgenom/zgenom.zsh"
export EDITOR='nvim'
export VEDITOR='code'

export ZGEN_RESET_ON_CHANGE=(${HOME}/.zshrc ${HOME}/.zshrc.local)

# check for updates every 7 days
zgenom autoupdate --background

local arch=$(uname -m)

# Common bin paths to check and add if present
local -a bin_paths=(
  /usr/local/bin
  /opt/homebrew/bin
  "$HOME/bin"
  "$HOME/.local/bin"
)

for bin_path in "${bin_paths[@]}"; do
  if [[ -d $bin_path && ":$PATH:" != *":$bin_path:"* ]]; then
    path=($bin_path $path)
  fi
done

if ! zgenom saved; then
  echo "Creating zgenom save state..."

  zgenom compdef

  # extensions
  zgenom load jandamm/zgenom-ext-eval
  zgenom load jandamm/zgenom-ext-release

  # omz
  zgenom ohmyzsh
  zgenom ohmyzsh plugins/git
  zgenom ohmyzsh plugins/sudo

  # qol
  zgenom load djui/alias-tips
  zgenom load hlissner/zsh-autopair

  # fzf
  zgenom load junegunn/fzf shell
  zgenom load urbainvaes/fzf-marks
  zgenom load wfxr/forgit

  zgenom load "$HOME/.config/zsh"

  zgenom load zsh-users/zsh-syntax-highlighting
  zgenom load zsh-users/zsh-history-substring-search
  zgenom load zsh-users/zsh-completions

  if command -v brew &>/dev/null && [[ -d $(brew --prefix)/share/zsh/site-functions ]]; then
    zgenom load --completion $(brew --prefix)/share/zsh/site-functions
  fi

  zgenom save

# Compile zsh files
  zgenom compile "$HOME/.zshrc"

  echo "...done"
fi

[ -d $HOME/.zgenom/bin ] && path=(~/.zgenom/bin $path)
[ -d ~/.local ] && path=(~/.local/bin $path)

command -v mise &>/dev/null && eval "$(mise activate zsh)"
command -v direnv &>/dev/null && eval "$(direnv hook zsh)"
command -v starship &>/dev/null && eval "$(starship init zsh)"
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

[[ -e "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"