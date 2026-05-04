#!/bin/bash

# --- Настройки ---
JACKETT_URL="https://jac-red.ru"
API_KEY="00000000000000000000000000000000"
TORRSERVER_URL="http://localhost:8090"
HISTORY_FILE="$HOME/.cache/movie-cli-last"
SUB_DIR="$HOME/.cache/mpv_subs"
SUBLIMINAL="/Users/sharabdin/Library/Python/3.9/bin/subliminal"

if command -v realpath >/dev/null 2>&1; then
    SELF=$(realpath "$0")
else
    SELF=$(python3 -c "import os,sys;print(os.path.realpath(sys.argv[1]))" "$0" 2>/dev/null || \
           perl -MCwd -e "print Cwd::abs_path(\$ARGV[0])" "$0" 2>/dev/null || \
           echo "$0")
fi

mkdir -p "$(dirname "$HISTORY_FILE")" "$SUB_DIR"

# Функция запуска mpv
play_video() {
    local URL="$1"
    local TITLE="$2"
    local EXTRA_ARGS=("${@:3}")
    
    if [[ "$URL" == *.m3u ]]; then
        mpv --save-position-on-quit --title="Movie-CLI: $TITLE" --playlist="$URL" "${EXTRA_ARGS[@]}"
    else
        mpv --save-position-on-quit --title="Movie-CLI: $TITLE" "$URL" "${EXTRA_ARGS[@]}"
    fi
}

# Функция очистки названия для поиска субтитров
clean_title() {
    local T="$1"
    # Удаляем содержимое квадратных и круглых скобок, технические данные
    echo "$T" | sed -E 's/\[[^]]+\]//g; s/\([^)]+\)//g; s/1080p|720p|WEB-DL|BDRip|AVC|x264|x265|HEVC//gi; s/[._]/ /g; s/  +/ /g' | xargs
}

# Функция поиска субтитров в терминале
get_subtitles() {
    local RAW_TITLE="$1"
    local TITLE=$(clean_title "$RAW_TITLE")
    
    echo "🔍 Авто-поиск для: $TITLE"
    echo "📝 Если не найдет, можно будет ввести название вручную."
    
    # Пытаемся скачать лучший вариант
    $SUBLIMINAL download -l ru -l en --directory "$SUB_DIR" "$TITLE" >/dev/null 2>&1
    
    local SUB_FILE=$(ls -t "$SUB_DIR" | head -n 1)
    
    # Если ничего не скачалось или файл старый (не относится к текущему поиску)
    # Простая проверка: если в папке пусто или последний файл создан более 30 сек назад
    if [ -z "$SUB_FILE" ] || [ $(find "$SUB_DIR/$SUB_FILE" -mmin +0.5 | wc -l) -gt 0 ]; then
        echo "❌ Авто-поиск не дал результатов."
        read -p "⌨️ Введите название для ручного поиска (или Enter для отмены): " MANUAL_TITLE
        if [ -n "$MANUAL_TITLE" ]; then
             echo "⏳ Ищу субтитры для: $MANUAL_TITLE..."
             $SUBLIMINAL download -l ru -l en --directory "$SUB_DIR" "$MANUAL_TITLE" >/dev/null 2>&1
             SUB_FILE=$(ls -t "$SUB_DIR" | head -n 1)
        fi
    fi
    
    if [ -n "$SUB_FILE" ] && [ $(find "$SUB_DIR/$SUB_FILE" -mmin -0.5 | wc -l) -gt 0 ]; then
        echo "✅ Субтитры найдены: $SUB_FILE"
        echo "--sub-file=$SUB_DIR/$SUB_FILE"
    else
        echo "❌ Субтитры не найдены."
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

# --- Основной цикл ---
while true; do
    CHOICE=$(fzf --disabled --ansi --header "🔍 Живой поиск | Esc для выхода" \
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

    VIDEO_FILES_JSON=$(echo "$FILES" | jq -c '.file_stats[] | select(.path | test("\\.(mkv|mp4|avi|ts|m4v|mov|flv|webm|mpg|mpeg|wmv)$"; "i"))')
    AUDIO_FILES_JSON=$(echo "$FILES" | jq -c '.file_stats[] | select(.path | test("\\.(mp3|flac|wav|m4a|ogg|aac|opus)$"; "i"))')

    IFS=$'\n' read -r -d '' -a V_NAMES < <(echo "$VIDEO_FILES_JSON" | jq -r '.path' && printf '\0')
    IFS=$'\n' read -r -d '' -a V_IDS < <(echo "$VIDEO_FILES_JSON" | jq -r '.id' && printf '\0')
    IFS=$'\n' read -r -d '' -a A_NAMES < <(echo "$AUDIO_FILES_JSON" | jq -r '.path' && printf '\0')
    IFS=$'\n' read -r -d '' -a A_IDS < <(echo "$AUDIO_FILES_JSON" | jq -r '.id' && printf '\0')

    TOTAL_MEDIA=$(( ${#V_NAMES[@]} + ${#A_NAMES[@]} ))

    if [ $TOTAL_MEDIA -gt 1 ]; then
        LIST_FILE=$(mktemp)
        [ ${#V_NAMES[@]} -gt 0 ] && echo -e "ALL_VIDEO\t00) 📺 ИГРАТЬ ВСЁ ВИДЕО" > "$LIST_FILE"
        [ ${#A_NAMES[@]} -gt 0 ] && echo -e "ALL_AUDIO\t00) 🎵 ИГРАТЬ ВСЁ АУДИО" >> "$LIST_FILE"
        for i in "${!V_NAMES[@]}"; do echo -e "${V_IDS[$i]}\t$(basename "${V_NAMES[$i]}")" >> "$LIST_FILE"; done
        for i in "${!A_NAMES[@]}"; do echo -e "${A_IDS[$i]}\t$(basename "${A_NAMES[$i]}")" >> "$LIST_FILE"; done
        FILE_CHOICE=$(cat "$LIST_FILE" | fzf --delimiter='\t' --with-nth=2 --height=40% --reverse --header="📺 Выберите файл (Esc для возврата)")
        rm "$LIST_FILE"
        FID=$(echo "$FILE_CHOICE" | cut -f1)
    else
        FID=$(echo "$FILES" | jq -r '.file_stats[0].id')
    fi

    if [ -n "$FID" ]; then
        SUB_ARG=""
        if [ "$FID" != "ALL_AUDIO" ] && [ ${#V_NAMES[@]} -gt 0 ]; then
             read -p "💬 Найти субтитры? (y/N): " -n 1 -r
             echo
             if [[ $REPLY =~ ^[Yy]$ ]]; then
                 SUB_ARG=$(get_subtitles "$TITLE")
             fi
        fi

        if [ "$FID" == "ALL_VIDEO" ] || [ "$FID" == "ALL_AUDIO" ]; then
            PLAYLIST_PATH="$HOME/.cache/movie_playlist.m3u"
            echo "#EXTM3U" > "$PLAYLIST_PATH"
            if [ "$FID" == "ALL_VIDEO" ]; then NAMES=("${V_NAMES[@]}"); IDS=("${V_IDS[@]}"); else NAMES=("${A_NAMES[@]}"); IDS=("${A_IDS[@]}"); fi
            for i in "${!IDS[@]}"; do
                echo "#EXTINF:-1,$(basename "${NAMES[$i]}")" >> "$PLAYLIST_PATH"
                echo "${TORRSERVER_URL}/stream/?link=${HASH}&index=${IDS[$i]}&play" >> "$PLAYLIST_PATH"
            done
            FINAL_URL="$PLAYLIST_PATH"
        else
            FINAL_URL="${TORRSERVER_URL}/stream/?link=${HASH}&index=${FID}&play"
        fi

        echo "LAST_URL=\"$FINAL_URL\"" > "$HISTORY_FILE"
        echo "LAST_TITLE=\"$TITLE\"" >> "$HISTORY_FILE"

        play_video "$FINAL_URL" "$TITLE" "$SUB_ARG"
    fi
done
