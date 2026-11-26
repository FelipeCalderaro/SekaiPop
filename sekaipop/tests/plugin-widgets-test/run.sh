#!/bin/sh
# run.sh [plugin id ...]: the checks for the bundled widget plugins (plugins/*), no shell needed.
#   0. every QML file parses (qmlformat)
#   1. plugin.json is valid and says what the shell requires (id = folder, api 1, name, version)
#   2. the kit copy (plugins/<id>/kit) is the same as examples/plugin-kit
#   3. the plugin's own tests: plugins/<id>/tests/tst_*.qml with qmltestrunner
#   4. Widget.qml draws in light, dark and darker without a QML error (render.qml), and the PNGs
#      are kept in $OUT (default: a temporary folder) to look at
# Needs qt6-declarative's qml and qmltestrunner, and python3.
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
QT=/usr/lib/qt6/bin
QMLTR=$QT/qmltestrunner   # Qt 6 (/usr/bin/qmltestrunner can be Qt 5's)
[ -x "$QMLTR" ] || QMLTR=$(command -v qmltestrunner6 || command -v qmltestrunner)
OUT=${OUT:-$(mktemp -d "${TMPDIR:-/tmp}/plugin-renders.XXXXXX")}
fails=0; n=0
ok() { n=$((n + 1)); }
bad() { n=$((n + 1)); fails=$((fails + 1)); echo "FAIL $1"; }

ids="$*"
[ -n "$ids" ] || ids=$(for d in "$root"/plugins/*/; do [ -f "$d/Widget.qml" ] && basename "$d"; done)

for id in $ids; do
    d="$root/plugins/$id"
    echo "== $id"
    if python3 -I - "$d" <<'PY'
import json, os, re, sys
d = sys.argv[1]
m = json.load(open(os.path.join(d, "plugin.json"), encoding="utf-8"))
assert m["id"] == os.path.basename(d.rstrip("/")), "id must be the folder's name"
assert re.fullmatch(r"[a-z0-9-]{1,40}", m["id"])
assert m["api"] == 1 and m["name"] and isinstance(m["version"], str)
for k, v in m.get("settings", {}).items():
    assert isinstance(v, (str, int, float, bool)), k
for k, info in m.get("settingsInfo", {}).items():
    assert k in m.get("settings", {}), "settingsInfo for an undeclared setting: " + k
    if "choices" in info:
        vals = [c["value"] if isinstance(c, dict) else c for c in info["choices"]]
        assert m["settings"][k] in vals, "default of %s is not one of its choices" % k
PY
    then ok; else bad "$id: plugin.json"; fi

    # every QML file parses (Service.qml can't be drawn here: it needs Quickshell's runtime)
    synt=1
    for f in "$d"/*.qml; do
        "$QT/qmlformat" "$f" >/dev/null 2>"$OUT/$id-syntax.log" || { synt=0; echo "  $(basename "$f"):"; head -3 "$OUT/$id-syntax.log"; }
    done
    [ "$synt" = 1 ] && ok || bad "$id: QML syntax"

    if [ -d "$d/kit" ]; then
        same=1
        for f in "$root"/examples/plugin-kit/*.qml; do cmp -s "$f" "$d/kit/$(basename "$f")" || same=0; done
        [ "$same" = 1 ] && ok || bad "$id: kit/ differs from examples/plugin-kit (run examples/plugin-kit/sync.sh)"
    fi

    if ls "$d"/tests/tst_*.qml >/dev/null 2>&1; then
        if QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen "$QMLTR" -input "$d/tests" >"$OUT/$id-tests.log" 2>&1; then ok
        else bad "$id: unit tests (see $OUT/$id-tests.log)"; sed -n '/FAIL/,+3p' "$OUT/$id-tests.log" | head -20; fi
    fi

    fx="$here/fixtures/$id.js"; [ -f "$fx" ] || fx=""
    for mode in light dark darker; do
        log="$OUT/$id-$mode.log"
        sh "$here/render.sh" "$d" "$OUT/$id-$mode.png" "$mode" vs "$fx" >"$log" 2>&1
        if [ -s "$OUT/$id-$mode.png" ] && ! grep -qiE "error|TypeError|ReferenceError|is not a type|cannot assign|unavailable" "$log"; then ok
        else bad "$id: draws in $mode (see $log)"; head -5 "$log"; fi
    done
done

# all of them through the shell's own manifest rules and Settings form (tst_manifests.qml)
echo "== manifests (the shell's PluginManifest.js / PluginForm.js)"
if QML_XHR_ALLOW_FILE_READ=1 QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen "$QMLTR" -input "$here/tst_manifests.qml" >"$OUT/manifests.log" 2>&1; then ok
else bad "manifests (see $OUT/manifests.log)"; grep -A3 FAIL "$OUT/manifests.log" | head -20; fi

echo "renders and logs: $OUT"
[ "$fails" = 0 ] && echo "all $n passed" || echo "$fails of $n failed"
[ "$fails" = 0 ]
