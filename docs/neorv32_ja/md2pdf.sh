#!/usr/bin/env bash
# Markdown → PDF (pandoc で HTML 化 → ヘッドレス Chrome で印刷)
# 使い方: ./md2pdf.sh 口頭試問対策.md  [出力.pdf]
set -euo pipefail

src="${1:?使い方: $0 input.md [output.pdf]}"
out="${2:-${src%.*}.pdf}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/style.css" <<'CSS'
@page { size: A4; margin: 20mm 18mm; }
body {
  font-family: "Noto Serif CJK JP", "IPAexMincho", serif;
  font-size: 10.5pt; line-height: 1.75; color: #111;
  max-width: none; margin: 0;
}
h1, h2, h3, h4 { font-family: "Noto Sans CJK JP", "IPAexGothic", sans-serif; line-height: 1.4; }
h1 { font-size: 17pt; border-bottom: 2px solid #333; padding-bottom: .3em; }
h2 { font-size: 13.5pt; border-bottom: 1px solid #bbb; padding-bottom: .2em; margin-top: 1.6em; }
h3 { font-size: 11.5pt; margin-top: 1.3em; }
h1, h2, h3, h4 { break-after: avoid; }
p, li, table, pre, blockquote { break-inside: avoid; }
code, pre { font-family: "Noto Sans Mono CJK JP", monospace; font-size: 9pt; }
pre { background: #f6f6f6; padding: .7em .9em; border-radius: 4px; white-space: pre-wrap; }
code { background: #f0f0f0; padding: .1em .3em; border-radius: 3px; }
pre code { background: none; padding: 0; }
table { border-collapse: collapse; width: 100%; font-size: 9.5pt; }
th, td { border: 1px solid #999; padding: .35em .6em; }
th { background: #eee; }
blockquote { border-left: 3px solid #ccc; margin-left: 0; padding-left: 1em; color: #444; }
img { max-width: 100%; }
CSS

pandoc "$src" \
  --standalone --embed-resources \
  --metadata title="$(basename "${src%.*}")" \
  --css "$tmp/style.css" \
  --resource-path="$(dirname "$src")" \
  -f gfm+tex_math_dollars -t html5 \
  --mathml \
  -o "$tmp/page.html"

google-chrome --headless --disable-gpu --no-sandbox \
  --no-pdf-header-footer \
  --print-to-pdf="$(realpath -m "$out")" \
  "file://$tmp/page.html" 2>/dev/null

echo "→ $out"
