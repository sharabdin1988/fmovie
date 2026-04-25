#!/bin/bash

# --- Настройки ---
JACKETT_URL="https://jac-red.ru"
API_KEY="00000000000000000000000000000000"
TORRSERVER_URL="http://localhost:8090"
HISTORY_FILE="$HOME/.cache/movie-cli-last"
SELF=$(realpath "$0")

mkdir -p "$(dirname "$HISTORY_FILE")"

# Функция запуска mpv
play_video() {
    if [[ "$1" == *.m3u ]]; then
        mpv --save-position-on-quit --title="Movie-CLI: $2" --playlist="$1"
    else
        mpv --save-position-on-quit --title="Movie-CLI: $2" "$1"
    fi
}

# --- Логика Resume ---
if [ "$1" == "--resume" ]; then
    if [ -f "$HISTORY_FILE" ]; then
        echo "↩️ Восстанавливаю последний просмотр..."
        source "$HISTORY_FILE"
        play_video "$LAST_URL" "$LAST_TITLE"
        exit 0
    else
        echo "❌ История пуста."
        exit 1
    fi
fi

# --- Внутренняя функция поиска ---
if [ "$1" == "--api" ]; then
    Q=$(jq -rn --arg x "$2" '$x|@uri')
    curl -s "${JACKETT_URL}/api/v2.0/indexers/all/results?apikey=${API_KEY}&Query=${Q}" | \
    jq -r '.Results[] | "[\(.Indexer)] \(.Title) | \(.Size / 1024 / 1024 / 1024 | tonumber | . * 100 | round / 100)GB | Seeds: \(.Seeders) \t \(.MagnetUri // .Link)"' 2>/dev/null
    exit
fi

# --- Основной поиск ---
CHOICE=$(fzf --disabled --ansi --header "🔍 Живой поиск | --resume для возврата" \
    --prompt "Поиск > " --bind "change:reload:$SELF --api {q}" \
    --delimiter='\t' --with-nth=1 --height=80% --reverse \
    --preview "echo {1}" --preview-window=top:3:wrap)

[ -z "$CHOICE" ] && exit 0

LINK=$(echo "$CHOICE" | awk -F'\t' '{print $2}' | tr -d '[:space:]')
TITLE=$(echo "$CHOICE" | cut -f1)

echo "🚀 Загрузка торрента..."
ADD_RESP=$(curl -s -X POST -d "{\"action\":\"add\", \"link\":\"$LINK\", \"save\":false}" "${TORRSERVER_URL}/torrents")
HASH=$(echo "$ADD_RESP" | jq -r 'if type == "array" then .[0].hash else .hash end')

for i in {1..30}; do
    FILES=$(curl -s -X POST -d "{\"action\":\"get\", \"hash\":\"$HASH\"}" "${TORRSERVER_URL}/torrents")
    if echo "$FILES" | jq -e 'if type == "array" then .[0].file_stats else .file_stats end | length > 0' >/dev/null 2>&1; then break; fi
    sleep 1; echo -n "."
done
echo ""

if echo "$FILES" | jq -e 'type == "array"' > /dev/null; then FILES=$(echo "$FILES" | jq '.[0]'); fi

IFS=$'\n' read -r -d '' -a F_NAMES < <(echo "$FILES" | jq -r '.file_stats[] | .path' && printf '\0')
IFS=$'\n' read -r -d '' -a F_IDS < <(echo "$FILES" | jq -r '.file_stats[] | .id' && printf '\0')

if [ ${#F_NAMES[@]} -gt 1 ]; then
    LIST_FILE=$(mktemp)
    echo -e "ALL\t00) 📺 ИГРАТЬ ВСЁ (плейлист)" > "$LIST_FILE"
    for i in "${!F_NAMES[@]}"; do
        echo -e "${F_IDS[$i]}\t$(basename "${F_NAMES[$i]}")" >> "$LIST_FILE"
    done
    
    FILE_CHOICE=$(cat "$LIST_FILE" | fzf --delimiter='\t' --with-nth=2 --height=40% --reverse --header="📺 Выберите серию")
    rm "$LIST_FILE"
    
    FID=$(echo "$FILE_CHOICE" | cut -f1)
else
    FID=${F_IDS[0]}
fi

[ -z "$FID" ] && exit 0

if [ "$FID" == "ALL" ]; then
    PLAYLIST_PATH="$HOME/.cache/movie_playlist.m3u"
    echo "#EXTM3U" > "$PLAYLIST_PATH"
    for i in "${!F_IDS[@]}"; do
        # Добавляем название серии для mpv
        echo "#EXTINF:-1,$(basename "${F_NAMES[$i]}")" >> "$PLAYLIST_PATH"
        echo "${TORRSERVER_URL}/stream/?link=${HASH}&index=${F_IDS[$i]}&play" >> "$PLAYLIST_PATH"
    done
    FINAL_URL="$PLAYLIST_PATH"
else
    FINAL_URL="${TORRSERVER_URL}/stream/?link=${HASH}&index=${FID}&play"
fi

echo "LAST_URL=\"$FINAL_URL\"" > "$HISTORY_FILE"
echo "LAST_TITLE=\"$TITLE\"" >> "$HISTORY_FILE"

play_video "$FINAL_URL" "$TITLE"
