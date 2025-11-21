#!/bin/bash
# Screen recording script for Sway with notifications

PIDFILE="/tmp/wf-recorder.pid"
VIDEODIR="$HOME/Videos"
mkdir -p "$VIDEODIR"

if [ -f "$PIDFILE" ]; then
    # Recording is running, stop it
    PID=$(cat "$PIDFILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        kill -INT "$PID"
        rm "$PIDFILE"
        notify-send -u normal "Recording Stopped" "Video saved to $VIDEODIR"
    else
        rm "$PIDFILE"
        notify-send -u critical "Recording Error" "No recording process found"
    fi
else
    # Start new recording
    GEOMETRY=$(slurp)
    if [ -n "$GEOMETRY" ]; then
        FILENAME="$VIDEODIR/recording-$(date +%Y%m%d-%H%M%S).mp4"
        wf-recorder -g "$GEOMETRY" -f "$FILENAME" &
        echo $! > "$PIDFILE"
        notify-send -u normal "Recording Started" "Press Mod+Shift+R to stop"
    else
        notify-send -u critical "Recording Cancelled" "No area selected"
    fi
fi
