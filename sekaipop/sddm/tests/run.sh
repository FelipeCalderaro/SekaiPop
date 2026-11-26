#!/bin/sh
# run.sh: the SDDM theme's checks, no SDDM and no root needed (from anywhere).
#   1. Main.qml parses (qmlformat)
#   2. Palette.js: the lockscreen's formulas (tst_palette.qml, qmltestrunner)
#   3. sddm-theme.sh: install / sync / status / restore against throwaway folders (python)
#   4. the theme drawn with stand-ins for SDDM (render.qml) in four states, failing on any QML
#      error; the PNGs are kept in $OUT to look at
here=$(cd "$(dirname "$0")" && pwd)
top=$(cd "$here/../.." && pwd)
QT=/usr/lib/qt6/bin
OUT=${OUT:-$(mktemp -d "${TMPDIR:-/tmp}/sddm-renders.XXXXXX")}
fails=0; n=0
ok() { n=$((n + 1)); }
bad() { n=$((n + 1)); fails=$((fails + 1)); echo "FAIL $1"; }

"$QT/qmlformat" "$top/sddm/sekaipop/Main.qml" >/dev/null 2>"$OUT/syntax.log" && ok || { bad "Main.qml syntax"; cat "$OUT/syntax.log"; }

QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen "$QT/qmltestrunner" -input "$here/tst_palette.qml" >"$OUT/palette.log" 2>&1 \
    && ok || { bad "palette tests"; grep -A3 FAIL "$OUT/palette.log" | head -20; }

python3 -B "$here/sddm_theme_test.py" >"$OUT/script.log" 2>&1 && ok || { bad "sddm-theme.sh tests"; tail -20 "$OUT/script.log"; }

bg="$OUT/bg.png"
command -v magick >/dev/null && magick -size 1920x1080 gradient:'#8ea3ff'-'#ff96c0' "$bg" 2>/dev/null || bg=""
for v in "vs idle" "vs failed" "vbs 12h" "mono many"; do
    set -- $v
    log="$OUT/render-$1-$2.log"
    QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen "$QT/qml" "$here/render.qml" -- "$OUT/sddm-$1-$2.png" "$1" "$2" "$bg" >"$log" 2>&1
    # the font file only exists in an installed theme; anything else is a real problem
    if [ -s "$OUT/sddm-$1-$2.png" ] && ! grep -v "FontLoader" "$log" | grep -qiE "error|TypeError|ReferenceError|is not a type|cannot assign|unavailable"; then ok
    else bad "draws ($1, $2): see $log"; grep -v FontLoader "$log" | head -5; fi
done

echo "renders and logs: $OUT"
[ "$fails" = 0 ] && echo "all $n passed" || echo "$fails of $n failed"
[ "$fails" = 0 ]
