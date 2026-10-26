#!/usr/bin/env bash
# Statusline — four-line colored usage display.
# Stdin: JSON session state from Claude Code.
# Format:
#   Dir: ~/projects/my-app
#   Model: Opus 5.5  Session ID: <uuid>
#   Session tokens: 6.0M (in 156 · out 76.4K · cache write 326.2K · cache read 5.6M)
#   Context: 25% | 5h: 75% reset 15:40 (in 4h45m) | 7d: 7% reset Jun 2 17:00 (in 1d6h)

INPUT=$(cat)

# ── Colors (24-bit truecolor, Dracula palette) ─────────────────────────────────────────────────
RST=$'\e[0m'
BOLD=$'\e[1m'
C_LABEL=$'\e[38;2;189;147;249m'   # Dracula purple #BD93F9 labels
C_MODEL=$'\e[38;2;255;121;198m'   # Dracula pink #FF79C6 model name
C_ID=$'\e[38;2;248;248;242m'      # Dracula foreground #F8F8F2 session ID
C_TIME=$'\e[38;2;139;233;253m'    # Dracula cyan #8BE9FD reset times
C_TOTAL=$'\e[38;2;255;121;198m'   # Dracula pink #FF79C6 total tokens
C_DIM=$'\e[38;5;245m'     # gray details
C_SEP=$'\e[38;2;98;114;164m'     # Dracula comment #6272A4 separators
C_OK=$'\e[38;2;80;250;123m'      # Dracula green #50FA7B (< 50%)
C_WARN=$'\e[38;2;241;250;140m'    # Dracula yellow #F1FA8C (50-79%)
C_HIGH=$'\e[38;2;255;85;85m'      # Dracula red #FF5555 (>= 80%)

# Pick color for a usage percentage
pct_color() {
  local p=${1%.*}
  if [ "$p" -ge 80 ]; then printf "%s" "$C_HIGH"
  elif [ "$p" -ge 50 ]; then printf "%s" "$C_WARN"
  else printf "%s" "$C_OK"
  fi
}

# Helper: format countdown from now to a future Unix epoch (no spaces)
# Output examples: 4h45m  1h5m  47m  1d6h  2d0h
format_countdown() {
  local target="$1"
  local now
  now=$(date +%s)
  local diff=$(( target - now ))
  if [ "$diff" -le 0 ]; then
    echo "now"
    return
  fi
  local days=$(( diff / 86400 ))
  local hours=$(( (diff % 86400) / 3600 ))
  local mins=$(( (diff % 3600) / 60 ))
  if [ "$days" -gt 0 ]; then
    printf "%dd%dh" "$days" "$hours"
  elif [ "$hours" -gt 0 ]; then
    printf "%dh%dm" "$hours" "$mins"
  else
    printf "%dm" "$mins"
  fi
}

# Portable date formatting (GNU date vs BSD date)
epoch_to_hhmm() {
  date -d "@$1" "+%H:%M" 2>/dev/null || date -r "$1" "+%H:%M" 2>/dev/null
}
epoch_to_mondd_hhmm() {
  # Produces e.g. "Jun 2 17:00" — strip leading zero from day
  date -d "@$1" "+%b %-d %H:%M" 2>/dev/null || date -r "$1" "+%b %e %H:%M" 2>/dev/null | sed 's/  / /'
}

# ── Line 0: current directory ───────────────────────────────────────────────
CWD=$(echo "$INPUT" | jq -r '.workspace.current_dir // .cwd // empty')
[ -n "$CWD" ] && printf "%sDir:%s %s%s%s\n" "$C_LABEL" "$RST" "$C_TIME" "$CWD" "$RST"

# ── Line 1: model and session ID ────────────────────────────────────────────
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
HEAD=""
[ -n "$MODEL" ] && HEAD="${C_LABEL}Model:${RST} ${BOLD}${C_MODEL}${MODEL}${RST}"
[ -n "$SESSION_ID" ] && HEAD="${HEAD:+${HEAD}  }${C_LABEL}Session ID:${RST} ${C_ID}${SESSION_ID}${RST}"
[ -n "$HEAD" ] && printf "%s\n" "$HEAD"

# ── Context segment ──────────────────────────────────────────────────────────
CTX_PCT=$(echo "$INPUT" | jq -r '.context_window.used_percentage // empty')
SEG_CTX=""
if [ -n "$CTX_PCT" ]; then
  P=$(printf "%.0f" "$CTX_PCT")
  SEG_CTX="${C_LABEL}Context:${RST} $(pct_color "$P")${P}%${RST}"
fi

# ── 5h segment ───────────────────────────────────────────────────────────────
FIVE_H_PCT=$(echo "$INPUT" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_H_RESET=$(echo "$INPUT" | jq -r '.rate_limits.five_hour.resets_at // empty')
SEG_5H=""
if [ -n "$FIVE_H_PCT" ]; then
  PCT1=$(printf "%.0f" "$FIVE_H_PCT")
  SEG_5H="${C_LABEL}5h:${RST} $(pct_color "$PCT1")${PCT1}%${RST}"
  if [ -n "$FIVE_H_RESET" ]; then
    RESET_TIME=$(epoch_to_hhmm "$FIVE_H_RESET")
    COUNTDOWN=$(format_countdown "$FIVE_H_RESET")
    SEG_5H="${SEG_5H} ${C_DIM}reset${RST} ${C_TIME}${RESET_TIME}${RST} ${C_DIM}(in ${COUNTDOWN})${RST}"
  fi
fi

# ── 7d segment ───────────────────────────────────────────────────────────────
SEVEN_D_PCT=$(echo "$INPUT" | jq -r '.rate_limits.seven_day.used_percentage // empty')
SEVEN_D_RESET=$(echo "$INPUT" | jq -r '.rate_limits.seven_day.resets_at // empty')
SEG_7D=""
if [ -n "$SEVEN_D_PCT" ]; then
  PCT2=$(printf "%.0f" "$SEVEN_D_PCT")
  SEG_7D="${C_LABEL}7d:${RST} $(pct_color "$PCT2")${PCT2}%${RST}"
  if [ -n "$SEVEN_D_RESET" ]; then
    RESET_DATE=$(epoch_to_mondd_hhmm "$SEVEN_D_RESET")
    COUNTDOWN2=$(format_countdown "$SEVEN_D_RESET")
    SEG_7D="${SEG_7D} ${C_DIM}reset${RST} ${C_TIME}${RESET_DATE}${RST} ${C_DIM}(in ${COUNTDOWN2})${RST}"
  fi
fi

# ── Line 2: total tokens of this session (including subagents) ─────────────
human() {
  awk -v n="$1" 'BEGIN {
    if (n >= 1e9) printf "%.2fB", n/1e9
    else if (n >= 1e6) printf "%.1fM", n/1e6
    else if (n >= 1e3) printf "%.1fK", n/1e3
    else printf "%d", n
  }'
}
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')
if [ -n "$TRANSCRIPT" ]; then
  PY=$(command -v python || command -v python3)
  read -r TOK_ALL TOK_IN TOK_OUT TOK_CW TOK_CR < <("$PY" "$(dirname "$0")/statusline_tokens.py" "$TRANSCRIPT" 2>/dev/null)
  if [ -n "$TOK_ALL" ]; then
    printf "%sSession tokens:%s %s%s%s%s %s(in %s · out %s · cache write %s · cache read %s)%s\n" \
      "$C_LABEL" "$RST" "$BOLD" "$C_TOTAL" "$(human "$TOK_ALL")" "$RST" \
      "$C_DIM" "$(human "$TOK_IN")" "$(human "$TOK_OUT")" "$(human "$TOK_CW")" "$(human "$TOK_CR")" "$RST"
  fi
fi

# ── Line 3: context and rate limits (pipe-separated, omit empty segments) ──
PARTS=()
[ -n "$SEG_CTX" ] && PARTS+=("$SEG_CTX")
[ -n "$SEG_5H"  ] && PARTS+=("$SEG_5H")
[ -n "$SEG_7D"  ] && PARTS+=("$SEG_7D")

if [ "${#PARTS[@]}" -gt 0 ]; then
  OUT="${PARTS[0]}"
  for seg in "${PARTS[@]:1}"; do
    OUT="${OUT} ${C_SEP}|${RST} ${seg}"
  done
  printf "%s" "$OUT"
fi
