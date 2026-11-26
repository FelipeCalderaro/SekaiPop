#!/bin/sh
# render.sh <plugin dir> <out.png> [mode] [palette] [fixture.js] [wait ms]
# Draws a plugin's widget offscreen (render.qml). Needs Qt 6's `qml` tool (qt6-declarative).
here=$(cd "$(dirname "$0")" && pwd)
QML=/usr/lib/qt6/bin/qml   # Qt 6 (/usr/bin/qml can be Qt 5's)
[ -x "$QML" ] || QML=$(command -v qml6 || command -v qml)
dir=$(cd "$1" && pwd); shift
QT_FORCE_STDERR_LOGGING=1 QML_XHR_ALLOW_FILE_READ=1 QT_QPA_PLATFORM=offscreen exec "$QML" "$here/render.qml" -- "$dir" "$@"
