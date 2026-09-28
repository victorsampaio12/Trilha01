# Trilha 01 — Onboarding · Pacote de produção

13 aulas, 78 páginas do PDF, ~26 min de narração no total.

aula-XX/
  slides/slide-N.png   ← já em 1920x1080
  roteiro/slide-N.txt  ← texto para colar no TTS
  audios/              ← salve aqui slide-N.mp3 (mesmo N do .txt)

## Fluxo
1. Leia PENDENCIAS.md e resolva o que der.
2. Gere só o áudio da aula-01 (6 arquivos) e rode: ./gerar-aula.sh aula-01
3. Aprovou voz e ritmo? Gere o resto, sempre com a mesma voz e as mesmas configurações.
4. ./gerar-aula.sh todas  → cada aula ganha video/Aula_Final.mp4

Corrigiu slides? Reexporte o PDF e rode ./separar-slides.sh arquivo.pdf (os áudios continuam válidos).
Pausa entre slides: PAUSA=0.8 ./gerar-aula.sh aula-01 (padrão 0.6 s).
Requisitos: ffmpeg e poppler-utils (sudo apt install ffmpeg poppler-utils).
