#!/usr/bin/env bash
# Uso: ./separar-slides.sh Slide_Trilha_1_Onboarding.pdf
# Lê aulas.txt (aula|titulo|paginas do PDF) e gera aula-XX/slides/slide-N.png em 1920x1080.
# Rode de novo sempre que corrigir os slides e reexportar o PDF. Os áudios não são afetados.
set -euo pipefail
PDF="${1:?Informe o PDF da trilha}"
MAPA="$(dirname "$0")/aulas.txt"
command -v pdftoppm >/dev/null || { echo "ERRO: instale poppler-utils (sudo apt install poppler-utils)"; exit 1; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

while IFS='|' read -r AULA TITULO PAGINAS; do
  [[ -z "$AULA" || "$AULA" == \#* ]] && continue
  mkdir -p "$AULA/slides" "$AULA/audios"
  rm -f "$AULA"/slides/slide-*.png
  i=1
  for P in $PAGINAS; do
    # -singlefile evita o preenchimento com zeros do pdftoppm (p-01, p-001...)
    pdftoppm -png -singlefile -scale-to-x 1920 -scale-to-y 1080 -f "$P" -l "$P" "$PDF" "$TMP/pg"
    mv "$TMP/pg.png" "$AULA/slides/slide-$i.png"
    i=$((i+1))
  done
  echo "$AULA ($TITULO): $((i-1)) slides"
done < "$MAPA"
