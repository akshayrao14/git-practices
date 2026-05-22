#!/usr/bin/env bash
# rao-terminal-theme — per-repo deterministic terminal theming
# Detects current git repo (worktree-aware), hashes repo name to a palette,
# emits OSC colour sequences to retheme GNOME Terminal live on cd.
# Light/dark mode respected. .rao-theme in repo root overrides hash pick.

# ---- config ----
_RAO_THEME_DIR="$HOME/.config/rao-terminal-theme"
_RAO_THEME_MODE_FILE="$_RAO_THEME_DIR/mode"     # auto | light | dark
# Scope dir: only theme inside this tree. Override with $RAO_THEME_SCOPE_DIR.
_RAO_THEME_SCOPE_DIR="${RAO_THEME_SCOPE_DIR:-$HOME/tern-work}"
mkdir -p "$_RAO_THEME_DIR"
[ -f "$_RAO_THEME_MODE_FILE" ] || echo auto > "$_RAO_THEME_MODE_FILE"

# Hue keys in fixed order — hash index maps into this list.
_RAO_HUES=(red orange yellow green cyan blue purple magenta)

# Palette: per hue, dark and light variants. Each variant = bg fg cursor accent.
# Format: _RAO_PAL[<hue>_<mode>]="bg fg cursor accent"
declare -gA _RAO_PAL
_RAO_PAL[red_dark]="#2a1414 #e8dada #e06060 #e06060"
_RAO_PAL[red_light]="#fae4e4 #1a1010 #c03030 #c03030"
_RAO_PAL[orange_dark]="#2a1f10 #e8e0d4 #e09060 #e09060"
_RAO_PAL[orange_light]="#faf0e4 #1a1410 #c06030 #c06030"
_RAO_PAL[yellow_dark]="#2a2810 #e8e6d4 #d0c060 #d0c060"
_RAO_PAL[yellow_light]="#fafae4 #1a1a10 #a08030 #a08030"
_RAO_PAL[green_dark]="#142a14 #dae8da #60c060 #60c060"
_RAO_PAL[green_light]="#e4fae4 #101a10 #308030 #308030"
_RAO_PAL[cyan_dark]="#102a2a #d4e6e6 #60c0c0 #60c0c0"
_RAO_PAL[cyan_light]="#e4fafa #101a1a #308080 #308080"
_RAO_PAL[blue_dark]="#14142a #dadae8 #6080e0 #6080e0"
_RAO_PAL[blue_light]="#e4e4fa #10101a #3050b0 #3050b0"
_RAO_PAL[purple_dark]="#1f142a #e0dae8 #9060e0 #9060e0"
_RAO_PAL[purple_light]="#f0e4fa #14101a #6030b0 #6030b0"
_RAO_PAL[magenta_dark]="#2a142a #e8dae8 #e060c0 #e060c0"
_RAO_PAL[magenta_light]="#fae4fa #1a101a #b03090 #b03090"

# ---- helpers ----

# Wrap an escape sequence for tmux passthrough if inside tmux.
_rao_osc() {
  local seq="$1"
  if [ -n "$TMUX" ]; then
    printf '\ePtmux;\e%s\e\\' "$seq"
  else
    printf '%s' "$seq"
  fi
}

# Resolve effective mode: auto -> read gsettings, else literal.
_rao_mode() {
  local m
  m="$(cat "$_RAO_THEME_MODE_FILE" 2>/dev/null)"
  case "$m" in
    light|dark) printf '%s' "$m"; return ;;
  esac
  # auto
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

# Detect current repo name. Echoes name or empty string.
# Worktree-aware: uses git common-dir parent.
_rao_repo_name() {
  case "$PWD/" in
    "$_RAO_THEME_SCOPE_DIR"/*) ;;
    *) return ;;
  esac
  command -v git >/dev/null 2>&1 || return
  local common abs
  common="$(git rev-parse --git-common-dir 2>/dev/null)" || return
  [ -z "$common" ] && return
  # common-dir may be relative; resolve.
  if [ -d "$common" ]; then
    abs="$(cd "$common/.." 2>/dev/null && pwd)" || return
    basename "$abs"
  fi
}

# Deterministic palette index for repo name.
_rao_hash_idx() {
  local name="$1" sum
  sum="$(printf '%s' "$name" | cksum | awk '{print $1}')"
  printf '%s' "$(( sum % ${#_RAO_HUES[@]} ))"
}

# Resolve hue for repo: .rao-theme override > hash.
# Echoes hue name.
_rao_pick_hue() {
  local name="$1"
  local root override hue
  root="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ -n "$root" ] && [ -f "$root/.rao-theme" ]; then
    override="$(head -n1 "$root/.rao-theme" | awk '{print $1}' | tr '[:upper:]' '[:lower:]')"
    for h in "${_RAO_HUES[@]}"; do
      [ "$h" = "$override" ] && { printf '%s' "$h"; return; }
    done
  fi
  local idx
  idx="$(_rao_hash_idx "$name")"
  printf '%s' "${_RAO_HUES[$idx]}"
}

# Apply a palette entry (4 hex values).
_rao_apply_palette() {
  local key="$1"
  local entry="${_RAO_PAL[$key]}"
  [ -z "$entry" ] && return
  # shellcheck disable=SC2206
  local arr=($entry)
  local bg="${arr[0]}" fg="${arr[1]}" cur="${arr[2]}"
  # OSC 10 fg, 11 bg, 12 cursor
  _rao_osc "$(printf '\033]10;%s\007' "$fg")"
  _rao_osc "$(printf '\033]11;%s\007' "$bg")"
  _rao_osc "$(printf '\033]12;%s\007' "$cur")"
}

# Reset to terminal defaults.
_rao_reset_palette() {
  _rao_osc "$(printf '\033]110\007')"
  _rao_osc "$(printf '\033]111\007')"
  _rao_osc "$(printf '\033]112\007')"
}

# Set tab/window title.
_rao_set_title() {
  local title="$1"
  printf '\033]0;%s\007' "$title"
}

# Apply theme for current dir. Called on cd or mode change.
_rao_theme_apply() {
  local name hue mode key branch title
  name="$(_rao_repo_name)"
  if [ -z "$name" ]; then
    _rao_reset_palette
    _rao_set_title "${PWD/#$HOME/~}"
    export RAO_THEME_REPO="" RAO_THEME_HUE="" RAO_THEME_ACCENT=""
    return
  fi
  hue="$(_rao_pick_hue "$name")"
  mode="$(_rao_mode)"
  key="${hue}_${mode}"
  _rao_apply_palette "$key"

  branch="$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)"
  if [ -n "$branch" ]; then
    title="$name ($branch)"
  else
    title="$name"
  fi
  _rao_set_title "$title"

  # Export for downstream tools (PS1, tmux, etc).
  local entry="${_RAO_PAL[$key]}"
  # shellcheck disable=SC2206
  local arr=($entry)
  export RAO_THEME_REPO="$name"
  export RAO_THEME_HUE="$hue"
  export RAO_THEME_MODE="$mode"
  export RAO_THEME_ACCENT="${arr[3]}"
}

# ---- prompt hook ----
_RAO_THEME_LAST_KEY=""
_rao_theme_hook() {
  local key="$PWD|$(cat "$_RAO_THEME_MODE_FILE" 2>/dev/null)"
  if [ "$key" != "$_RAO_THEME_LAST_KEY" ]; then
    _RAO_THEME_LAST_KEY="$key"
    _rao_theme_apply
  fi
}

# Install hook into PROMPT_COMMAND (idempotent).
case ";${PROMPT_COMMAND:-};" in
  *";_rao_theme_hook;"*) ;;
  *) PROMPT_COMMAND="_rao_theme_hook;${PROMPT_COMMAND:-}" ;;
esac

# ---- user-facing CLI ----
rao-theme() {
  local cmd="${1:-status}"; shift 2>/dev/null
  case "$cmd" in
    status|"")
      printf 'repo:    %s\n' "${RAO_THEME_REPO:-<none>}"
      printf 'hue:     %s\n' "${RAO_THEME_HUE:-<none>}"
      printf 'mode:    %s (file: %s)\n' "$(_rao_mode)" "$(cat "$_RAO_THEME_MODE_FILE")"
      printf 'accent:  %s\n' "${RAO_THEME_ACCENT:-<none>}"
      ;;
    light|dark|auto)
      echo "$cmd" > "$_RAO_THEME_MODE_FILE"
      _RAO_THEME_LAST_KEY=""
      _rao_theme_apply
      printf 'mode -> %s\n' "$cmd"
      ;;
    toggle)
      case "$(_rao_mode)" in
        dark) echo light > "$_RAO_THEME_MODE_FILE" ;;
        *)    echo dark  > "$_RAO_THEME_MODE_FILE" ;;
      esac
      _RAO_THEME_LAST_KEY=""
      _rao_theme_apply
      printf 'mode -> %s\n' "$(cat "$_RAO_THEME_MODE_FILE")"
      ;;
    list)
      # Enumerate immediate subdirs of scope dir that are git repos.
      local d name hue
      printf '%-32s %-10s %s\n' REPO HUE INDEX
      for d in "$_RAO_THEME_SCOPE_DIR"/*/; do
        [ -d "$d/.git" ] || [ -f "$d/.git" ] || continue
        name="$(basename "$d")"
        hue="${_RAO_HUES[$(_rao_hash_idx "$name")]}"
        # Honour .rao-theme override.
        if [ -f "$d/.rao-theme" ]; then
          local ov
          ov="$(head -n1 "$d/.rao-theme" | awk '{print $1}' | tr '[:upper:]' '[:lower:]')"
          for h in "${_RAO_HUES[@]}"; do
            [ "$h" = "$ov" ] && { hue="$ov*"; break; }
          done
        fi
        printf '%-32s %-10s %s\n' "$name" "$hue" "$(_rao_hash_idx "$name")"
      done
      printf '\n(* = .rao-theme override)\n'
      ;;
    preview)
      local target="${1:-}"
      [ -z "$target" ] && { echo "usage: rao-theme preview <hue|repo-name>"; return 1; }
      local hue="" h
      for h in "${_RAO_HUES[@]}"; do
        [ "$h" = "$target" ] && hue="$h"
      done
      if [ -z "$hue" ]; then
        hue="${_RAO_HUES[$(_rao_hash_idx "$target")]}"
      fi
      local mode; mode="$(_rao_mode)"
      printf 'preview: %s (%s)\n' "$hue" "$mode"
      _rao_apply_palette "${hue}_${mode}"
      _rao_set_title "preview: $hue"
      printf '  bg/fg/cursor/accent: %s\n' "${_RAO_PAL[${hue}_${mode}]}"
      printf '  (run "rao-theme reapply" to restore current repo theme)\n'
      ;;
    reapply|refresh)
      _RAO_THEME_LAST_KEY=""
      _rao_theme_apply
      ;;
    reset)
      _rao_reset_palette
      _rao_set_title "${PWD/#$HOME/~}"
      ;;
    set)
      local target="${1:-}"
      [ -z "$target" ] && { echo "usage: rao-theme set <hue> (writes .rao-theme in repo root)"; return 1; }
      local valid="" h
      for h in "${_RAO_HUES[@]}"; do
        [ "$h" = "$target" ] && valid=1
      done
      [ -z "$valid" ] && { echo "unknown hue: $target. valid: ${_RAO_HUES[*]}"; return 1; }
      local root
      root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "not in a git repo"; return 1; }
      echo "$target" > "$root/.rao-theme"
      _RAO_THEME_LAST_KEY=""
      _rao_theme_apply
      printf 'wrote %s/.rao-theme = %s\n' "$root" "$target"
      ;;
    unset)
      local root
      root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "not in a git repo"; return 1; }
      [ -f "$root/.rao-theme" ] && rm -- "$root/.rao-theme"
      _RAO_THEME_LAST_KEY=""
      _rao_theme_apply
      printf 'removed %s/.rao-theme\n' "$root"
      ;;
    hues)
      printf '%s\n' "${_RAO_HUES[@]}"
      ;;
    palette|colours|colors)
      # Render all hues with dark + light variants inline via ANSI 24-bit colour.
      # Does NOT flip the actual terminal bg.
      _rao_hex_rgb() {
        local hex="${1#\#}"
        printf '%d %d %d' "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
      }
      _rao_swatch() {
        # args: bg fg accent label
        local bg="$1" fg="$2" ac="$3" label="$4"
        local r g b fr fg2 fb ar ag ab
        read -r r g b   <<<"$(_rao_hex_rgb "$bg")"
        read -r fr fg2 fb <<<"$(_rao_hex_rgb "$fg")"
        read -r ar ag ab <<<"$(_rao_hex_rgb "$ac")"
        printf '\033[48;2;%d;%d;%dm\033[38;2;%d;%d;%dm ██ ' "$r" "$g" "$b" "$ar" "$ag" "$ab"
        printf '\033[38;2;%d;%d;%dm%-13s' "$fr" "$fg2" "$fb" "$label"
        printf '\033[38;2;%d;%d;%dm ██ \033[0m' "$ar" "$ag" "$ab"
      }
      printf '\n  %-10s %-26s %s\n' '' 'DARK' 'LIGHT'
      local h entry arr
      for h in "${_RAO_HUES[@]}"; do
        printf '  %-10s ' "$h"
        entry="${_RAO_PAL[${h}_dark]}"
        # shellcheck disable=SC2206
        arr=($entry)
        _rao_swatch "${arr[0]}" "${arr[1]}" "${arr[3]}" "$h dark"
        printf '  '
        entry="${_RAO_PAL[${h}_light]}"
        # shellcheck disable=SC2206
        arr=($entry)
        _rao_swatch "${arr[0]}" "${arr[1]}" "${arr[3]}" "$h light"
        printf '\n'
      done
      printf '\n  Pin to current repo:  rao-theme set <hue>\n'
      printf '  Preview live:         rao-theme preview <hue>\n\n'
      unset -f _rao_hex_rgb _rao_swatch
      ;;
    help|-h|--help)
      cat <<'EOF'
rao-theme — per-repo terminal theme control

  rao-theme                    Show current theme state
  rao-theme list               List repos and their assigned hues
  rao-theme hues               List available hue names
  rao-theme palette            Show all hues with colour swatches (no bg flip)
  rao-theme preview <hue|repo> Preview a palette by flipping terminal bg
  rao-theme reapply            Re-apply current repo theme
  rao-theme reset              Reset to terminal default colours
  rao-theme set <hue>          Pin .rao-theme in current repo root
  rao-theme unset              Remove .rao-theme from current repo root
  rao-theme light|dark|auto    Set mode (auto follows GNOME color-scheme)
  rao-theme toggle             Flip light/dark

Env exported on each cd: RAO_THEME_REPO, RAO_THEME_HUE, RAO_THEME_MODE, RAO_THEME_ACCENT
EOF
      ;;
    *)
      echo "unknown subcommand: $cmd (try: rao-theme help)"
      return 1
      ;;
  esac
}
