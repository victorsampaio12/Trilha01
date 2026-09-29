#!/usr/bin/env bash
# Uso: ./gerar-aula.sh aula-01        (ou ./gerar-aula.sh todas)
# Espera: aula-XX/slides/slide-N.png e aula-XX/audios/slide-N.mp3
export LC_ALL=C
# Gera:   aula-XX/video/Aula_Final.mp4 (1920x1080, H.264 + AAC)
set -euo pipefail
PAUSA="${PAUSA:-0.6}"   # silêncio (s) no fim de cada slide, para a troca não ficar abrupta
FPS=30

for t in ffmpeg ffprobe; do
  command -v "$t" >/dev/null || { echo "ERRO: instale o ffmpeg (sudo apt install ffmpeg)"; exit 1; }
done

gerar() {
  local AULA="${1%/}"
  echo "=== $AULA ==="
  [[ -d "$AULA/slides" && -d "$AULA/audios" ]] || { echo "ERRO: $AULA precisa de slides/ e audios/"; return 1; }

  # 1-3. Descobre os slides em ordem numérica e confere os pares PNG <-> MP3
  mapfile -t NUMS < <(ls "$AULA/slides" | sed -n 's/^slide-\([0-9]\+\)\.png$/\1/p' | sort -n)
  local N=${#NUMS[@]}
  (( N > 0 )) || { echo "ERRO: nenhum slide-N.png em $AULA/slides"; return 1; }
  local ERROS=0
  for ((k=1; k<=N; k++)); do
    [[ -f "$AULA/slides/slide-$k.png" ]] || { echo "ERRO: falta slides/slide-$k.png (numeração com buraco)"; ERROS=1; }
    [[ -s "$AULA/audios/slide-$k.mp3" ]] || { echo "ERRO: falta ou está vazio audios/slide-$k.mp3"; ERROS=1; }
  done
  for f in "$AULA"/audios/slide-*.mp3; do
    [[ -e "$f" ]] || continue
    local n; n=$(basename "$f" .mp3); n=${n#slide-}
    [[ -f "$AULA/slides/slide-$n.png" ]] || { echo "ERRO: áudio sem slide: $f"; ERROS=1; }
  done
  (( ERROS == 0 )) || return 1

  # 4. Um MP4 por slide, com a duração exata do áudio + pausa
  mkdir -p "$AULA/video"; rm -f "$AULA"/video/slide-*.mp4
  : > "$AULA/video/list.txt"
  local TOTAL=0
  for ((k=1; k<=N; k++)); do
    local DUR
    DUR=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$AULA/audios/slide-$k.mp3")
    [[ -n "$DUR" ]] && awk "BEGIN{exit !($DUR>0.3)}" || { echo "ERRO: áudio inválido ou curto demais: slide-$k.mp3"; return 1; }
    local LEN; LEN=$(awk "BEGIN{printf \"%.3f\", $DUR+$PAUSA}")
    ffmpeg -nostdin -loglevel error -y \
      -loop 1 -framerate $FPS -i "$AULA/slides/slide-$k.png" \
      -i "$AULA/audios/slide-$k.mp3" \
      -filter_complex "[0:v]scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=white,setsar=1,format=yuv420p[v];[1:a]aresample=48000,apad[a]" \
      -map "[v]" -map "[a]" -t "$LEN" -r $FPS \
      -c:v libx264 -preset medium -tune stillimage -crf 20 \
      -c:a aac -b:a 192k -ar 48000 -ac 2 \
      "$AULA/video/slide-$k.mp4"
    [[ -s "$AULA/video/slide-$k.mp4" ]] || { echo "ERRO: slide-$k.mp4 não foi gerado"; return 1; }
    echo "file 'slide-$k.mp4'" >> "$AULA/video/list.txt"
    TOTAL=$(awk "BEGIN{print $TOTAL+$LEN}")
    printf "  slide-%d  %.1fs\n" "$k" "$LEN"
  done

  # 5-6. Junta tudo (mesmos parâmetros em todos os trechos, então -c copy é seguro)
  ffmpeg -nostdin -loglevel error -y -f concat -safe 0 -i "$AULA/video/list.txt" \
    -c copy -movflags +faststart "$AULA/video/Aula_Final.mp4"

  # 7. Validação
  local F="$AULA/video/Aula_Final.mp4"
  [[ -s "$F" ]] || { echo "ERRO: vídeo final não foi criado"; return 1; }
  local RES AUD DURF
  RES=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$F")
  AUD=$(ffprobe -v error -select_streams a -show_entries stream=codec_name -of csv=p=0 "$F")
  DURF=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$F")
  [[ "$RES" == "1920x1080" ]] || { echo "ERRO: resolução $RES"; return 1; }
  [[ -n "$AUD" ]] || { echo "ERRO: vídeo final sem áudio"; return 1; }
  awk "BEGIN{d=$DURF-$TOTAL; if(d<0)d=-d; exit !(d<1.5)}" || { echo "ERRO: duração $DURF s difere do esperado $TOTAL s"; return 1; }
  printf "OK: %s  |  %s  |  %.0f s  |  %s\n\n" "$F" "$RES" "$DURF" "$(du -h "$F" | cut -f1)"
}

cd "$(dirname "$0")"
if [[ "${1:-}" == "todas" ]]; then
  for d in aula-*/; do gerar "$d"; done
else
  gerar "${1:?Uso: ./gerar-aula.sh aula-01 | todas}"
fi
