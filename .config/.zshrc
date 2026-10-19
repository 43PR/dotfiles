# --------------------------------------------------
# Live autocompletion (must be sourced FIRST, before compinit)
# --------------------------------------------------

source /usr/share/zsh/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh

# Start suggesting after 1 character, with a tiny delay so it feels smooth
zstyle ':autocomplete:*' min-input 1
zstyle ':autocomplete:*' delay 0.05

# Tab cycles through the menu, Shift+Tab goes backwards
bindkey '^I' menu-complete
bindkey "$terminfo[kcbt]" reverse-menu-complete

# Keep Up/Down arrows as normal history navigation
bindkey '^[[A' up-line-or-history
bindkey '^[[B' down-line-or-history

# --------------------------------------------------
# Prompt
# --------------------------------------------------

eval "$(starship init zsh)"

# --------------------------------------------------
# eza (monochrome)
# --------------------------------------------------

export EZA_COLORS="uu=bright-black:gu=bright-black:da=bright-black:ur=white:uw=bright-black:ux=white:ue=bright-black:gr=bright-black:gw=bright-black:gx=white:tr=bright-black:fi=white:di=bright-white:ln=bright-black:pi=bright-black:so=bright-black:bd=bright-black:cd=bright-black:or=bright-black:mi=bright-black:ex=white"

alias ls='eza --icons'
alias ll='eza -lah --icons --git'
alias la='eza -a --icons'
alias lt='eza --tree --icons'

# --------------------------------------------------
# Completion styling
# --------------------------------------------------

# Case-insensitive matching
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Grayscale completion colors
zstyle ':completion:*' list-colors \
  '=(#b)*(=0)=38;5;250' \
  '=(#b)*(=1)=38;5;255' \
  '=(#b)*(=2)=38;5;245' \
  '=(#b)*(=3)=38;5;240'

# Dim group headers
zstyle ':completion:*:descriptions' format '%F{8}-- %d --%f'

# --------------------------------------------------
# History
# --------------------------------------------------

HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS

# --------------------------------------------------
# Autosuggestions
# --------------------------------------------------

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# --------------------------------------------------
# Syntax highlighting (keep LAST)
# --------------------------------------------------

source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

ZSH_HIGHLIGHT_STYLES[command]='fg=white'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=white'
ZSH_HIGHLIGHT_STYLES[function]='fg=white'
ZSH_HIGHLIGHT_STYLES[alias]='fg=white'
ZSH_HIGHLIGHT_STYLES[path]='fg=245'
ZSH_HIGHLIGHT_STYLES[comment]='fg=240'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=245'

# --------------------------------------------------
# 43PR theme controller
# --------------------------------------------------

theme() { python3 "$HOME/.config/43pr/bin/theme.py" "$@"; }
