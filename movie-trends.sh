#!/bin/bash

# --- Настройки ---
# Используем публичный прокси-агрегатор, который часто не блокируется
TRENDS_URL="https://api.realt.monster/movie/trends" # Публичный хаб трендов
SHIKIMORI_URL="https://shikimori.one/api/animes"

echo "🍿 Выберите подборку:"
echo "1) 🎬 Популярные фильмы"
echo "2) 📺 Популярные сериалы"
echo "3) ⛩️ Аниме (через прокси)"
echo -n "👉 Ваш выбор: "
read -r CAT_CHOICE

echo "📡 Загружаю список..."

# Используем User-Agent и прокси-запрос
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

case $CAT_CHOICE in
    1|2)
        # Попробуем получить тренды через открытый API TMDB прокси (как в fMovie)
        API_KEY="8d6d91941d3d63964893708f53f938d2"
        # Используем зеркало tmdb.cub.red (Лампа)
        TYPE=$([[ "$CAT_CHOICE" == "1" ]] && echo "movie" || echo "tv")
        TREND_URL="https://tmdb.cub.red/3/trending/$TYPE/week?api_key=$API_KEY&language=ru-RU"
        
        RESPONSE=$(curl -s -L -A "$UA" "$TREND_URL")
        CHOICE=$(echo "$RESPONSE" | jq -r '.results[] | "\(.vote_average) | \(.title // .name) (\(.release_date // .first_air_date // \"N/A\" | .[0:4])) @@@ \(.overview)"' | \
            fzf --delimiter=' @@@ ' --with-nth=1 --height=80% --reverse --header="🔥 Популярное сейчас" --preview 'echo -e "📖 ОПИСАНИЕ:\n\n{2}"' --preview-window=right:50%:wrap)
        ;;
    3)
        # Аниме через зеркало
        TREND_URL="https://tmdb.cub.red/3/discover/tv?api_key=$API_KEY&language=ru-RU&with_keywords=210024&sort_by=popularity.desc"
        RESPONSE=$(curl -s -L -A "$UA" "$TREND_URL")
        CHOICE=$(echo "$RESPONSE" | jq -r '.results[] | "\(.vote_average) | \(.name) (\(.first_air_date // \"N/A\" | .[0:4])) @@@ \(.overview)"' | \
            fzf --delimiter=' @@@ ' --with-nth=1 --height=80% --reverse --header="⛩️ Аниме Тренды" --preview 'echo -e "📖 ОПИСАНИЕ:\n\n{2}"' --preview-window=right:50%:wrap)
        ;;
    *) echo "Отмена."; exit 0 ;;
esac

[ -z "$CHOICE" ] && exit 0

# Извлекаем название
RAW_NAME=$(echo "$CHOICE" | awk -F' @@@ ' '{print $1}')
MOVIE_TITLE=$(echo "$RAW_NAME" | sed -E 's/^[0-9\.]+ \| (.*) \(.*\)$/\1/')

if [ -z "$MOVIE_TITLE" ]; then
    MOVIE_TITLE=$(echo "$RAW_NAME" | cut -d'|' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
fi

echo "🔍 Ищу: $MOVIE_TITLE..."
fmovie "$MOVIE_TITLE"
