#!/bin/sh
# sync.sh: copy the plugin kit (Block, Key, Icon, Sticker, Tag) into every bundled plugin that has a
# kit/ folder. A plugin can't import another plugin's files (each is installed on its own), so each
# carries a copy; tests/plugin-widgets-test checks the copies match this folder.
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
for k in "$root"/plugins/*/kit; do
    [ -d "$k" ] || continue
    cp "$here"/*.qml "$k"/
    echo "kit -> ${k#$root/}"
done
