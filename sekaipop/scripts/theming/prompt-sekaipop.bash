# sekaipop: managed file, removed by Settings -> Desktop -> App colours (revert)
# The bash side of the "Terminal prompt" target. app-theme.sh copies this template to
# ~/.local/state/sekaipop/terminal/prompt.bash (filling in @SEQ@ and @BIN@), and one managed
# block at the end of ~/.bashrc sources it.
#
#   - the plates come from prompt.sh (the same script as fish's) and go INTO PS1, every escape
#     wrapped in \[ \], so readline and ble.sh know the prompt's width and Ctrl+L redraws them.
#     Folder and branch names are escaped first (\ $ `): PS1 is expanded, and a folder called
#     $(something) must not run.
#   - the command time comes from PS0, which writes $EPOCHREALTIME to a small file just before
#     each command runs (PS0 runs in a subshell, so it can't set a variable).
#   - ble.sh, when installed, gives fish-style suggestions from your history as you type
#     (grey text; Right arrow or End takes it) and syntax colours. AUR: blesh-git.

[[ $- == *i* ]] || return 0

for __sekaipop_ble in /usr/share/blesh/ble.sh "${XDG_DATA_HOME:-$HOME/.local/share}/blesh/ble.sh"; do
    if [[ -f $__sekaipop_ble && -z ${BLE_VERSION-} ]]; then
        source "$__sekaipop_ble" --noattach
        break
    fi
done
unset __sekaipop_ble

[ -f '@SEQ@' ] && cat '@SEQ@'

__sekaipop_tf="${XDG_RUNTIME_DIR:-/tmp}/sekaipop-prompt-$$"
PS0='$(printf %s "${EPOCHREALTIME/[.,]/}" > "$__sekaipop_tf")'

__sekaipop_prompt() {
    local st=$? ms=0 t0 now out rows ac=243
    if [ -f "$__sekaipop_tf" ]; then
        read -r t0 < "$__sekaipop_tf"; rm -f "$__sekaipop_tf"
        now=${EPOCHREALTIME/[.,]/}; ms=$(( (now - t0) / 1000 ))
    fi
    [ -f '@BIN@' ] || return "$st"
    out=$(sh '@BIN@' "$st" "$ms" "$PWD" "${COLUMNS:-80}")
    rows=$(printf '%s' "${out%$'\n'*}" | sed -e 's/[\\$`]/\\&/g' -e 's/\x1b\[[0-9;]*m/\\[&\\]/g')
    [ "$st" -ne 0 ] && ac=244
    PS1="${rows}\n\[\e[1;38;5;${ac}m\] "$'\357\201\213'"\[\e[0m\] "
    return "$st"
}
[[ $PROMPT_COMMAND == *__sekaipop_prompt* ]] || PROMPT_COMMAND="__sekaipop_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}"

if [[ ${BLE_VERSION-} ]]; then
    bleopt complete_auto_history=1 2>/dev/null
    ble-attach
fi
