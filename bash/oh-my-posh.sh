# Mitchell Hashimoto's Oh My Posh prompt.
# Sourced by ~/.bashrc through ~/.bashrc.d.
if [[ $- == *i* ]] && command -v oh-my-posh >/dev/null 2>&1; then
	eval "$(oh-my-posh init bash --config "${HOME}/.config/oh-my-posh/config.json")"
fi
