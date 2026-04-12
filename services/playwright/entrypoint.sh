#!/bin/bash
set -e

# Start Xvfb (virtual display)
Xvfb :99 -screen 0 1920x1080x24 &
export DISPLAY=:99

# Start fluxbox (minimal window manager)
fluxbox &

# Start VNC server
x11vnc -display :99 -forever -nopw -shared -rfbport 5900 &

# Start noVNC (web-based VNC client)
websockify --web /usr/share/novnc/ 6080 localhost:5900 &

echo "noVNC available at http://localhost:6080"

# Start the API server
exec node src/server.js
