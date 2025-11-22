#!/usr/bin/env bash
# ============================================================
#  MonitorForgeX
#  Xrandr monitor auto-arranger + Xresources exporter
#  Developed by X Project
# ============================================================

set -Eeuo pipefail
IFS=$'\n\t'

# -------------------------------
# Flags
# -------------------------------
DRY_RUN=0
SILENT=0

log() { ((SILENT)) || printf '%s\n' "$*"; }
err() { printf '%s\n' "$*" >&2; }

run() {
  if (( DRY_RUN )); then
    log "DRY: $*"
  else
    eval "$@"
  fi
}

need_cmd() {
  command -v "$1" &>/dev/null || {
    err "ERROR: Missing dependency: $1"
    exit 1
  }
}

usage() {
  cat <<'EOF'
MonitorForgeX - Developed by X Project

Usage:
  monitorforgex.sh [flags] [command] [args]

Flags:
  --dry-run      Print what would be executed, do not change anything
  --silent       No normal output, only errors

Commands:
  arrange                 Detect, order, and arrange monitors; export to Xresources (default)
  list                    Print connected monitor names
  rotate MON DIR          Rotate monitor MON to DIR: left|right|normal|inverted
  set-primary MON         Make MON primary and refresh exports
  export-only             Refresh Xresources exports without changing layout
  help                    Show this help

Examples:
  ./monitorforgex.sh
  ./monitorforgex.sh list
  ./monitorforgex.sh rotate HDMI-1 left
  ./monitorforgex.sh set-primary DP-1
  ./monitorforgex.sh --dry-run arrange
EOF
}

# -------------------------------
# Detect monitors
# -------------------------------
get_connected_monitors() {
  xrandr --query | awk '$2=="connected"{print $1}'
}

get_primary_monitor_xrandr() {
  xrandr --query | awk '$2=="connected" && $0 ~ / primary / {print $1; exit}'
}

get_primary_monitor_xresources() {
  [[ -f "${HOME}/.Xresources" ]] || return 0
  awk -F': ' '$1=="i3wm.primary_monitor"{print $2; exit}' "${HOME}/.Xresources" 2>/dev/null || true
}

get_resolution() {
  local mon="$1"
  xrandr --query | awk -v m="$mon" '
    $1==m && $2=="connected" {
      for(i=1;i<=NF;i++){
        if($i ~ /^[0-9]+x[0-9]+\+/){
          split($i,a,"+"); print a[1]; exit
        }
      }
    }
  '
}

# priority rule for stable ordering
order_key() {
  local m="$1"
  case "$m" in
    eDP*|LVDS*) echo "10" ;;              # internal laptop panel
    DP*|DisplayPort*) echo "20" ;;
    HDMI*) echo "30" ;;
    DVI*) echo "40" ;;
    VGA*) echo "50" ;;
    TV*) echo "60" ;;
    *) echo "90" ;;
  esac
}

sort_monitors() {
  local mons=("$@")
  local tmp=()
  local m k
  for m in "${mons[@]}"; do
    k="$(order_key "$m")"
    tmp+=("${k}:::${m}")
  done

  printf '%s\n' "${tmp[@]}" \
    | sort -n -t':' -k1,1 \
    | awk -F':::' '{print $2}'
}

# -------------------------------
# Xresources handling
# -------------------------------
XR_FILE="${HOME}/.Xresources"

ensure_xresources() {
  [[ -f "$XR_FILE" ]] || touch "$XR_FILE"
}

clear_xresources_keys() {
  ensure_xresources
  # remove old i3wm monitor keys
  sed -i -E '/^i3wm\.(primary_monitor|other_monitor_[0-9]+)(_[a-z]+)?:/Id' "$XR_FILE"
}

write_xrec() {
  local key="$1"
  local mon="$2"
  local res resx resy

  res="$(get_resolution "$mon" || true)"
  if [[ -n "$res" ]]; then
    resx="${res%x*}"
    resy="${res#*x}"
  fi

  local lines=()
  lines+=("i3wm.${key}: ${mon}")
  if [[ -n "${resx:-}" && -n "${resy:-}" ]]; then
    lines+=("i3wm.${key}_resx: ${resx}")
    lines+=("i3wm.${key}_resy: ${resy}")
  fi

  log "$(printf '%s\n' "${lines[@]}")"
  if (( !DRY_RUN )); then
    printf '%s\n' "${lines[@]}" >> "$XR_FILE"
    printf '\n' >> "$XR_FILE"
  fi
}

load_xresources() {
  need_cmd xrdb
  run "xrdb \"$XR_FILE\""
}

refresh_wallpaper() {
  local wp="${HOME}/bin/xwallpaperauto.sh"
  if [[ -x "$wp" ]]; then
    run "\"$wp\" --silent"
  fi
}

# -------------------------------
# Actions
# -------------------------------
arrange_monitors() {
  need_cmd xrandr
  need_cmd awk
  need_cmd sed
  need_cmd sort

  local mons=()
  mapfile -t mons < <(get_connected_monitors)

  [[ "${#mons[@]}" -gt 0 ]] || { err "ERROR: No connected monitors found"; exit 1; }

  local primary=""
  primary="$(get_primary_monitor_xrandr || true)"
  [[ -n "$primary" ]] || primary="$(get_primary_monitor_xresources || true)"
  [[ -n "$primary" ]] || primary="${mons[0]}"

  local sorted=()
  mapfile -t sorted < <(sort_monitors "${mons[@]}")

  log "Detected monitors: ${sorted[*]}"
  log "Primary monitor: $primary"

  clear_xresources_keys

  local prev=""
  local idx=0
  local m

  for m in "${sorted[@]}"; do
    if [[ -z "$prev" ]]; then
      run "xrandr --output \"$m\" --auto"
    else
      run "xrandr --output \"$m\" --auto --right-of \"$prev\""
    fi

    if [[ "$m" == "$primary" ]]; then
      run "xrandr --output \"$m\" --primary"
      write_xrec "primary_monitor" "$m"
    else
      idx=$((idx+1))
      write_xrec "other_monitor_${idx}" "$m"
    fi

    prev="$m"
  done

  load_xresources
  refresh_wallpaper
}

export_only() {
  need_cmd xrandr
  ensure_xresources

  local mons=()
  mapfile -t mons < <(get_connected_monitors)
  [[ "${#mons[@]}" -gt 0 ]] || { err "ERROR: No connected monitors found"; exit 1; }

  local primary=""
  primary="$(get_primary_monitor_xrandr || true)"
  [[ -n "$primary" ]] || primary="$(get_primary_monitor_xresources || true)"
  [[ -n "$primary" ]] || primary="${mons[0]}"

  local sorted=()
  mapfile -t sorted < <(sort_monitors "${mons[@]}")

  clear_xresources_keys

  local idx=0
  local m
  for m in "${sorted[@]}"; do
    if [[ "$m" == "$primary" ]]; then
      write_xrec "primary_monitor" "$m"
    else
      idx=$((idx+1))
      write_xrec "other_monitor_${idx}" "$m"
    fi
  done

  load_xresources
}

rotate_monitor() {
  need_cmd xrandr
  local mon="${1:-}"
  local dir="${2:-left}"

  [[ -n "$mon" ]] || { err "ERROR: rotate requires MON"; exit 1; }

  case "${dir,,}" in
    left|right|normal|inverted) ;;
    *) err "ERROR: DIR must be left|right|normal|inverted"; exit 1 ;;
  esac

  # detect current rotation
  local current=""
  current="$(xrandr --query | awk -v m="$mon" '
    $1==m {
      for(i=1;i<=NF;i++){
        if($i=="left"||$i=="right"||$i=="normal"||$i=="inverted"){
          print $i; exit
        }
      }
    }
  ')"

  local new="$dir"
  if [[ "$current" == "$dir" ]]; then
    new="normal"
  fi

  log "Rotate $mon: $current -> $new"
  run "xrandr --output \"$mon\" --rotate \"$new\""

  export_only
  refresh_wallpaper
}

set_primary() {
  need_cmd xrandr
  local mon="${1:-}"
  [[ -n "$mon" ]] || { err "ERROR: set-primary requires MON"; exit 1; }

  run "xrandr --output \"$mon\" --primary"
  export_only
}

list_monitors() {
  get_connected_monitors
}

# -------------------------------
# Parse flags + dispatch
# -------------------------------
args=()
for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    --silent) SILENT=1 ;;
    -h|--help) usage; exit 0 ;;
    *) args+=("$a") ;;
  esac
done

cmd="${args[0]:-arrange}"
case "${cmd,,}" in
  arrange) arrange_monitors ;;
  list|get) list_monitors ;;
  rotate) rotate_monitor "${args[1]:-}" "${args[2]:-left}" ;;
  set-primary) set_primary "${args[1]:-}" ;;
  export-only) export_only ;;
  help) usage ;;
  *) err "ERROR: Unknown command: $cmd"; usage; exit 1 ;;
esac
