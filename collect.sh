#!/bin/sh
# Emits tab-separated lines, both optional:
# R  APPID  PERCENT  DONE  COUNT  AGE_S  NAME   Steam background shader replay
# C  TICKS  HZ  THREADS                         CPU ticks of DXVK compiler threads

STEAM="$HOME/.local/share/Steam"
LOG="$STEAM/logs/shader_log.txt"
TAB=$(printf '\t')

game_name() {
  awk -F'"' '/"path"/{print $4}' "$STEAM/steamapps/libraryfolders.vdf" 2>/dev/null |
    while IFS= read -r lib; do
      m="$lib/steamapps/appmanifest_$1.acf"
      [ -f "$m" ] && awk -F'"' '/"name"/{print $4; exit}' "$m" && break
    done
}

if pgrep -f 'ubuntu12_64/fossilize_replay' >/dev/null && [ -f "$LOG" ]; then
  # [2026-10-25 12:40:44] Still replaying 2357570 (33%, 10682/2623845).
  line=$(tail -n 50 "$LOG" | grep 'Still replaying' | tail -1)
  fields=$(printf '%s\n' "$line" | sed -n 's/^\[\([^]]*\)\] Still replaying \([0-9]*\) (\([0-9]*\)%, \([0-9]*\)\/\([0-9]*\)).*/\1\t\2\t\3\t\4\t\5/p')
  if [ -n "$fields" ]; then
    IFS="$TAB" read -r ts app pct done count <<END
$fields
END
    age=$(( $(date +%s) - $(date -d "$ts" +%s) ))
    name=$(game_name "$app")
    printf 'R\t%s\t%s\t%s\t%s\t%s\t%s\n' "$app" "$pct" "$done" "$count" "$age" "${name:-App $app}"
  fi
fi

# Fields 14 and 15 of stat are utime and stime; stripping "pid (comm) " shifts them to 12 and 13.
grep -s -l '^dxvk-shader' /proc/[0-9]*/task/*/comm | sed 's/comm$/stat/' |
  xargs -r awk '{ sub(/^.*\) /, ""); t += $12 + $13; n++ } END { if (n) printf "C\t%d\t%d\t%d\n", t, hz, n }' hz="$(getconf CLK_TCK)" 2>/dev/null
