#!/usr/bin/env bash
#
# awww-resilient.sh — wrapper anti-crash para awww-daemon (awww 0.12.x).
#
# El daemon aborta con pánico Rust (BrokenPipe en daemon/src/main.rs cuando
# un cliente se desconecta a mitad de una escritura). Al morir, el fondo
# queda negro hasta lanzar de nuevo el daemon.
#
# Este wrapper lo relanza y pinta el ultimo wallpaper cada vez que muere.

traylog="$HOME/.cache/awww-resilient.log"
state_file="${XDG_STATE_HOME:-$HOME/.local/state}/43pr/state.json"

log() { echo "[$(date '+%d %b %H:%M:%S')] $*" >> "$traylog" 2>/dev/null; }

restore() {
    img="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("wallpaper",""))' "$state_file" 2>/dev/null)"
    [[ -f "$img" ]] || return 0
    for _ in {1..20}; do
        awww query >/dev/null 2>&1 && break
        sleep 0.25
    done
    awww img "$img" -t none >/dev/null 2>&1
}

while true; do
    awww-daemon 2>>"$traylog"
    rc=$?
    # rc 143/130 = SIGTERM/SIGINT (salida limpia de sesion, no reintentar)
    if [[ $rc -eq 143 || $rc -eq 130 ]]; then
        log "daemon ended cleanly (rc=$rc), exit"
        exit 0
    fi
    log "awww-daemon crashed (rc=$rc), restarting + restoring wallpaper"
    sleep 0.3
    restore &
done
