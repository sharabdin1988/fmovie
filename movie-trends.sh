#!/bin/bash

# --- Настройки ---
# Используем стабильный прокси от сообщества Lampa (tmdb.cub.red)
API_KEY="8d6d91941d3d63964893708f53f938d2"
BASE_URL="https://tmdb.cub.red/3"
LANG="ru-RU"

echo "🍿 Выберите категорию:"
echo "1) 🎬 Популярные фильмы"
echo "2) 📺 Трендовые сериалы"
echo "3) ⛩️ Лучшее аниме"
echo -n "👉 Ваш выбор: "
read -r CAT_CHOICE

case $CAT_CHOICE in
    1) TREND_URL="$BASE_URL/trending/movie/day?api_key=$API_KEY&language=$LANG" ;;
    2) TREND_URL="$BASE_URL/trending/tv/day?api_key=$API_KEY&language=$LANG" ;;
    3) TREND_URL="$BASE_URL/discover/tv?api_key=$API_KEY&language=$LANG&with_keywords=210024&sort_by=popularity.desc" ;;
    *) echo "Отмена."; exit 0 ;;
esac

echo "📡 Загружаю список через Lampa Proxy..."

RESPONSE=$(curl -s -L --connect-timeout 10 "$TREND_URL")

if ! echo "$RESPONSE" | jq -e '.results | length > 0' > /dev/null 2>&1; then
    echo "❌ Ошибка: Не удалось получить данные даже через прокси."
    echo "Проверьте интернет-соединение."
    exit 1
fi

# Формируем список: [Название] @@@ [Описание]
CHOICE=$(echo "$RESPONSE" | jq -r '.results[] | "\(.vote_average) | \(.title // .name) (\(.release_date // .first_air_date // \"N/A\" | .[0:4])) @@@ \(.overview)"' | \
    fzf --delimiter=' @@@ ' --with-nth=1 \
    --height=80% --reverse --header="🔥 Тренды (Lampa API) | [Enter] искать в fmovie" \
    --preview 'echo -e "📖 ОПИСАНИЕ:\n\n{2}"' --preview-window=right:50%:wrap)

[ -z "$CHOICE" ] && exit 0

# Извлекаем название
RAW_NAME=$(echo "$CHOICE" | awk -F' @@@ ' '{print $1}')
MOVIE_TITLE=$(echo "$RAW_NAME" | sed -E 's/^[0-9\.]+ \| (.*) \(.*\)$/\1/')

if [ -z "$MOVIE_TITLE" ]; then
    MOVIE_TITLE=$(echo "$RAW_NAME" | cut -d'|' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
fi

echo "🔍 Ищу в прокате: $MOVIE_TITLE..."
fmovie "$MOVIE_TITLE"
