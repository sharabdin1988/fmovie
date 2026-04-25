#!/bin/bash

# --- Настройки ---
JACKETT_URL="https://jac-red.ru"
API_KEY="00000000000000000000000000000000"
TORRSERVER_URL="http://localhost:8090"
HISTORY_FILE="$HOME/.cache/movie-cli-last"

mkdir -p "$(dirname "$HISTORY_FILE")"

# Функция запуска mpv с сохранением позиции
play_video() {
    local URL="$1"
    local TITLE="$2"
    # --save-position-on-quit заставляет mpv запоминать время остановки
    mpv --save-position-on-quit --title="Movie-CLI: $TITLE" "$URL"
}

# --- Логика ---
if [ "$1" == "--resume" ] && [ -f "$HISTORY_FILE" ]; then
    echo "↩️ Восстанавливаю последний просмотр..."
    source "$HISTORY_FILE"
    play_video "$LAST_URL" "$LAST_TITLE"
    exit 0
fi

if [ -z "$1" ]; then echo -n "🔍 Название: "; read -r QUERY_NAME; else QUERY_NAME="$1"; fi

QUERY=$(jq -rn --arg x "$QUERY_NAME" '$x|@uri')
echo "🔎 Ищу торренты для: $QUERY_NAME..."

RESULTS=$(curl -s "${JACKETT_URL}/api/v2.0/indexers/all/results?apikey=${API_KEY}&Query=${QUERY}")
IFS=$'\n' read -r -d '' -a TITLES < <(echo "$RESULTS" | jq -r '.Results[0:30][] | "[\(.Indexer)] \(.Title) | \(.Size / 1024 / 1024 / 1024 | tonumber | . * 100 | round / 100)GB | Seeds: \(.Seeders) \t \(.MagnetUri // .Link)"' && printf '\0')

if [ ${#TITLES[@]} -eq 0 ]; then echo "❌ Не найдено"; exit 1; fi
for i in "${!TITLES[@]}"; do echo "$((i+1))) $(echo "${TITLES[$i]}" | cut -f1)"; done
echo -n "👉 Номер раздачи: "; read -r CHOICE
if [[ ! "$CHOICE" =~ ^[0-9]+$ ]]; then exit 0; fi

LINK=$(echo "${TITLES[$((CHOICE-1))]}" | cut -f2 | tr -d '[:space:]')
TITLE=$(echo "${TITLES[$((CHOICE-1))]}" | cut -f1)

echo "🚀 Добавляю в TorrServer..."
ADD_RESP=$(curl -s -X POST -d "{\"action\":\"add\", \"link\":\"$LINK\", \"save\":false}" "${TORRSERVER_URL}/torrents")
HASH=$(echo "$ADD_RESP" | jq -r 'if type == "array" then .[0].hash else .hash end')

echo "⏳ Загружаю файлы..."
for i in {1..30}; do
    FILES=$(curl -s -X POST -d "{\"action\":\"get\", \"hash\":\"$HASH\"}" "${TORRSERVER_URL}/torrents")
    if echo "$FILES" | jq -e 'if type == "array" then .[0].file_stats else .file_stats end | length > 0' >/dev/null 2>&1; then break; fi
    sleep 1; echo -n ".";
done
echo ""
if echo "$FILES" | jq -e 'type == "array"' > /dev/null; then FILES=$(echo "$FILES" | jq '.[0]'); fi

IFS=$'\n' read -r -d '' -a F_NAMES < <(echo "$FILES" | jq -r '.file_stats[] | .path' && printf '\0')
IFS=$'\n' read -r -d '' -a F_IDS < <(echo "$FILES" | jq -r '.file_stats[] | .id' && printf '\0')

if [ ${#F_NAMES[@]} -gt 1 ]; then
    echo "0) 📺 ИГРАТЬ ВСЁ (плейлист)"
    for i in "${!F_NAMES[@]}"; do printf "%2d) %s\n" "$((i+1))" "$(basename "${F_NAMES[$i]}")"; done
    echo -n "👉 Выберите серию: "; read -r FC
    
    if [ "$FC" == "0" ]; then
        # Плейлист для всех файлов торрента
        FINAL_URL="${TORRSERVER_URL}/stream/playlist.m3u?link=${HASH}"
    else
        FID=${F_IDS[$((FC-1))]}
        FINAL_URL="${TORRSERVER_URL}/stream/?link=${HASH}&index=${FID}&play"
    fi
else
    FINAL_URL="${TORRSERVER_URL}/stream/?link=${HASH}&index=${F_IDS[0]}&play"
fi

# Сохраняем в историю
echo "LAST_URL=\"$FINAL_URL\"" > "$HISTORY_FILE"
echo "LAST_TITLE=\"$TITLE\"" >> "$HISTORY_FILE"

play_video "$FINAL_URL" "$TITLE"
