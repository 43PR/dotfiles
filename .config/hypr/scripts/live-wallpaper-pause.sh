#!/usr/bin/env bash
# Pause mpvpaper (SIGSTOP) while any visible workspace has a fullscreen window.
sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

update() {
    local fs
    fs=$(jq -n \
        --argjson mons "$(hyprctl -j monitors)" \
        --argjson wss  "$(hyprctl -j workspaces)" '
        [$mons[].activeWorkspace.id] as $act
        | any($wss[]; .hasfullscreen and ([.id] | inside($act)))')
    if [[ "$fs" == true ]]; then
        pkill -STOP -x mpvpaper
    else
        pkill -CONT -x mpvpaper
    fi
}

update
socat -U - "UNIX-CONNECT:$sock" | while read -r line; do
    case "${line%%>>*}" in
        fullscreen|workspacev2|focusedmonv2|openwindow|closewindow|movewindow|monitoradded|monitorremoved)
            update ;;
    esac
done
