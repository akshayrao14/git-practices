#!/usr/bin/env bash
# repohue — per-repo deterministic terminal theming
# Detects current git repo (worktree-aware), hashes repo name to a palette,
# emits OSC colour sequences to retheme the terminal live on cd.
# Light/dark variants. .repohue in repo root overrides hash pick.

# ---- config ----
_REPOHUE_DIR="$HOME/.config/repohue"
_REPOHUE_MODE_FILE="$_REPOHUE_DIR/mode"     # auto | light | dark
# Scope dir: if non-empty, only theme inside this tree.
# If empty/unset, theme in ANY git repo anywhere on the system.
_REPOHUE_SCOPE_DIR="${REPOHUE_SCOPE_DIR:-}"
mkdir -p "$_REPOHUE_DIR"
[ -f "$_REPOHUE_MODE_FILE" ] || echo auto > "$_REPOHUE_MODE_FILE"

# One-time migration: pull mode from legacy rao-terminal-theme config dir.
if [ ! -s "$_REPOHUE_MODE_FILE" ] && [ -f "$HOME/.config/rao-terminal-theme/mode" ]; then
  cp "$HOME/.config/rao-terminal-theme/mode" "$_REPOHUE_MODE_FILE" 2>/dev/null
fi

# Hue keys in fixed order — hash index maps into this list.
_REPOHUE_HUES=(red orange yellow green cyan blue purple magenta)

# Palette: per hue, dark and light variants. Each variant = bg fg cursor accent.
declare -gA _REPOHUE_PAL
_REPOHUE_PAL[red_dark]="#2a1414 #e8dada #e06060 #e06060"
_REPOHUE_PAL[red_light]="#fae4e4 #1a1010 #c03030 #c03030"
_REPOHUE_PAL[orange_dark]="#2a1f10 #e8e0d4 #e09060 #e09060"
_REPOHUE_PAL[orange_light]="#faf0e4 #1a1410 #c06030 #c06030"
_REPOHUE_PAL[yellow_dark]="#2a2810 #e8e6d4 #d0c060 #d0c060"
_REPOHUE_PAL[yellow_light]="#fafae4 #1a1a10 #a08030 #a08030"
_REPOHUE_PAL[green_dark]="#142a14 #dae8da #60c060 #60c060"
_REPOHUE_PAL[green_light]="#e4fae4 #101a10 #308030 #308030"
_REPOHUE_PAL[cyan_dark]="#102a2a #d4e6e6 #60c0c0 #60c0c0"
_REPOHUE_PAL[cyan_light]="#e4fafa #101a1a #308080 #308080"
_REPOHUE_PAL[blue_dark]="#14142a #dadae8 #6080e0 #6080e0"
_REPOHUE_PAL[blue_light]="#e4e4fa #10101a #3050b0 #3050b0"
_REPOHUE_PAL[purple_dark]="#1f142a #e0dae8 #9060e0 #9060e0"
_REPOHUE_PAL[purple_light]="#f0e4fa #14101a #6030b0 #6030b0"
_REPOHUE_PAL[magenta_dark]="#2a142a #e8dae8 #e060c0 #e060c0"
_REPOHUE_PAL[magenta_light]="#fae4fa #1a101a #b03090 #b03090"

# ---- helpers ----

# Wrap an escape sequence for tmux passthrough if inside tmux.
_repohue_osc() {
  local seq="$1"
  if [ -n "$TMUX" ]; then
    printf '\ePtmux;\e%s\e\\' "$seq"
  else
    printf '%s' "$seq"
  fi
}

# Hex (#rrggbb) -> "R G B"
_repohue_hex_rgb() {
  local hex="${1#\#}"
  printf '%d %d %d' "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

# Resolve effective mode: auto -> read gsettings, else literal.
_repohue_mode() {
  local m
  m="$(cat "$_REPOHUE_MODE_FILE" 2>/dev/null)"
  case "$m" in
    light|dark) printf '%s' "$m"; return ;;
  esac
  if command -v gsettings >/dev/null 2>&1; then
    local cs
    cs="$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)"
    case "$cs" in
      *prefer-dark*) printf dark ;;
      *prefer-light*) printf light ;;
      *) printf dark ;;
    esac
  else
    printf dark
  fi
}

# Detect current repo name. Echoes name or empty.
# Worktree-aware: uses git common-dir parent.
# If _REPOHUE_SCOPE_DIR is set, only fires inside that tree.
# If unset, fires in any git repo anywhere.
_repohue_repo_name() {
  if [ -n "$_REPOHUE_SCOPE_DIR" ]; then
    case "$PWD/" in
      "$_REPOHUE_SCOPE_DIR"/*) ;;
      *) return ;;
    esac
  fi
  command -v git >/dev/null 2>&1 || return
  local common abs
  common="$(git rev-parse --git-common-dir 2>/dev/null)" || return
  [ -z "$common" ] && return
  if [ -d "$common" ]; then
    abs="$(cd "$common/.." 2>/dev/null && pwd)" || return
    basename "$abs"
  fi
}

# Deterministic palette index for repo name.
_repohue_hash_idx() {
  local name="$1" sum
  sum="$(printf '%s' "$name" | cksum | awk '{print $1}')"
  printf '%s' "$(( sum % ${#_REPOHUE_HUES[@]} ))"
}

# Resolve hue for repo: .repohue override > hash.
_repohue_pick_hue() {
  local name="$1"
  local root override
  root="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ -n "$root" ] && [ -f "$root/.repohue" ]; then
    override="$(head -n1 "$root/.repohue" | awk '{print $1}' | tr '[:upper:]' '[:lower:]')"
    for h in "${_REPOHUE_HUES[@]}"; do
      [ "$h" = "$override" ] && { printf '%s' "$h"; return; }
    done
  fi
  local idx
  idx="$(_repohue_hash_idx "$name")"
  printf '%s' "${_REPOHUE_HUES[$idx]}"
}

# Apply terminal bg/fg/cursor via OSC.
_repohue_apply_palette() {
  local key="$1"
  local entry="${_REPOHUE_PAL[$key]}"
  [ -z "$entry" ] && return
  # shellcheck disable=SC2206
  local arr=($entry)
  local bg="${arr[0]}" fg="${arr[1]}" cur="${arr[2]}"
  _repohue_osc "$(printf '\033]10;%s\007' "$fg")"
  _repohue_osc "$(printf '\033]11;%s\007' "$bg")"
  _repohue_osc "$(printf '\033]12;%s\007' "$cur")"
}

_repohue_reset_palette() {
  _repohue_osc "$(printf '\033]110\007')"
  _repohue_osc "$(printf '\033]111\007')"
  _repohue_osc "$(printf '\033]112\007')"
}

_repohue_set_title() {
  printf '\033]0;%s\007' "$1"
}

# tmux status bar tint (no-op outside tmux). Silent failures.
# REPOHUE_NO_TMUX=1 disables.
_repohue_apply_tmux() {
  [ -z "$TMUX" ] && return
  [ "${REPOHUE_NO_TMUX:-0}" = 1 ] && return
  command -v tmux >/dev/null 2>&1 || return
  local accent="$1" bg="$2"
  tmux set-option -gw window-status-current-style "bg=$accent,fg=#000000,bold" 2>/dev/null
  tmux set-option -g  status-left-style          "bg=$accent,fg=#000000,bold" 2>/dev/null
  tmux set-option -g  status-style               "bg=$bg,fg=$accent"           2>/dev/null
}

_repohue_reset_tmux() {
  [ -z "$TMUX" ] && return
  command -v tmux >/dev/null 2>&1 || return
  tmux set-option -gu window-status-current-style 2>/dev/null
  tmux set-option -gu status-left-style           2>/dev/null
  tmux set-option -gu status-style                2>/dev/null
}

# Print "→ repohue: <repo> [<hue> <mode>]" to stderr, accent-coloured.
# REPOHUE_QUIET=1 disables. Only fires when repo/hue/mode actually changed.
_repohue_notify() {
  [ "${REPOHUE_QUIET:-0}" = 1 ] && return
  local repo="$1" hue="$2" mode="$3" accent="$4"
  local r g b
  read -r r g b <<<"$(_repohue_hex_rgb "$accent")"
  printf '\033[2m→ repohue: \033[22m\033[38;2;%d;%d;%dm%s\033[0m \033[2m[%s %s]\033[0m\n' \
    "$r" "$g" "$b" "$repo" "$hue" "$mode" >&2
}

# Apply theme for current dir. Called on cd or mode change.
_repohue_theme_apply() {
  local name hue mode key branch title entry arr bg fg accent
  local prev_repo="$REPOHUE_REPO" prev_hue="$REPOHUE_HUE" prev_mode="$REPOHUE_MODE"

  name="$(_repohue_repo_name)"
  if [ -z "$name" ]; then
    _repohue_reset_palette
    _repohue_reset_tmux
    _repohue_set_title "${PWD/#$HOME/~}"
    export REPOHUE_REPO="" REPOHUE_HUE="" REPOHUE_MODE="" REPOHUE_ACCENT=""
    return
  fi

  hue="$(_repohue_pick_hue "$name")"
  mode="$(_repohue_mode)"
  key="${hue}_${mode}"
  _repohue_apply_palette "$key"

  entry="${_REPOHUE_PAL[$key]}"
  # shellcheck disable=SC2206
  arr=($entry)
  bg="${arr[0]}"; fg="${arr[1]}"; accent="${arr[3]}"

  branch="$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)"
  if [ -n "$branch" ]; then title="$name ($branch)"; else title="$name"; fi
  _repohue_set_title "$title"

  _repohue_apply_tmux "$accent" "$bg"

  export REPOHUE_REPO="$name"
  export REPOHUE_HUE="$hue"
  export REPOHUE_MODE="$mode"
  export REPOHUE_ACCENT="$accent"

  # Notify only on transition (different repo/hue/mode).
  if [ "$prev_repo" != "$name" ] || [ "$prev_hue" != "$hue" ] || [ "$prev_mode" != "$mode" ]; then
    _repohue_notify "$name" "$hue" "$mode" "$accent"
  fi
}

# ---- prompt hook ----
_REPOHUE_LAST_KEY=""
_repohue_hook() {
  local key="$PWD|$(cat "$_REPOHUE_MODE_FILE" 2>/dev/null)"
  if [ "$key" != "$_REPOHUE_LAST_KEY" ]; then
    _REPOHUE_LAST_KEY="$key"
    _repohue_theme_apply
  fi
}

# Install hook into PROMPT_COMMAND (idempotent).
case ";${PROMPT_COMMAND:-};" in
  *";_repohue_hook;"*) ;;
  *) PROMPT_COMMAND="_repohue_hook;${PROMPT_COMMAND:-}" ;;
esac

# ---- user-facing CLI ----
repohue() {
  local cmd="${1:-status}"; shift 2>/dev/null
  case "$cmd" in
    status|"")
      printf 'repo:    %s\n' "${REPOHUE_REPO:-<none>}"
      printf 'hue:     %s\n' "${REPOHUE_HUE:-<none>}"
      printf 'mode:    %s (file: %s)\n' "$(_repohue_mode)" "$(cat "$_REPOHUE_MODE_FILE")"
      printf 'accent:  %s\n' "${REPOHUE_ACCENT:-<none>}"
      printf 'scope:   %s\n' "${_REPOHUE_SCOPE_DIR:-<any git repo>}"
      printf 'tmux:    %s\n' "$([ -n "$TMUX" ] && echo yes || echo no)"
      printf 'quiet:   %s\n' "${REPOHUE_QUIET:-0}"
      ;;
    light|dark|auto)
      echo "$cmd" > "$_REPOHUE_MODE_FILE"
      _REPOHUE_LAST_KEY=""
      _repohue_theme_apply
      printf 'mode -> %s\n' "$cmd"
      ;;
    toggle)
      case "$(_repohue_mode)" in
        dark) echo light > "$_REPOHUE_MODE_FILE" ;;
        *)    echo dark  > "$_REPOHUE_MODE_FILE" ;;
      esac
      _REPOHUE_LAST_KEY=""
      _repohue_theme_apply
      printf 'mode -> %s\n' "$(cat "$_REPOHUE_MODE_FILE")"
      ;;
    list)
      local list_dir="${1:-${_REPOHUE_SCOPE_DIR:-$HOME/tern-work}}"
      if [ ! -d "$list_dir" ]; then
        echo "no such dir: $list_dir"
        echo "usage: repohue list [dir]   (default: \$REPOHUE_SCOPE_DIR or ~/tern-work)"
        return 1
      fi
      local d name hue
      printf 'scanning: %s\n\n' "$list_dir"
      printf '%-32s %-10s %s\n' REPO HUE INDEX
      for d in "$list_dir"/*/; do
        [ -d "$d/.git" ] || [ -f "$d/.git" ] || continue
        name="$(basename "$d")"
        hue="${_REPOHUE_HUES[$(_repohue_hash_idx "$name")]}"
        if [ -f "$d/.repohue" ]; then
          local ov
          ov="$(head -n1 "$d/.repohue" | awk '{print $1}' | tr '[:upper:]' '[:lower:]')"
          for h in "${_REPOHUE_HUES[@]}"; do
            [ "$h" = "$ov" ] && { hue="$ov*"; break; }
          done
        fi
        printf '%-32s %-10s %s\n' "$name" "$hue" "$(_repohue_hash_idx "$name")"
      done
      printf '\n(* = .repohue override)\n'
      ;;
    preview)
      local target="${1:-}"
      [ -z "$target" ] && { echo "usage: repohue preview <hue|repo-name>"; return 1; }
      local hue="" h
      for h in "${_REPOHUE_HUES[@]}"; do
        [ "$h" = "$target" ] && hue="$h"
      done
      [ -z "$hue" ] && hue="${_REPOHUE_HUES[$(_repohue_hash_idx "$target")]}"
      local mode; mode="$(_repohue_mode)"
      printf 'preview: %s (%s)\n' "$hue" "$mode"
      _repohue_apply_palette "${hue}_${mode}"
      _repohue_set_title "preview: $hue"
      printf '  bg/fg/cursor/accent: %s\n' "${_REPOHUE_PAL[${hue}_${mode}]}"
      printf '  (run "repohue reapply" to restore current repo theme)\n'
      ;;
    reapply|refresh)
      _REPOHUE_LAST_KEY=""
      _repohue_theme_apply
      ;;
    reset)
      _repohue_reset_palette
      _repohue_reset_tmux
      _repohue_set_title "${PWD/#$HOME/~}"
      ;;
    set)
      local target="${1:-}"
      [ -z "$target" ] && { echo "usage: repohue set <hue> (writes .repohue in repo root)"; return 1; }
      local valid="" h
      for h in "${_REPOHUE_HUES[@]}"; do
        [ "$h" = "$target" ] && valid=1
      done
      [ -z "$valid" ] && { echo "unknown hue: $target. valid: ${_REPOHUE_HUES[*]}"; return 1; }
      local root
      root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "not in a git repo"; return 1; }
      echo "$target" > "$root/.repohue"
      _REPOHUE_LAST_KEY=""
      _repohue_theme_apply
      printf 'wrote %s/.repohue = %s\n' "$root" "$target"
      ;;
    unset)
      local root
      root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "not in a git repo"; return 1; }
      [ -f "$root/.repohue" ] && rm -- "$root/.repohue"
      _REPOHUE_LAST_KEY=""
      _repohue_theme_apply
      printf 'removed %s/.repohue\n' "$root"
      ;;
    hues)
      printf '%s\n' "${_REPOHUE_HUES[@]}"
      ;;
    palette|colours|colors)
      _repohue_swatch() {
        local bg="$1" fg="$2" ac="$3" label="$4"
        local r g b fr fg2 fb ar ag ab
        read -r r g b   <<<"$(_repohue_hex_rgb "$bg")"
        read -r fr fg2 fb <<<"$(_repohue_hex_rgb "$fg")"
        read -r ar ag ab <<<"$(_repohue_hex_rgb "$ac")"
        printf '\033[48;2;%d;%d;%dm\033[38;2;%d;%d;%dm ██ ' "$r" "$g" "$b" "$ar" "$ag" "$ab"
        printf '\033[38;2;%d;%d;%dm%-13s' "$fr" "$fg2" "$fb" "$label"
        printf '\033[38;2;%d;%d;%dm ██ \033[0m' "$ar" "$ag" "$ab"
      }
      printf '\n  %-10s %-26s %s\n' '' 'DARK' 'LIGHT'
      local h entry arr
      for h in "${_REPOHUE_HUES[@]}"; do
        printf '  %-10s ' "$h"
        entry="${_REPOHUE_PAL[${h}_dark]}"
        # shellcheck disable=SC2206
        arr=($entry)
        _repohue_swatch "${arr[0]}" "${arr[1]}" "${arr[3]}" "$h dark"
        printf '  '
        entry="${_REPOHUE_PAL[${h}_light]}"
        # shellcheck disable=SC2206
        arr=($entry)
        _repohue_swatch "${arr[0]}" "${arr[1]}" "${arr[3]}" "$h light"
        printf '\n'
      done
      printf '\n  Pin to current repo:  repohue set <hue>\n'
      printf '  Preview live:         repohue preview <hue>\n\n'
      unset -f _repohue_swatch
      ;;
    quiet)
      case "${1:-}" in
        on)  export REPOHUE_QUIET=1; echo "notifications: off" ;;
        off) export REPOHUE_QUIET=0; echo "notifications: on" ;;
        *)   echo "usage: repohue quiet on|off"; return 1 ;;
      esac
      ;;
    prompt-snippet)
      # Print starship.toml + bash PS1 snippets for accent integration.
      cat <<'EOF'
# ---- starship.toml ----
# Paste these into ~/.config/starship.toml. One custom module per hue
# (starship can't read env vars in colour fields, so we branch on $REPOHUE_HUE).

EOF
      local h entry arr accent
      for h in "${_REPOHUE_HUES[@]}"; do
        entry="${_REPOHUE_PAL[${h}_dark]}"
        # shellcheck disable=SC2206
        arr=($entry)
        accent="${arr[3]}"
        cat <<EOF
[custom.repohue_${h}]
when = '''test "\$REPOHUE_HUE" = "${h}"'''
command = "printf %s \"\$REPOHUE_REPO\""
format = "[\$symbol \$output ](fg:${accent} bold) "
symbol = "●"

EOF
      done
      cat <<'EOF'
# ---- bash PS1 (non-starship users) ----
# Paste into ~/rao_bashrc_overrides AFTER sourcing repohue.sh:
#
#   _repohue_ps1_prefix() {
#     [ -z "$REPOHUE_ACCENT" ] && return
#     local r g b; read -r r g b <<<"$(_repohue_hex_rgb "$REPOHUE_ACCENT")"
#     printf '\[\e[38;2;%d;%d;%dm\]● \[\e[0m\]' "$r" "$g" "$b"
#   }
#   PS1='$(_repohue_ps1_prefix)'"$PS1"
EOF
      ;;
    help|-h|--help)
      cat <<'EOF'
repohue — per-repo deterministic terminal colours

  repohue                       Show current state
  repohue list [dir]            List repos in dir + their hues
                                (default: $REPOHUE_SCOPE_DIR or ~/tern-work)
  repohue hues                  List available hue names
  repohue palette               Show all hues as inline swatches (no bg flip)
  repohue preview <hue|repo>    Preview a palette by flipping terminal bg
  repohue reapply               Re-apply current repo theme
  repohue reset                 Reset terminal/tmux to defaults
  repohue set <hue>             Pin .repohue in current repo root
  repohue unset                 Remove .repohue from current repo root
  repohue light|dark|auto       Set mode (auto follows GNOME color-scheme)
  repohue toggle                Flip light/dark
  repohue quiet on|off          Toggle cd notifications
  repohue prompt-snippet        Print starship.toml + bash PS1 snippets

Env exported on each cd:
  REPOHUE_REPO, REPOHUE_HUE, REPOHUE_MODE, REPOHUE_ACCENT

Env knobs (set before sourcing):
  REPOHUE_SCOPE_DIR  Narrow theming to one tree (default: empty = any git repo)
  REPOHUE_QUIET=1    Suppress "→ repohue:" notifications
  REPOHUE_NO_TMUX=1  Skip tmux status-bar tinting
EOF
      ;;
    *)
      echo "unknown subcommand: $cmd (try: repohue help)"
      return 1
      ;;
  esac
}
