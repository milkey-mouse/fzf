# Key bindings
# ------------
__fzf_select__() {
  local cmd="${FZF_CTRL_T_COMMAND:-"command find -L . -mindepth 1 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune \
    -o -type f -print \
    -o -type d -print \
    -o -type l -print 2> /dev/null | cut -b3-"}"
  eval "$cmd" | FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} --reverse $FZF_DEFAULT_OPTS $FZF_CTRL_T_OPTS" fzf -m "$@" | while read -r item; do
    printf '%q ' "$item"
  done
  echo
}

if [[ $- =~ i ]]; then

__fzf_use_tmux__() {
  [ -n "$TMUX_PANE" ] && [ "${FZF_TMUX:-0}" != 0 ] && [ ${LINES:-40} -gt 15 ]
}

__fzfcmd() {
  __fzf_use_tmux__ &&
    echo "fzf-tmux -d${FZF_TMUX_HEIGHT:-40%}" || echo "fzf"
}

__fzf_select_tmux__() {
  local height
  height=${FZF_TMUX_HEIGHT:-40%}
  if [[ $height =~ %$ ]]; then
    height="-p ${height%\%}"
  else
    height="-l $height"
  fi

  tmux split-window $height "cd $(printf %q "$PWD"); FZF_DEFAULT_OPTS=$(printf %q "$FZF_DEFAULT_OPTS") PATH=$(printf %q "$PATH") FZF_CTRL_T_COMMAND=$(printf %q "$FZF_CTRL_T_COMMAND") FZF_CTRL_T_OPTS=$(printf %q "$FZF_CTRL_T_OPTS") bash -c 'source \"${BASH_SOURCE[0]}\"; RESULT=\"\$(__fzf_select__ --no-height)\"; tmux setb -b fzf \"\$RESULT\" \\; pasteb -b fzf -t $TMUX_PANE \\; deleteb -b fzf || tmux send-keys -t $TMUX_PANE \"\$RESULT\"'"
}

fzf-file-widget() {
  if __fzf_use_tmux__; then
    __fzf_select_tmux__
  else
    local selected="$(__fzf_select__)"
    READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}$selected${READLINE_LINE:$READLINE_POINT}"
    READLINE_POINT=$(( READLINE_POINT + ${#selected} - 3 ))
  fi
}

__fzf_cd__() {
  local cmd dir
  cmd="${FZF_ALT_C_COMMAND:-"command find -L . -mindepth 1 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune \
    -o -type d -print 2> /dev/null | cut -b3-"}"
  dir=$(eval "$cmd" | FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} --reverse $FZF_DEFAULT_OPTS $FZF_ALT_C_OPTS" $(__fzfcmd) +m) && printf 'cd %q' "$dir"
}

__fzf_history_3__() (
  local out line
  shopt -u nocaseglob nocasematch
  out="$(
    HISTTIMEFORMAT= history | sed 's/^\s*[0-9]*\s*//g' |
    FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} $FZF_DEFAULT_OPTS --tac --sync --tiebreak=index --expect=ENTER,ESC,HOME,END,LEFT,RIGHT --bind=ctrl-r:toggle-sort $FZF_CTRL_R_OPTS +m" $(__fzfcmd)
  )"
  line="$(tail -n+2 <<< "$out")"
  if [[ ! -z "$line" ]] && [[ "$(head -n1 <<< "$out")" == "ENTER" ]]; then
    history -s "$line"
    # print a newline as if ENTER had actually been pressed
    echo "${PS1@P}$line" > /dev/tty
    eval $line &> /dev/tty
  else
    echo "$line"
  fi
)

fzf-history-run() {
  local out line key
  shopt -u nocaseglob nocasematch
  out="$(
    HISTTIMEFORMAT= history | sed 's/^\s*[0-9]*\s*//g' |
    FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} $FZF_DEFAULT_OPTS --tac --sync --tiebreak=index --expect=ENTER,ESC,HOME,END,LEFT,RIGHT --bind=ctrl-r:toggle-sort $FZF_CTRL_R_OPTS +m" $(__fzfcmd)
  )"

  line="$(tail -n+2 <<< "$out")"
  if [[ -z "$line" ]]; then
    return
  fi

  key="$(head -n1 <<< "$out")"
  if [[ "$key" == "ENTER" ]]; then
    history -s "$line"
    echo "${PS1@P}$line"
    eval "$line"
    return
  else
    #READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}$line${READLINE_LINE:$READLINE_POINT}"
    READLINE_LINE="$line"
    if [[ "$key" == "LEFT" ]]; then
      READLINE_POINT=$(( READLINE_POINT + ${#line} - 1 ))
    elif [[ "$key" != "HOME" ]]; then
      READLINE_POINT=$(( READLINE_POINT + ${#line} ))
    fi
  fi
}

if [[ ! -o vi ]]; then
  # Required to refresh the prompt after fzf
  bind '"\er": redraw-current-line'
  bind '"\e^": history-expand-line'

  if [ $BASH_VERSINFO -gt 3 ]; then
    # CTRL-T - Paste the selected file path into the command line
    bind -x '"\C-t": "fzf-file-widget"'

    # CTRL-R - Paste the selected command from history into the command line
    bind -x '"\C-r": "fzf-history-run"'
  else
    if __fzf_use_tmux__; then
      bind '"\C-t": " \C-u \C-a\C-k`__fzf_select_tmux__`\e\C-e\C-y\C-a\C-d\C-y\ey\C-h"'
    else
      bind '"\C-t": " \C-u \C-a\C-k`__fzf_select__`\e\C-e\C-y\C-a\C-y\ey\C-h\C-e\er \C-h"'
    fi

    bind '"\C-r": " \C-e\C-u\C-y\ey\C-u`__fzf_history_3__`\e\C-e\er\e^"'
  fi

  # ALT-C - cd into the selected directory
  bind '"\ec": " \C-e\C-u`__fzf_cd__`\e\C-e\er\C-m"'
else
  # We'd usually use "\e" to enter vi-movement-mode so we can do our magic,
  # but this incurs a very noticeable delay of a half second or so,
  # because many other commands start with "\e".
  # Instead, we bind an unused key, "\C-x\C-a",
  # to also enter vi-movement-mode,
  # and then use that thereafter.
  # (We imagine that "\C-x\C-a" is relatively unlikely to be in use.)
  bind '"\C-x\C-a": vi-movement-mode'

  bind '"\C-x\C-e": shell-expand-line'
  bind '"\C-x\C-r": redraw-current-line'
  bind '"\C-x^": history-expand-line'

  # CTRL-T - Paste the selected file path into the command line
  # - FIXME: Selected items are attached to the end regardless of cursor position
  if [ $BASH_VERSINFO -gt 3 ]; then
    bind -x '"\C-t": "fzf-file-widget"'
  elif __fzf_use_tmux__; then
    bind '"\C-t": "\C-x\C-a$a \C-x\C-addi`__fzf_select_tmux__`\C-x\C-e\C-x\C-a0P$xa"'
  else
    bind '"\C-t": "\C-x\C-a$a \C-x\C-addi`__fzf_select__`\C-x\C-e\C-x\C-a0Px$a \C-x\C-r\C-x\C-axa "'
  fi
  bind -m vi-command '"\C-t": "i\C-t"'

  # CTRL-R - Paste the selected command from history into the command line
  bind '"\C-r": "\C-x\C-addi`__fzf_history__`\C-x\C-e\C-x\C-r\C-x^\C-x\C-a$a"'
  bind -m vi-command '"\C-r": "i\C-r"'

  # ALT-C - cd into the selected directory
  bind '"\ec": "\C-x\C-addi`__fzf_cd__`\C-x\C-e\C-x\C-r\C-m"'
  bind -m vi-command '"\ec": "ddi`__fzf_cd__`\C-x\C-e\C-x\C-r\C-m"'
fi

fi
