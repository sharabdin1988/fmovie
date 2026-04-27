#!/bin/bash

# --- Настройки ---
# Используем публичный API TMDB для трендов на русском языке
API_KEY="8d6d91941d3d63964893708f53f938d2"
BASE_URL="https://api.themoviedb.org/3"
LANG="ru-RU"

echo "🍿 Выберите категорию трендов:"
echo "1) 🎬 Фильмы"
echo "2) 📺 Сериалы"
echo "3) ⛩️ Аниме"
echo -n "👉 Ваш выбор: "
read -r CAT_CHOICE

case $CAT_CHOICE in
    1) TYPE="movie"; TREND_URL="$BASE_URL/trending/movie/day?api_key=$API_KEY&language=$LANG" ;;
    2) TYPE="tv"; TREND_URL="$BASE_URL/trending/tv/day?api_key=$API_KEY&language=$LANG" ;;
    3) TYPE="tv"; TREND_URL="$BASE_URL/discover/tv?api_key=$API_KEY&language=$LANG&with_keywords=210024&sort_by=popularity.desc" ;;
    *) echo "Отмена."; exit 0 ;;
esac

echo "📡 Загружаю список..."

# Получаем данные
RESPONSE=$(curl -s "$TREND_URL")

if [[ $RESPONSE == *"status_message"* ]]; then
    echo "❌ Ошибка API. Возможно, ключ устарел."
    exit 1
fi

# Формируем список для fzf
# Названия в API TMDB лежат в разных полях для кино (title) и сериалов (name)
CHOICE=$(echo "$RESPONSE" | jq -r '.results[] | "\(.vote_average) | \(.title // .name) (\(.release_date // .first_air_date // "N/A" | .[0:4])) \t \(.title // .name) \t \(.overview)"' | \
    fzf --delimiter='\t' --with-nth=1 \
    --height=80% --reverse --header="🔥 Тренды на сегодня | [Enter] искать в fmovie" \
    --preview 'echo -e "📖 ОПИСАНИЕ:\n\n{3}"' --preview-window=right:50%:wrap)

if [ -z "$CHOICE" ]; then
    echo "Отмена."
    exit 0
fi

# Извлекаем чистое название для поиска
MOVIE_TITLE=$(echo "$CHOICE" | awk -F'\t' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

echo "🔍 Ищу '$MOVIE_TITLE' в кинотеатре..."

# Запускаем fmovie
fmovie "$MOVIE_TITLE"
