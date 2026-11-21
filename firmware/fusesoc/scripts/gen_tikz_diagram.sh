#!/bin/bash
# Compile a hand-drawn TikZ block diagram (../docs/block-diagrams/tikz/*.tex)
# to a tightly-cropped SVG under ../docs/block-diagrams/.
#
# Usage: gen_tikz_diagram.sh NAME
#   e.g. gen_tikz_diagram.sh sg_v6
#        reads  ../docs/block-diagrams/tikz/sg_v6.tex
#        writes ../docs/block-diagrams/sg_v6.svg
#
# Works for both `standalone`-class sources (already tightly cropped --
# the gs crop step below is then a no-op) and older `article`-class ones
# (e.g. firmware-overview.tex, which needs the crop).
set -euo pipefail

name="$1"
srcdir="../docs/block-diagrams/tikz"
outdir="../docs/block-diagrams"
tex="$srcdir/$name.tex"

if [ ! -f "$tex" ]; then
    echo "error: $tex not found" >&2
    exit 1
fi

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

cp "$tex" "$workdir/$name.tex"
( cd "$workdir" && pdflatex -interaction=nonstopmode "$name.tex" >pdflatex.log 2>&1 ) \
    || { echo "error: pdflatex failed, see log:"; cat "$workdir/pdflatex.log"; exit 1; }

bbox=$(gs -dBATCH -dNOPAUSE -sDEVICE=bbox "$workdir/$name.pdf" 2>&1 \
    | grep HiResBoundingBox | awk '{print $2, $3, $4, $5}')
read -r x0 y0 x1 y1 <<<"$bbox"
width=$(echo "$x1 - $x0" | bc)
height=$(echo "$y1 - $y0" | bc)

gs -o "$workdir/${name}_cropped.pdf" -sDEVICE=pdfwrite \
   -dDEVICEWIDTHPOINTS="$width" -dDEVICEHEIGHTPOINTS="$height" -dFIXEDMEDIA \
   -c "<< /PageOffset [-$x0 -$y0] >> setpagedevice" -f "$workdir/$name.pdf" \
   >/dev/null 2>&1

mkdir -p "$outdir"
pdftocairo -svg "$workdir/${name}_cropped.pdf" "$outdir/$name.svg"
echo "wrote $outdir/$name.svg"
