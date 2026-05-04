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

# Фильтруем медиафайлы
VIDEO_FILES_JSON=$(echo "$FILES" | jq -c '.file_stats[] | select(.path | test("\\.(mkv|mp4|avi|ts|m4v|mov|flv|webm|mpg|mpeg|wmv)$"; "i"))')
AUDIO_FILES_JSON=$(echo "$FILES" | jq -c '.file_stats[] | select(.path | test("\\.(mp3|flac|wav|m4a|ogg|aac|opus)$"; "i"))')

# Списки имен и ID для вывода
IFS=$'\n' read -r -d '' -a V_NAMES < <(echo "$VIDEO_FILES_JSON" | jq -r '.path' && printf '\0')
IFS=$'\n' read -r -d '' -a V_IDS < <(echo "$VIDEO_FILES_JSON" | jq -r '.id' && printf '\0')
IFS=$'\n' read -r -d '' -a A_NAMES < <(echo "$AUDIO_FILES_JSON" | jq -r '.path' && printf '\0')
IFS=$'\n' read -r -d '' -a A_IDS < <(echo "$AUDIO_FILES_JSON" | jq -r '.id' && printf '\0')

# Общее количество медиафайлов
TOTAL_MEDIA=$(( ${#V_NAMES[@]} + ${#A_NAMES[@]} ))

if [ $TOTAL_MEDIA -gt 1 ]; then
    [ ${#V_NAMES[@]} -gt 0 ] && echo "0) 📺 ИГРАТЬ ВСЁ ВИДЕО (плейлист)"
    [ ${#A_NAMES[@]} -gt 0 ] && echo "00) 🎵 ИГРАТЬ ВСЁ АУДИО (плейлист)"
    
    # Объединяем списки для отображения
    COMBINED_NAMES=("${V_NAMES[@]}" "${A_NAMES[@]}")
    COMBINED_IDS=("${V_IDS[@]}" "${A_IDS[@]}")
    
    for i in "${!COMBINED_NAMES[@]}"; do 
        printf "%2d) %s\n" "$((i+1))" "$(basename "${COMBINED_NAMES[$i]}")"
    done
    
    echo -n "👉 Ваш выбор: "; read -r FC
    
    if [ "$FC" == "0" ] && [ ${#V_NAMES[@]} -gt 0 ]; then
        FINAL_URL="${TORRSERVER_URL}/stream/playlist.m3u?link=${HASH}"
    elif [ "$FC" == "00" ] && [ ${#A_NAMES[@]} -gt 0 ]; then
        # Плейлист для аудио
        PLAYLIST_PATH="$HOME/.cache/movie_playlist.m3u"
        echo "#EXTM3U" > "$PLAYLIST_PATH"
        for i in "${!A_IDS[@]}"; do
            echo "#EXTINF:-1,$(basename "${A_NAMES[$i]}")" >> "$PLAYLIST_PATH"
            echo "${TORRSERVER_URL}/stream/?link=${HASH}&index=${A_IDS[$i]}&play" >> "$PLAYLIST_PATH"
        done
        FINAL_URL="$PLAYLIST_PATH"
    else
        FID=${COMBINED_IDS[$((FC-1))]}
        FINAL_URL="${TORRSERVER_URL}/stream/?link=${HASH}&index=${FID}&play"
    fi
else
    # Один файл
    FID=$(echo "$FILES" | jq -r '.file_stats[0].id')
    FINAL_URL="${TORRSERVER_URL}/stream/?link=${HASH}&index=${FID}&play"
fi

# Сохраняем в историю
echo "LAST_URL=\"$FINAL_URL\"" > "$HISTORY_FILE"
echo "LAST_TITLE=\"$TITLE\"" >> "$HISTORY_FILE"

play_video "$FINAL_URL" "$TITLE"
