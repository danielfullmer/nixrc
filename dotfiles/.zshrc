if [[ "$TERM" == "xterm" && "$COLORTERM" == "gnome-terminal" ]]; then
	export TERM=xterm-256color
fi

bindkey -e # Use emacs keys

fpath=("${HOME}/.zsh-completions/src" $fpath)
autoload -U compinit && compinit
source "${HOME}/.zsh-autosuggestions/zsh-autosuggestions.zsh"
source "${HOME}/.zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

BASE16_SHELL="${HOME}/.base16-shell/base16-tomorrow.dark.sh"
[[ -s $BASE16_SHELL ]] && . $BASE16_SHELL

source "${HOME}/.zshrc.prompt"

# Extra aliases
source "${HOME}/.aliases"